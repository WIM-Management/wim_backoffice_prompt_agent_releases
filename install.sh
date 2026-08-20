#!/usr/bin/env bash
# wim-backoffice-prompt-agent 설치 스크립트 (macOS / Linux)
#
# 원라이너:
#   curl -fsSL https://raw.githubusercontent.com/WIM-Management/wim_backoffice_prompt_agent_releases/main/install.sh | bash
#
# 하는 일: 최신 릴리스 바이너리 다운로드 → SHA256 검증 → 설치 + PATH 등록 → install(enroll·데몬·첫 수집 자동).
# 옵션: --no-setup (바이너리 설치까지만, enroll/데몬 등록 생략)
set -euo pipefail

REPO="WIM-Management/wim_backoffice_prompt_agent_releases"
BIN="wim-backoffice-prompt-agent"
BASE="https://github.com/${REPO}/releases/latest/download"
NO_SETUP=0
[ "${1:-}" = "--no-setup" ] && NO_SETUP=1

# --- 플랫폼 판별 ---
os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in darwin|linux) ;; *) echo "지원하지 않는 OS: $os" >&2; exit 1;; esac
arch=$(uname -m)
case "$arch" in
  x86_64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) echo "지원하지 않는 아키텍처: $arch" >&2; exit 1 ;;
esac
asset="${BIN}-${os}-${arch}"

# --- 다운로드 + 체크섬 검증 ---
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "최신 릴리스 다운로드 중... ($asset)"
curl -fsSL -o "$tmp/$asset" "$BASE/$asset"
curl -fsSL -o "$tmp/SHA256SUMS" "$BASE/SHA256SUMS"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$tmp" && grep "  ${asset}\$" SHA256SUMS | sha256sum -c - >/dev/null)
else
  (cd "$tmp" && grep "  ${asset}\$" SHA256SUMS | shasum -a 256 -c - >/dev/null)
fi
echo "체크섬 OK"

# --- 설치 위치: /usr/local/bin 쓰기 가능하면 거기, 아니면 ~/.local/bin ---
dest="/usr/local/bin"
if [ ! -w "$dest" ]; then
  dest="$HOME/.local/bin"
  mkdir -p "$dest"
fi
install -m 0755 "$tmp/$asset" "$dest/$BIN"
[ "$os" = darwin ] && xattr -d com.apple.quarantine "$dest/$BIN" 2>/dev/null || true
echo "설치됨: $dest/$BIN ($("$dest/$BIN" status | head -1))"

# --- PATH 등록: $dest 가 PATH에 없으면 로그인 셸 프로파일에 영구 추가(멱등) ---
# 예전엔 경고만 출력했더니 그냥 지나쳐서 이름으로 명령이 안 되는 사례가 있었다
# (`~/.local/bin` 설치인데 PATH 미등록). 데몬은 절대경로라 무관하지만, 사람이
# doctor/update 를 이름으로 못 쳐서 진단·수동 복구가 막힌다 → 자동 등록한다.
case ":$PATH:" in
  *":$dest:"*)
    : # 이미 PATH에 있음 — 할 일 없음
    ;;
  *)
    # 이 세션에도 즉시 반영(뒤따르는 명령이 이름으로 동작하도록).
    export PATH="$dest:$PATH"

    # 프로파일에 적을 줄. $HOME 하위면 $HOME 형태로 적어 이식성 유지.
    path_line="export PATH=\"$dest:\$PATH\""
    case "$dest" in
      "$HOME/"*) path_line="export PATH=\"\$HOME/${dest#"$HOME"/}:\$PATH\"" ;;
    esac
    marker="# wim-backoffice-prompt-agent (PATH)"

    # 대상 rc 파일: 로그인 셸 기준. 알 수 없으면 POSIX ~/.profile.
    case "${SHELL##*/}" in
      zsh)  rc="$HOME/.zshrc" ;;
      bash) [ "$os" = darwin ] && rc="$HOME/.bash_profile" || rc="$HOME/.bashrc" ;;
      *)    rc="$HOME/.profile" ;;
    esac

    if [ -f "$rc" ] && { grep -qF "$marker" "$rc" || grep -qF "$dest" "$rc"; }; then
      echo "PATH 이미 등록됨: $rc"
    elif printf '\n%s\n%s\n' "$marker" "$path_line" >> "$rc" 2>/dev/null; then
      echo "PATH 등록: $rc 에 $dest 추가함 (새 터미널부터 적용 · 지금 세션은 이미 반영)"
    else
      echo "⚠️  $rc 에 PATH를 못 썼습니다. 수동 추가: $path_line"
    fi
    ;;
esac

# --- 설치 마무리 (install이 enroll·데몬·첫 수집을 전부 오케스트레이션) ---
if [ "$NO_SETUP" = 1 ]; then
  echo "(--no-setup) 다음 단계: $BIN install  (enroll·데몬·첫 수집까지 자동)"
  exit 0
fi
echo ""
echo "설치를 마무리합니다 — 필요하면 브라우저가 열리니 회사 Google 계정으로 로그인하세요."
"$dest/$BIN" install
