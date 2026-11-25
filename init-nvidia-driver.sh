#!/usr/bin/env bash
# =============================================================================
# init-nvidia-driver.sh
# 用途：全新安装 Debian 13 (trixie) 后，一键把显示驱动从开源 nouveau 切换到
#       闭源 nvidia-driver，解锁 CUDA / NVENC / NVDEC（AI 创作、本地 AI、视频硬编）。
# 用法：
#   sudo bash init-nvidia-driver.sh              # 正式安装（装完需重启才生效）
#   sudo bash init-nvidia-driver.sh --dry-run    # 只预演，不安装驱动
# 特性：幂等（可重复运行）；自动备份 /etc/apt 源文件；兼容 sources.list 与 deb822。
# =============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
TS=$(date +%Y%m%d-%H%M%S)
log(){ printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }
die(){ printf '\033[1;31m错误: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$EUID" -eq 0 ] || die "请用 sudo 运行：  sudo bash $0 ${1:-}"

# ---- 0. Secure Boot 提示（开启则 DKMS 模块需 MOK 注册） ----
if [ -d /sys/firmware/efi ] && command -v mokutil >/dev/null 2>&1; then
  SB=$(mokutil --sb-state 2>/dev/null)
  log "Secure Boot: $SB"
  case "$SB" in
    *enabled*) echo "⚠ 已开启 Secure Boot：DKMS 模块需签名。重启后首次开机会进蓝色 MOK 界面 → Enroll MOK → Continue → 设密码 → Reboot；或先到 BIOS 关闭 Secure Boot。";;
  esac
fi

# ---- 1. 启用 contrib non-free（兼容两种源格式；已备份） ----
log "1/6 启用 contrib non-free"
shopt -s nullglob
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do
  [ -f "$f" ] || continue
  cp -a "$f" "$f.bak.$TS"
  if [[ "$f" == *.sources ]]; then            # deb822 格式
    if grep -qE '^Components:' "$f" && ! grep -qE '^Components:.*\bcontrib\b' "$f"; then
      sed -i -E 's/^(Components:.*)\bmain\b/\1main contrib non-free/' "$f"
    fi
  else                                        # 经典 sources.list 格式
    sed -i -E '/^deb [^#]/ s/ main non-free-firmware$/ main contrib non-free non-free-firmware/; /^deb [^#]/ s/ main$/ main contrib non-free/' "$f"
  fi
done
grep -hE '^(deb |Components:)' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null | grep -vE '^[[:space:]]*#'

# ---- 2. 更新索引 ----
log "2/6 apt-get update"
apt-get update || die "apt-get update 失败（检查网络/源）"

# ---- 预演模式到此为止 ----
if [ "$DRY_RUN" -eq 1 ]; then
  log "预演：apt-get install -s nvidia-driver（-s 只模拟，不装）"
  apt-cache policy nvidia-driver | grep -E 'Candidate|Installed'
  apt-get install -s nvidia-driver
  log "预演结束（未安装）。确认 NEW 列表合理、无桌面被 REMOVE 后，去掉 --dry-run 正式运行。"
  exit 0
fi

# ---- 3. 内核头（DKMS 编译必需） ----
log "3/6 安装内核头 linux-headers-$(uname -r)"
apt-get install -y "linux-headers-$(uname -r)" \
  || die "找不到当前内核头 linux-headers-$(uname -r)；请先 apt update/升级内核后重试"

# ---- 4. 安装闭源驱动（DKMS 自动编译模块，下载+编译约几分钟） ----
log "4/6 安装 nvidia-driver"
apt-get install -y nvidia-driver || die "nvidia-driver 安装失败"

# ---- 5. 重建 initramfs（把 nouveau 拉黑固化进去） ----
log "5/6 update-initramfs -u"
update-initramfs -u

# ---- 6. 安装后校验（重启前能查的项） ----
log "6/6 安装后校验"
echo "--- DKMS（应为 nvidia-current/... : installed）---"; dkms status
echo "--- 模块文件 ---"; find "/lib/modules/$(uname -r)" -iname 'nvidia-current*.ko*' 2>/dev/null | head
echo "--- nouveau 拉黑（-R 跟随符号链接）---"; grep -RE 'blacklist[[:space:]]+nouveau' /etc/modprobe.d/ /etc/nvidia/ 2>/dev/null | head
echo "--- GL alternative（应为 nvidia）---"; update-glx --query nvidia 2>/dev/null | sed -n '1,2p'

cat <<'EOF'

=================================================================
✅ 安装完成。重启后才会从 nouveau 切到闭源驱动：  sudo reboot
重启后验证：
  nvidia-smi                            # 显卡型号 + Driver 版本 + CUDA 版本
  lsmod | grep -E '^nvidia|^nouveau'    # 有 nvidia、无 nouveau
  lspci -nnk | grep -A3 -i 'vga\|3d'    # N 卡 "Kernel driver in use: nvidia"
若重启后进不了桌面：Ctrl+Alt+F3 →
  sudo apt purge 'nvidia*' && sudo apt install --reinstall nvidia-driver
=================================================================
EOF