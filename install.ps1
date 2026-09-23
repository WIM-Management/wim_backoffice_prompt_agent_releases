# wim-backoffice-prompt-agent 설치 스크립트 (Windows)
#
# 원라이너 (PowerShell):
#   irm https://raw.githubusercontent.com/WIM-Management/wim_backoffice_prompt_agent_releases/main/install.ps1 | iex
#
# 하는 일: 최신 릴리스 exe 다운로드 → SHA256 검증 → %LOCALAPPDATA%\wim-backoffice-prompt-agent 설치 +
# 사용자 PATH 등록 → 토큰 입력 → install(등록·데몬·첫 수집 자동).
# 옵션: $env:WIM_PROMPT_NO_SETUP=1 (바이너리 설치까지만)
$ErrorActionPreference = "Stop"

# --- 스마트 앱 컨트롤(SAC) 점검 ---
# 이 점검은 다른 무엇보다 먼저 온다. SAC는 신뢰되지 않은 스크립트의 PowerShell을
# 제한 언어 모드로 내릴 수 있고, 그러면 아래 .NET 타입 접근부터 실패해 정작 안내가
# 한 줄도 나오지 않는다. 가드는 자기가 보호하려는 대상보다 앞에 있어야 한다.
# Windows 11의 스마트 앱 컨트롤은 유효한 Authenticode 서명과 마이크로소프트 평판이
# 둘 다 있는 실행 파일만 허용하고, 나머지는 커널에서 차단한다. macOS Gatekeeper와 달리
# "그래도 실행" 우회가 없다. 릴리스 바이너리는 현재 서명이 없어 차단 대상이고,
# 차단되면 exe가 아무 메시지 없이 죽어 원인을 찾기 어렵다 — 설치 전에 멈추고 안내한다.
#
# 스크립트가 대신 끄지 않는 이유: SAC는 한 번 끄면 Windows를 다시 설치하기 전까지
# 켤 수 없고, 레지스트리를 직접 건드리면 시스템이 불일치 상태로 남아 미서명 앱
# 대부분이 차단되는 사례가 보고돼 있다. 되돌릴 수 없는 보안 설정 변경은 사용자가
# 설정 UI에서 직접 한다.
#
# 값: 0=끔, 1=켬, 2=평가 모드(차단하지 않고 학습만 한다). 키가 없으면 SAC 미지원 OS다.
# 판독이 잘못됐다고 판단되면 $env:WIM_PROMPT_SKIP_SAC_CHECK=1 로 건너뛸 수 있다.
if ($env:WIM_PROMPT_SKIP_SAC_CHECK -ne "1") {
    # 프로퍼티를 바로 체이닝하지 않는다 — 호출자 프로필이 Set-StrictMode 를 켜 뒀으면
    # $null 프로퍼티 접근이 종료 에러가 되어 멀쩡한 기기의 설치가 여기서 멈춘다.
    $sacKey = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
        -Name "VerifiedAndReputablePolicyState" -ErrorAction SilentlyContinue
    $sacState = if ($sacKey) { $sacKey.VerifiedAndReputablePolicyState } else { $null }
    if ($sacState -eq 1) {
        Write-Host ""
        Write-Host "스마트 앱 컨트롤이 켜져 있어 설치를 진행할 수 없습니다."
        Write-Host "이 기능은 서명과 평판이 없는 프로그램을 차단하며, 우회 옵션이 없습니다."
        Write-Host ""
        Write-Host "끄는 방법: 설정 > 개인 정보 및 보안 > Windows 보안 >"
        Write-Host "          앱 및 브라우저 컨트롤 > 스마트 앱 컨트롤 설정 > 끄기"
        Write-Host ""
        Write-Host "주의: 스마트 앱 컨트롤은 한 번 끄면 Windows를 다시 설치하기 전까지"
        Write-Host "      켤 수 없습니다. 판단이 서지 않으면 담당자에게 문의하세요."
        Write-Host ""
        Write-Host "끈 뒤 이 설치 명령을 다시 실행하세요."
        return
    }
    if ($sacState -eq 2) {
        Write-Host "스마트 앱 컨트롤이 평가 모드입니다 — 지금은 차단하지 않지만, 평가 결과 켜지면"
        Write-Host "에이전트가 차단되어 수집이 멈춥니다. 그때는 위 경로에서 끄고 다시 설치하세요."
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = "WIM-Management/wim_backoffice_prompt_agent_releases"
$base = "https://github.com/$repo/releases/latest/download"

# enroll 페이지 주소. 에이전트 config의 EnrollURL과 같은 값이다. 에이전트는 콘솔에
# 직접 출력하고 PowerShell 파이프로는 캡처되지 않으므로(GUI 서브시스템 + CONOUT$
# 재연결) 바이너리에서 읽어오지 못한다. 주소가 바뀌면 여기도 같이 고친다.
$enrollUrl = "https://backoffice.wimcorp.co.kr/prompt-agent/enroll"

# --- 아키텍처 판정 (Windows on ARM 지원) ---
# 32비트 프로세스에서 실행될 때 실제 OS 아키텍처는 PROCESSOR_ARCHITEW6432에 들어온다.
$archRaw = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = if ($archRaw -eq "ARM64") { "arm64" } else { "amd64" }
$asset = "wim-backoffice-prompt-agent-windows-$arch.exe"

# --- 실행 중인 에이전트 정지 ---
# Windows는 실행 중인 exe 파일을 잠근다. 재설치 시점에 이전 에이전트(주기 run-once,
# 또는 종료되지 않고 남은 대화형 프로세스)가 살아 있으면 덮어쓰기가 공유 위반으로
# 실패한다. 관리자 권한과 무관한 문제라 승격해도 풀리지 않는다 — 프로세스를 먼저 놓아야 한다.
# 에이전트는 로그인 사용자 계정으로 돌기 때문에 승격 없이 종료할 수 있다.
$running = @(Get-Process -Name "wim-backoffice-prompt-agent" -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Host "실행 중인 에이전트 $($running.Count)개를 정지합니다."
    $running | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# --- 다운로드 + 체크섬 검증 ---
$dir = Join-Path $env:LOCALAPPDATA "wim-backoffice-prompt-agent"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$exe = Join-Path $dir "wim-backoffice-prompt-agent.exe"
$new = "$exe.new"
$sums = Join-Path $dir "SHA256SUMS"

# 새 파일은 별도 경로로 받아 검증까지 마친 뒤 교체한다. 실행 파일에 직접 내려받으면
# 잠겨 있을 때 실패하고, 검증 실패 시에도 기존 바이너리가 이미 깨진 상태가 된다.
Write-Host "최신 릴리스 다운로드 중... ($asset)"
try {
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile $new
} catch {
    # arm64 자산이 없는 이전 릴리스일 때만 amd64로 내려간다(Windows on ARM은 x64를
    # 에뮬레이션으로 실행). 404가 아닌 오류를 폴백으로 삼키면 원인이 가려진다.
    $status = $_.Exception.Response.StatusCode.value__
    if ($arch -eq "arm64" -and $status -eq 404) {
        Write-Host "arm64 자산이 없는 릴리스입니다 — amd64로 대체합니다(에뮬레이션 실행)."
        $arch = "amd64"
        $asset = "wim-backoffice-prompt-agent-windows-$arch.exe"
        Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile $new
    } else {
        throw
    }
}
Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile $sums

$expected = ((Select-String -Path $sums -Pattern ([regex]::Escape($asset))).Line -split "\s+")[0]
$actual = (Get-FileHash $new -Algorithm SHA256).Hash.ToLower()
if ($expected -ne $actual) {
    Remove-Item $new -Force -ErrorAction SilentlyContinue
    throw "체크섬 불일치: expected=$expected actual=$actual"
}
Write-Host "체크섬 OK"

# --- 교체 ---
# 잠긴 exe도 이름 변경은 허용된다. 기존 파일을 옆으로 밀고 새 파일을 제자리에 넣는다
# (에이전트 self-update가 쓰는 방식과 동일).
$old = $null
if (Test-Path $exe) {
    $old = "$exe.old"
    Remove-Item $old -Force -ErrorAction SilentlyContinue
    # 이전 .old가 아직 잠겨 있으면(다른 프로세스가 물고 있음) 고유 이름으로 비켜 둔다.
    if (Test-Path $old) { $old = "$exe.old.$([Guid]::NewGuid().ToString('N').Substring(0,8))" }
    Rename-Item -Path $exe -NewName (Split-Path $old -Leaf)
}
Move-Item -Path $new -Destination $exe -Force
if ($old) { Remove-Item $old -Force -ErrorAction SilentlyContinue }

# --- 사용자 PATH 등록 ---
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$dir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$dir", "User")
    $env:PATH = "$env:PATH;$dir"
    Write-Host "PATH에 추가됨: $dir (새 터미널부터 wim-backoffice-prompt-agent 명령 사용 가능)"
}
Write-Host "설치됨: $exe ($arch)"

# --- 설치 마무리 ---
if ($env:WIM_PROMPT_NO_SETUP -eq "1") {
    Write-Host "(NO_SETUP) 다음 단계: $enrollUrl 에서 토큰을 복사한 뒤"
    Write-Host "  wim-backoffice-prompt-agent install --token <토큰>"
    return
}

# 토큰은 PowerShell이 받아 인자로 넘긴다. 에이전트를 콘솔에서 직접 읽게 하면 안 된다 —
# 릴리스 바이너리는 GUI 서브시스템(-H=windowsgui)이라 PowerShell이 종료를 기다리지 않고,
# 셸이 콘솔 입력 소유권을 유지해 에이전트의 프롬프트에 친 내용이 전달되지 않는다.
Write-Host ""
Write-Host "브라우저에서 아래 주소를 열어 회사 Google 계정으로 로그인한 뒤, 화면에 표시된 토큰을 복사하세요."
Write-Host "  $enrollUrl"
try { Start-Process $enrollUrl } catch { Write-Host "(브라우저 자동 실행 실패 — 위 주소를 직접 여세요)" }
$token = Read-Host "토큰"
if (-not $token.Trim()) { throw "토큰이 비어 있습니다 — 위 주소에서 토큰을 복사해 다시 실행하세요." }

# Start-Process -Wait: GUI 서브시스템 프로세스는 `& $exe`로 부르면 셸이 기다리지 않아
# 종료코드도, 완료 시점도 알 수 없다(기존 $LASTEXITCODE 검사는 직전 명령의 값을 보고 있었다).
$p = Start-Process -FilePath $exe -ArgumentList @("install", "--token", $token) -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "install 실패 (exit $($p.ExitCode))" }
