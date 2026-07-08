# wim-backoffice-prompt-agent 설치 스크립트 (Windows)
#
# 원라이너 (PowerShell):
#   irm https://raw.githubusercontent.com/WIM-Management/wim_backoffice_prompt_agent_releases/main/install.ps1 | iex
#
# 하는 일: 최신 릴리스 exe 다운로드 → SHA256 검증 → %LOCALAPPDATA%\wim-backoffice-prompt-agent 설치 +
# 사용자 PATH 등록 → enroll → install(작업 스케줄러).
# 옵션: $env:WIM_PROMPT_NO_SETUP=1 (바이너리 설치까지만)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = "WIM-Management/wim_backoffice_prompt_agent_releases"
$asset = "wim-backoffice-prompt-agent-windows-amd64.exe"
$base = "https://github.com/$repo/releases/latest/download"

# --- 다운로드 + 체크섬 검증 ---
$dir = Join-Path $env:LOCALAPPDATA "wim-backoffice-prompt-agent"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Write-Host "최신 릴리스 다운로드 중... ($asset)"
Invoke-WebRequest -UseBasicParsing -Uri "$base/$asset" -OutFile (Join-Path $dir "wim-backoffice-prompt-agent.exe")
Invoke-WebRequest -UseBasicParsing -Uri "$base/SHA256SUMS" -OutFile (Join-Path $dir "SHA256SUMS")

$expected = ((Select-String -Path (Join-Path $dir "SHA256SUMS") -Pattern ([regex]::Escape($asset))).Line -split "\s+")[0]
$actual = (Get-FileHash (Join-Path $dir "wim-backoffice-prompt-agent.exe") -Algorithm SHA256).Hash.ToLower()
if ($expected -ne $actual) { throw "체크섬 불일치: expected=$expected actual=$actual" }
Write-Host "체크섬 OK"

# --- 사용자 PATH 등록 ---
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$dir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$dir", "User")
    $env:PATH = "$env:PATH;$dir"
    Write-Host "PATH에 추가됨: $dir (새 터미널부터 wim-backoffice-prompt-agent 명령 사용 가능)"
}

$exe = Join-Path $dir "wim-backoffice-prompt-agent.exe"
Write-Host "설치됨: $exe"
& $exe status | Select-Object -First 1

# --- enroll + 작업 스케줄러 등록 ---
if ($env:WIM_PROMPT_NO_SETUP -eq "1") {
    Write-Host "(NO_SETUP) 다음 단계: wim-backoffice-prompt-agent enroll ; wim-backoffice-prompt-agent install"
    return
}
Write-Host ""
Write-Host "기기 등록을 시작합니다 — 브라우저가 열리면 회사 Google 계정으로 로그인하세요."
& $exe enroll
if ($LASTEXITCODE -ne 0) { throw "enroll 실패" }
& $exe install
if ($LASTEXITCODE -ne 0) { throw "install 실패" }
Write-Host ""
Write-Host "✅ 완료! 15분 주기로 자동 수집됩니다. 확인: wim-backoffice-prompt-agent status"
