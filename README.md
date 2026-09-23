# wim_backoffice_prompt_agent — 릴리스 배포 채널

WIM 사내 **프롬프트 수집 에이전트**(wim-backoffice-prompt-agent)의 릴리스 바이너리 배포용 공개 레포입니다.
소스 코드는 private 레포(`WIM-Management/wim_backoffice_prompt_agent`)에서 관리되며, 여기에는 **빌드된 바이너리와 설치 스크립트만** 올라옵니다.

## 설치 (명령 한 줄)

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/WIM-Management/wim_backoffice_prompt_agent_releases/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/WIM-Management/wim_backoffice_prompt_agent_releases/main/install.ps1 | iex
```

스크립트가 최신 릴리스 다운로드 → SHA256 검증 → PATH 배치 → `install`까지 합니다. `install` 한 명령이 기기 등록(필요 시 회사 Google 계정 로그인) → 데몬 등록 → 첫 수집 1회를 전부 처리합니다. Windows 스크립트는 CPU 아키텍처(amd64 / arm64)를 판정해 맞는 자산을 받고, 등록 토큰은 스크립트가 물어본 뒤 `install --token`으로 넘깁니다.

Windows에서 수동으로 등록할 때도 토큰은 인자로 넘겨야 합니다. 릴리스 바이너리는 GUI 서브시스템으로 빌드되어 PowerShell·cmd가 종료를 기다리지 않으며, 셸이 콘솔 입력 소유권을 유지하기 때문에 에이전트가 띄운 프롬프트에는 입력이 전달되지 않습니다.

```powershell
wim-backoffice-prompt-agent install --token <웹 페이지에 표시된 토큰>
```

### Windows: 스마트 앱 컨트롤

Windows 11의 스마트 앱 컨트롤(Smart App Control)이 켜져 있으면 에이전트가 실행되지 않습니다. 이 기능은 유효한 Authenticode 서명과 마이크로소프트 평판이 둘 다 있는 실행 파일만 허용하고 나머지는 차단하며, macOS Gatekeeper와 달리 "그래도 실행" 우회가 없습니다. 현재 릴리스 바이너리에는 Authenticode 서명이 없어 차단 대상입니다.

증상은 조용합니다. 에이전트가 아무 메시지 없이 종료되어 수집만 멈춥니다. 설치 스크립트는 시작 시 상태를 읽어 켜져 있으면 안내를 출력하고 설치를 중단합니다.

끄는 경로: 설정 > 개인 정보 및 보안 > Windows 보안 > 앱 및 브라우저 컨트롤 > 스마트 앱 컨트롤 설정 > 끄기

스마트 앱 컨트롤은 한 번 끄면 Windows를 다시 설치하기 전까지 켤 수 없습니다. 설치 스크립트가 대신 끄지 않는 이유가 이것입니다. 레지스트리를 직접 수정해 끄면 시스템이 불일치 상태로 남아 미서명 앱 대부분이 차단되는 사례가 보고돼 있으므로, 설정 UI에서 끄십시오.

이미 설치된 기기에서 수집이 멈췄을 때는 `wim-backoffice-prompt-agent doctor`가 스마트 앱 컨트롤 상태를 함께 점검합니다.

수동 설치는 [Releases](https://github.com/WIM-Management/wim_backoffice_prompt_agent_releases/releases/latest)에서 OS별 바이너리를 직접 받아도 됩니다 (`darwin-arm64` / `darwin-amd64` / `linux-amd64` / `linux-arm64` / `windows-amd64.exe` / `windows-arm64.exe`, `SHA256SUMS`로 검증).

> 에이전트는 회사 Google Workspace 계정(wimcorp.co.kr)으로만 등록됩니다. 외부 사용자는 바이너리를 받아도 등록/사용할 수 없습니다.
