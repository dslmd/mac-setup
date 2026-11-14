#!/bin/bash
# 新 Mac 一键装软件。
#   ./setup.sh            全部安装
#   ./setup.sh --dry-run  只打印要做什么，不安装
#
# 装不上的不会中断，最后统一列出来。要增删软件，改下面三个列表就行。

set -o pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# ---------- Homebrew cask ----------
CASKS=(
  google-chrome
  microsoft-edge
  google-drive              # 自带 Google Docs / Sheets / Slides 快捷方式
  chrome-remote-desktop-host
  microsoft-word
  microsoft-excel
  microsoft-powerpoint
  microsoft-onenote
  microsoft-teams
  adobe-acrobat-pro         # 含 Acrobat Distiller
  slack
  telegram
  wechat
  whatsapp
  zoom
  tencent-meeting
  claude
  chatgpt
  visual-studio-code
  anaconda                  # 含 Anaconda-Navigator
  obsidian
  iina
  inkscape
  blender
  freecad
  ltspice
  anydesk
  tailscale-app
  thaw
  moomoo
)

# ---------- Mac App Store（要先登录 App Store）----------
# 格式: "ID 名字"
MAS_APPS=(
  "409201541 Pages"
  "409183694 Keynote"
  "409203825 Numbers"
  "408981434 iMovie"
  "682658836 GarageBand"
  "634148309 Logic Pro"
  "634159523 MainStage"
  "490179405 Okta Verify"
  "967004861 HP Easy Scan"
)

# ---------- 只能手动装的 ----------
# 格式: "名字|网址"，网址留空就只提醒
MANUAL=(
  "EndNote 2025|https://endnote.com/downloads"
  "NeatDownloadManager|https://www.neatdownloadmanager.com"
  "Gemini|https://gemini.google.com"
  "爱壹帆|https://www.iyf.tv"
  "DeepSeek|"
  "Muse|"
)

VIDAC_REPO="dslmd/Vidac"

# ------------------------------------------------------------

FAILED=()

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

if [ "$(uname)" != "Darwin" ] && [ $DRY_RUN -eq 0 ]; then
  echo "这个脚本只能在 macOS 上跑。" >&2
  exit 1
fi

# --- Homebrew ---
say "Homebrew"
if [ $DRY_RUN -eq 1 ]; then
  info "检查 Homebrew，没有就装"
else
  if ! command -v brew >/dev/null 2>&1; then
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
  fi
  if ! command -v brew >/dev/null 2>&1; then
    info "没装，现在装（会要一次密码）"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      echo "Homebrew 安装失败，先解决这个再重跑。" >&2
      exit 1
    }
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
    # 写进 zsh 配置，新开终端也能用 brew
    if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
      echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
    fi
  else
    info "已安装"
  fi
fi

# --- cask ---
say "Homebrew cask（${#CASKS[@]} 个）"
for cask in "${CASKS[@]}"; do
  if [ $DRY_RUN -eq 1 ]; then
    info "brew install --cask $cask"
    continue
  fi
  if brew list --cask "$cask" >/dev/null 2>&1; then
    info "$cask 已安装，跳过"
    continue
  fi
  info "安装 $cask ..."
  # --adopt: /Applications 里已有同名 app 时直接接管，不报错
  if ! brew install --cask --adopt "$cask"; then
    FAILED+=("$cask (brew cask)")
  fi
done

# --- Mac App Store ---
say "Mac App Store（${#MAS_APPS[@]} 个）"
if [ $DRY_RUN -eq 0 ] && ! command -v mas >/dev/null 2>&1; then
  brew install mas || FAILED+=("mas (App Store 命令行工具)")
fi
for entry in "${MAS_APPS[@]}"; do
  id="${entry%% *}"
  name="${entry#* }"
  if [ $DRY_RUN -eq 1 ]; then
    info "mas install $id   # $name"
    continue
  fi
  if [ -d "/Applications/$name.app" ]; then
    info "$name 已安装，跳过"
    continue
  fi
  info "安装 $name ..."
  # install 只认买过/领过的；没领过的免费 app 用 get
  if ! mas install "$id" && ! mas get "$id"; then
    FAILED+=("$name (App Store, id $id)")
  fi
done

# --- Vidac ---
say "Vidac"
if [ $DRY_RUN -eq 1 ]; then
  info "从 github.com/$VIDAC_REPO 最新 release 下载 DMG，拷到 /Applications"
elif [ -d "/Applications/Vidac.app" ]; then
  info "已安装，跳过"
else
  install_vidac() {
    local url tmp mnt
    url=$(curl -fsSL "https://api.github.com/repos/$VIDAC_REPO/releases/latest" \
      | grep -o 'https://[^"]*\.dmg' | head -1)
    [ -n "$url" ] || return 1
    tmp=$(mktemp -d) || return 1
    mnt="$tmp/mnt"
    mkdir "$mnt"
    info "下载 $url"
    curl -fL --progress-bar -o "$tmp/Vidac.dmg" "$url" || return 1
    hdiutil attach "$tmp/Vidac.dmg" -nobrowse -quiet -mountpoint "$mnt" || return 1
    cp -R "$mnt/Vidac.app" /Applications/
    local rc=$?
    hdiutil detach "$mnt" -quiet
    rm -rf "$tmp"
    return $rc
  }
  install_vidac || FAILED+=("Vidac (https://github.com/$VIDAC_REPO/releases/latest)")
fi

# --- 收尾 ---
say "需要手动装的"
for entry in "${MANUAL[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  if [ -n "$url" ]; then
    info "$name  $url"
  else
    info "$name"
  fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
  say "没装上的（${#FAILED[@]} 个）"
  for f in "${FAILED[@]}"; do info "$f"; done
  exit 1
fi

say "完成"
