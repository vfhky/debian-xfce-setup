#!/usr/bin/env bash
# component: nvidia — 包装 init-nvidia-driver.sh（透传 --dry-run）
set -uo pipefail
ID=nvidia; TYPE=script; ORDER=50; DESC="闭源 NVIDIA 驱动"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  local drv="$REPO_ROOT/init-nvidia-driver.sh"
  [ -f "$drv" ] || { warn "未找到 $drv"; return 1; }
  if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] bash $drv --dry-run"; return 0; fi
  bash "$drv"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi