# wim_backoffice_prompt_agent — 릴리스 배포 채널

WIM 사내 **프롬프트 수집 에이전트**(wim-prompt-agent)의 릴리스 바이너리 배포용 공개 레포입니다.
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

스크립트가 최신 릴리스 다운로드 → SHA256 검증 → PATH 배치 → 기기 등록(`enroll`, 회사 Google 계정 로그인) → 자동 수집 시작(`install`)까지 한 번에 합니다.

수동 설치는 [Releases](https://github.com/WIM-Management/wim_backoffice_prompt_agent_releases/releases/latest)에서 OS별 바이너리를 직접 받아도 됩니다 (`darwin-arm64` / `darwin-amd64` / `linux-amd64` / `linux-arm64` / `windows-amd64.exe`, `SHA256SUMS`로 검증).

> 에이전트는 회사 Google Workspace 계정(wimcorp.co.kr)으로만 등록됩니다. 외부 사용자는 바이너리를 받아도 등록/사용할 수 없습니다.
