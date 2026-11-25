#!/usr/bin/env bash
# =============================================================================
# init-system.sh — 重装 Debian 13 (trixie) + XFCE 后，按 SOFTWARE.md 一键初始化
# 用法：
#   sudo bash init-system.sh                 # 正式执行
#   sudo bash init-system.sh --dry-run       # 只打印将执行的命令，不改动系统
# 安装来源（无需你提前下载 .deb，脚本联网自动获取）：
#   · 官方 apt 仓库：Chrome / Sublime / Tailscale → 自动加源安装
#   · GitHub release：Obsidian / RustDesk / Clash Verge → 自动取最新 .deb 安装
#   · 官方直链：在下方 DEB_URL 填一次 .deb 地址即自动下载安装（留空=跳过）
#   · 内部/无公开源：NyaTerm / 微信 / QQ / 问剑 等 → 在 DEB_URL 填直链，或从备份恢复
#   可选：PKG_DIR 若放了本地 .deb 则优先用本地（离线）。
# 说明：幂等；需可访问外网；GPU 驱动复用同目录 init-nvidia-driver.sh。
# =============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

DRY_RUN=0; [ "${1:-}" = "--dry-run" ] && DRY_RUN=1
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
PKG_DIR="${PKG_DIR:-$REAL_HOME/reinstall-pkgs}"
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
log(){ printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }
run(){ [ "$DRY_RUN" -eq 1 ] && { echo "[dry-run] $*"; return; }; eval "$@"; }
as_user(){ [ "$DRY_RUN" -eq 1 ] && { echo "[dry-run][user $REAL_USER] $*"; return; }; sudo -u "$REAL_USER" -H bash -lc "$*"; }

install_deb(){ # $1=输出文件名 $2=URL —— 下载并 apt 安装
  local out="$TMP/$1"
  [ "$DRY_RUN" -eq 1 ] && { echo "[dry-run] wget -O $out '$2' && apt install -y $out"; return; }
  wget -q -O "$out" "$2" && apt install -y "$out" || warn "下载/安装失败：$1 ($2)"
}
gh_latest_deb(){ # $1=owner/repo $2=.deb 名匹配正则(忽略大小写) —— 取 GitHub 最新 release（走 github.com，避开 api 限流）
  if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] 取 GitHub 最新 $1 的 .deb($2) 并安装"; return; fi
  local tag page url
  tag=$(curl -sSI "https://github.com/$1/releases/latest" 2>/dev/null | tr -d '\r' | awk -F/ '/^location:/{print $NF}' | tail -1)
  if [ -n "$tag" ]; then
    page=$(curl -sSL "https://github.com/$1/releases/expanded_assets/$tag" 2>/dev/null)
    url=$(printf '%s' "$page" | grep -oE "/$1/releases/download/[^\"]+\.deb" | grep -iE "$2" | head -1)
    url="${url:+https://github.com$url}"
  fi
  if [ -n "$url" ]; then install_deb "$(basename "$url")" "$url"; else warn "GitHub 未匹配到 .deb：$1 — 见 https://github.com/$1/releases/latest"; fi
}

# ========================= 应用下载源配置 =========================
GH_DEB=( # "owner/repo|.deb名正则"
  "obsidianmd/obsidian-releases|obsidian.*amd64\.deb"
  "rustdesk/rustdesk|rustdesk-.*x86_64\.deb"
  "clash-verge-rev/clash-verge-rev|clash.*verge.*amd64\.deb"
)
declare -A DEB_URL=( # 官方直链，填完整 .deb URL（留空=跳过）
  [nyaterm]=""     [wechat]=""   [qq]=""        [windinput]=""
  [git-tree]=""    [noteGen]=""  [openidea]=""
)
# 本地优先目录（放了对应 *.deb 就用本地，不下载）
# =================================================================
[ "$EUID" -eq 0 ] || die "请用 sudo 运行：  sudo bash $0 ${1:-}"
log "初始化开始  用户=$REAL_USER  家目录=$REAL_HOME  dry_run=$DRY_RUN"

# ---- 1. 启用 contrib non-free ----
log "1/8 启用 contrib non-free"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] 给 apt 源补 contrib non-free（并备份）"
else
  shopt -s nullglob
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue; cp -a "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ "$f" == *.sources ]]; then
      if grep -qE '^Components:' "$f" && ! grep -qE '^Components:.*\bcontrib\b' "$f"; then
        sed -i -E 's/^(Components:[^\n]*)\bmain\b/\1main contrib non-free/' "$f"
      fi
    else
      sed -i -E '/^deb [^#]/ s/ main non-free-firmware$/ main contrib non-free non-free-firmware/; /^deb [^#]/ s/ main$/ main contrib non-free/' "$f"
    fi
  done
fi

# ---- 2. 第三方 apt 仓库：Chrome / Sublime / Tailscale ----
log "2/8 第三方 apt 仓库 Chrome / Sublime / Tailscale"
if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  run 'wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg'
  run 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
fi
if ! dpkg -s sublime-text >/dev/null 2>&1; then
  run 'wget -qO- https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor -o /usr/share/keyrings/sublime-pub.gpg'
  run 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/sublime-pub.gpg] https://download.sublimetext.com/apt/stable/ stable main" > /etc/apt/sources.list.d/sublime-text.list'
fi
if ! dpkg -s tailscale >/dev/null 2>&1; then
  run 'curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg'
  run 'curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list'
fi
run apt-get update

# ---- 3. 官方源常用软件 + Chrome/Sublime/Tailscale ----
log "3/8 官方源常用软件"
run apt install -y git gh curl wget vim ripgrep \
  git-gui gitk git-cola rabbitvcs-thunar rabbitvcs-cli keepassxc \
  xfce4-docklike-plugin bluetooth bluez blueman libspa-0.2-bluetooth
run apt install -y google-chrome-stable sublime-text tailscale
# ---- 4. 其余应用：自动下载安装（本地优先 / GitHub 最新 / 官方直链）----
log "4/8 下载安装应用（无需预备 .deb）"
# 4a 本地优先：PKG_DIR 里对应 *.deb 存在则直接用，不下载
declare -A LOCAL_DEB=()
if [ -d "$PKG_DIR" ]; then
  shopt -s nullglob
  for d in "$PKG_DIR"/*.deb; do
    b=$(basename "$d" .deb); k=$(printf '%s' "$b" | cut -d_ -f1 | tr 'A-Z' 'a-z')
    LOCAL_DEB["$k"]="$d"
  done
fi
# 4b GitHub 最新 release（Obsidian / RustDesk / Clash Verge）
for e in "${GH_DEB[@]}"; do
  repo="${e%%|*}"; pat="${e#*|}"; key=$(echo "$repo" | sed -E 's#.*/##' | tr 'A-Z' 'a-z')
  if [ -n "${LOCAL_DEB[$key]:-}" ]; then run apt install -y "${LOCAL_DEB[$key]}"
  else gh_latest_deb "$repo" "$pat"; fi
done
# 4c 官方直链（DEB_URL 里填了的才装）
for name in "${!DEB_URL[@]}"; do
  u="${DEB_URL[$name]}"; [ -z "$u" ] && continue
  if [ -n "${LOCAL_DEB[$name]:-}" ]; then run apt install -y "${LOCAL_DEB[$name]}"
  else install_deb "${name}.deb" "$u"; fi
done
# 4d PKG_DIR 里其余本地 .deb（可选离线；上面的已跳过）
if compgen -G "$PKG_DIR/*.deb" >/dev/null 2>&1; then
  echo "  另安装 PKG_DIR 其余本地 .deb："; for d in "$PKG_DIR"/*.deb; do echo "    $(basename "$d")"; done
  run apt install -y "$PKG_DIR"/*.deb
fi
# 4e 未填源的内置清单项（诚实提示，不编造 URL）
warn "以下应用无公开源/未填 URL，请在 DEB_URL 填直链或从备份恢复：NyaTerm / 微信 / QQ / 问剑 / Git-Tree / Orca / MisterDownloadManager"

# ---- 5. 用户级工具 uv + claude ----
log "5/8 用户级工具 uv / claude"
as_user 'command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh'
as_user 'command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash'

# ---- 6. sdkm(Node/Go) / Telegram / magpie（自定义，需从备份恢复）----
log "6/8 sdkm / Telegram / magpie（自定义工具）"
if [ -x "$REAL_HOME/.sdkm/sdkm" ]; then
  warn "已存在 ~/.sdkm，用其装： sdkm install node 26.13.0 / go 1.27.3（CLI 以 sdkm 为准）"
else
  warn "未找到 sdkm：从备份恢复 ~/.sdkm 后再装 Node 26.13.0 / Go 1.27.3"
fi
[ -d "$REAL_HOME/.local/opt/Telegram" ] || warn "Telegram 未装：从备份恢复 ~/.local/opt/Telegram"
[ -x "$REAL_HOME/.local/bin/magpie" ] || warn "magpie 未装：从备份恢复 ~/.local/bin/magpie"

# ---- 7. GPU 驱动 ----
log "7/8 GPU 驱动（复用 init-nvidia-driver.sh）"
if [ -f "$HERE/init-nvidia-driver.sh" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] bash $HERE/init-nvidia-driver.sh"
  else bash "$HERE/init-nvidia-driver.sh"; fi
else warn "同目录未找到 init-nvidia-driver.sh，请单独运行它装闭源 NVIDIA 驱动"; fi

# ---- 8. 汇总 ----
log "8/8 完成"
cat <<EOF
下一步：
  · 标⚠的项（sdkm/Telegram/magpie，或未填 URL 的应用）按提示处理或从备份恢复。
  · 输入法：确认 fcitx5 + WindInput 已装并在"设置→输入法"启用。
  · 重启：sudo reboot （切换 GPU 驱动需重启；之后 nvidia-smi 验证）。
  · 幂等：缺源/下载失败只跳过对应项，可随时重跑。
EOF