#!/usr/bin/env bash
# =============================================================================
# init-system.sh — 重装 Debian 13 (trixie) + XFCE 后，按 SOFTWARE.md 一键初始化
# 用法：
#   sudo bash init-system.sh                 # 正式执行
#   sudo bash init-system.sh --dry-run       # 只打印将执行的命令，不改动系统
# 离线包目录（可选，环境变量覆盖）：
#   PKG_DIR 默认 = <你的家目录>/reinstall-pkgs
#   把重装前备份的 .deb（NyaTerm/Obsidian/Orca/Sublime/RustDesk/微信/QQ/Clash/
#   WindInput 等）放进该目录，脚本会自动 apt 安装；放 sdkm 也会提示恢复。
# 说明：幂等；联网部分需可访问外网；GPU 驱动复用同目录 init-nvidia-driver.sh。
# =============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

DRY_RUN=0; [ "${1:-}" = "--dry-run" ] && DRY_RUN=1
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
PKG_DIR="${PKG_DIR:-$REAL_HOME/reinstall-pkgs}"
HERE=$(cd "$(dirname "$0")" && pwd)
log(){ printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }
run(){ [ "$DRY_RUN" -eq 1 ] && { echo "[dry-run] $*"; return; }; eval "$@"; }
as_user(){ [ "$DRY_RUN" -eq 1 ] && { echo "[dry-run][user $REAL_USER] $*"; return; }; sudo -u "$REAL_USER" -H bash -lc "$*"; }

[ "$EUID" -eq 0 ] || die "请用 sudo 运行：  sudo bash $0 ${1:-}"
log "初始化开始  用户=$REAL_USER  家目录=$REAL_HOME  离线包=$PKG_DIR  dry_run=$DRY_RUN"

# ---- 1. 启用 contrib non-free（幂等，已备份源） ----
log "1/8 启用 contrib non-free"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] 将给 apt 源补 contrib non-free（并备份原文件）"
else
  shopt -s nullglob
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue; cp -a "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ "$f" == *.sources ]]; then
      grep -qE '^Components:' "$f" && ! grep -qE '^Components:.*\bcontrib\b' "$f" && sed -i -E 's/^(Components:.*)\bmain\b/\1main contrib non-free/' "$f"
    else
      sed -i -E '/^deb [^#]/ s/ main non-free-firmware$/ main contrib non-free non-free-firmware/; /^deb [^#]/ s/ main$/ main contrib non-free/' "$f"
    fi
  done
fi

# ---- 2. 第三方仓库：Chrome + Tailscale（优先用离线 .deb） ----
log "2/8 第三方仓库 Chrome / Tailscale"
if [ -f "$PKG_DIR/google-chrome-stable_current_amd64.deb" ]; then
  run apt install -y "$PKG_DIR/google-chrome-stable_current_amd64.deb"
else
  run 'wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg'
  run 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
fi
if ! dpkg -s tailscale >/dev/null 2>&1; then
  run 'curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg'
  run 'curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list'
fi
run apt-get update

# ---- 3. 官方源常用软件（B 组）+ Chrome/Tailscale ----
log "3/8 官方源常用软件"
run apt install -y git gh curl wget vim ripgrep git-gui gitk git-cola \
  rabbitvcs-thunar rabbitvcs-cli keepassxc xfce4-docklike-plugin \
  bluetooth bluez blueman libspa-0.2-bluetooth
run apt install -y google-chrome-stable tailscale

# ---- 4. 离线 .deb 应用（C 组）----
log "4/8 离线 .deb 应用"
if compgen -G "$PKG_DIR/*.deb" >/dev/null 2>&1; then
  for d in "$PKG_DIR"/*.deb; do echo "  将安装: $(basename "$d")"; done
  run apt install -y "$PKG_DIR"/*.deb
else
  warn "未在 $PKG_DIR 找到 .deb，跳过 C 组。备份好 .deb 放入该目录后重跑本步即可。"
fi

# ---- 5. 用户级工具 uv + claude（联网，装到用户家目录）----
log "5/8 用户级工具 uv / claude"
as_user 'command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh'
as_user 'command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash'

# ---- 6. sdkm(Node/Go) / Telegram / magpie（自定义，需从备份恢复）----
log "6/8 sdkm / Telegram / magpie（自定义工具）"
if [ -x "$REAL_HOME/.sdkm/sdkm" ]; then
  warn "已存在 ~/.sdkm，请用其手动安装： sdkm install node 26.13.0 / go 1.27.3（CLI 以 sdkm 为准）"
elif [ -x "$PKG_DIR/sdkm" ]; then
  warn "发现 $PKG_DIR/sdkm：请放入 ~/.sdkm/ 后用其安装 Node/Go（自定义工具，未自动执行）"
else
  warn "未找到 sdkm（自定义 SDK 管理器）：从备份恢复 ~/.sdkm 后再装 Node 26.13.0 / Go 1.27.3"
fi
[ -d "$REAL_HOME/.local/opt/Telegram" ] || warn "Telegram 未装：从备份恢复 ~/.local/opt/Telegram"
[ -x "$REAL_HOME/.local/bin/magpie" ] || warn "magpie 未装：从备份恢复 ~/.local/bin/magpie"

# ---- 7. GPU 驱动（复用 init-nvidia-driver.sh）----
log "7/8 GPU 驱动"
if [ -f "$HERE/init-nvidia-driver.sh" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] bash $HERE/init-nvidia-driver.sh"; else bash "$HERE/init-nvidia-driver.sh"; fi
else
  warn "同目录未找到 init-nvidia-driver.sh，请单独运行它安装闭源 NVIDIA 驱动"
fi

# ---- 8. 汇总 ----
log "8/8 完成"
cat <<EOF
下一步：
  · 若上面提示恢复 sdkm/Telegram/magpie，按提示从备份放回。
  · 输入法：确认 fcitx5 + WindInput（.deb 在 C 组）已装并在“设置→输入法”里启用。
  · 重启：sudo reboot   （GPU 驱动切换需重启；之后 nvidia-smi 验证）
  · 重跑安全：本脚本幂等，缺离线包时只跳过对应项，可随时再跑。
EOF