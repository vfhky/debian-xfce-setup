#!/usr/bin/env bash
# component: windinput — 清风输入法 WindInput（官方直链，默认已填；可 WINDINPUT_URL 覆盖）
set -uo pipefail
ID=windinput; TYPE=url; ORDER=42; DESC="清风输入法 WindInput"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have windinput && { skip "windinput 已装"; return 0; }
  local URL="${WINDINPUT_URL:-https://dl.windinput.com/WindInput-0.133.0-linux-amd64.deb}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 WINDINPUT_URL，从备份恢复"; return 0; }
  install_deb "windinput.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi