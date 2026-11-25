#!/usr/bin/env bash
# component: telegram — 从备份恢复 ~/.local/opt/Telegram（绿色安装，非 apt）
set -uo pipefail
ID=telegram; TYPE=script; ORDER=90; DESC="Telegram（备份恢复）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  if [ -d "$REAL_HOME/.local/opt/Telegram" ]; then skip "已存在 ~/.local/opt/Telegram"
  else skip "未装 Telegram，从备份恢复 ~/.local/opt/Telegram"; fi
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi