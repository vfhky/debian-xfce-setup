#!/usr/bin/env bash
# component: windinput — 问剑输入法（官方直链；URL 留空则跳过）
set -uo pipefail
ID=windinput; TYPE=url; ORDER=42; DESC="WindInput 问剑输入法"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have windinput && { skip "windinput 已装"; return 0; }
  local URL="${WINDINPUT_URL:-}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 WINDINPUT_URL，从备份恢复"; return 0; }
  install_deb "windinput.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi