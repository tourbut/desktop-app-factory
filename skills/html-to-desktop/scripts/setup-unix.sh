#!/usr/bin/env bash
# Tauri v2 빌드 환경 점검/설치 (macOS, Linux).
# 사용: bash setup-unix.sh [--install]
# --install 없이 실행하면 점검만 한다. 끝에 "MISSING: ..." 또는 "READY" 한 줄을 출력한다.
set -u
export PATH="$HOME/.cargo/bin:$PATH"
has() { command -v "$1" >/dev/null 2>&1; }

check() {
  missing=()
  case "$(uname -s)" in
    Darwin) xcode-select -p >/dev/null 2>&1 || missing+=(xcode-clt) ;;
    Linux)  pkg-config --exists webkit2gtk-4.1 2>/dev/null || missing+=(system-libs) ;;
  esac
  has cargo || missing+=(rust)
  has node || missing+=(node)
}

check
if [ ${#missing[@]} -eq 0 ]; then echo READY; exit 0; fi
if [ "${1:-}" != "--install" ]; then echo "MISSING: ${missing[*]}"; exit 1; fi

for m in "${missing[@]}"; do
  case "$m" in
    xcode-clt)
      echo "==> xcode-select --install (뜨는 창에서 '설치'를 누른다)"
      xcode-select --install || true ;;
    system-libs)
      if has apt-get; then
        sudo apt-get update && sudo apt-get install -y libwebkit2gtk-4.1-dev build-essential curl wget file \
          libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev
      elif has dnf; then
        sudo dnf check-update; sudo dnf install -y webkit2gtk4.1-devel openssl-devel curl wget file \
          libappindicator-gtk3-devel librsvg2-devel libxdo-devel && sudo dnf group install -y "c-development"
      elif has pacman; then
        sudo pacman -Syu --needed --noconfirm webkit2gtk-4.1 base-devel curl wget file openssl \
          appmenu-gtk-module libappindicator-gtk3 librsvg xdotool
      else
        echo "지원하지 않는 패키지 관리자. https://v2.tauri.app/start/prerequisites/ 를 따라 수동 설치하라."
      fi ;;
    rust)
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      export PATH="$HOME/.cargo/bin:$PATH" ;;
    node)
      if [ "$(uname -s)" = Darwin ] && has brew; then brew install node
      elif has apt-get; then sudo apt-get install -y nodejs npm
      elif has dnf; then sudo dnf install -y nodejs npm
      elif has pacman; then sudo pacman -S --needed --noconfirm nodejs npm
      else echo "Node.js LTS를 https://nodejs.org 에서 설치하라."
      fi ;;
  esac
done

check
if [ ${#missing[@]} -eq 0 ]; then echo READY; exit 0; fi
echo "MISSING: ${missing[*]}"
echo "설치 창이 끝난 뒤(또는 새 터미널에서) 다시 점검하라."
exit 1
