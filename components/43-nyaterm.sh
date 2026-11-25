#!/usr/bin/env bash
# component: nyaterm — NyaTerm（官方/内部直链；URL 留空则跳过，本地优先）
set -uo pipefail
ID=nyaterm; TYPE=url; ORDER=43; DESC="NyaTerm"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have nyaterm && { skip "nyaterm 已装"; return 0; }
  local URL="${NYATERM_URL:-}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 NYATERM_URL，从备份恢复"; return 0; }
  install_deb "nyaterm.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi