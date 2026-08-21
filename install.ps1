# wim-backoffice-prompt-agent 설치 스크립트 (Windows)
#
# 원라이너 (PowerShell):
#   irm https://raw.githubusercontent.com/WIM-Management/wim_backoffice_prompt_agent_releases/main/install.ps1 | iex
#
# 하는 일: 최신 릴리스 exe 다운로드 → SHA256 검증 → %LOCALAPPDATA%\wim-backoffice-prompt-agent 설치 +
# 사용자 PATH 등록 → 토큰 입력 → install(등록·데몬·첫 수집 자동).
# 옵션: $env:WIM_PROMPT_NO_SETUP=1 (바이너리 설치까지만)
$ErrorActionPreference = "Stop"
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

# --- 다운로드 + 체크섬 검증 ---
$dir = Join-Path $env:LOCALAPPDATA "wim-backoffice-prompt-agent"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$exe = Join-Path $dir "wim-backoffice-prompt-agent.exe"
$sums = Join-Path $dir "SHA256SUMS"

Write-Host "최신 릴리스 다운로드 중... ($asset)"
try {
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile $exe
} catch {
    # arm64 자산은 특정 버전부터 발행된다. 그 이전 릴리스를 받는 경우 amd64로 내려간다
    # (Windows on ARM은 x64 바이너리를 에뮬레이션으로 실행한다).
    if ($arch -eq "arm64") {
        Write-Host "arm64 자산이 없는 릴리스입니다 — amd64로 대체합니다(에뮬레이션 실행)."
        $arch = "amd64"
        $asset = "wim-backoffice-prompt-agent-windows-$arch.exe"
        Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile $exe
    } else {
        throw
    }
}
Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile $sums

$expected = ((Select-String -Path $sums -Pattern ([regex]::Escape($asset))).Line -split "\s+")[0]
$actual = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
if ($expected -ne $actual) { throw "체크섬 불일치: expected=$expected actual=$actual" }
Write-Host "체크섬 OK"

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
