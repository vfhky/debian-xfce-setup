#!/usr/bin/env bash
# component: qq — QQ Linux（官方直链；URL 留空则跳过）。dpkg 包名为 linuxqq
set -uo pipefail
ID=qq; TYPE=url; ORDER=41; DESC="QQ (linuxqq)"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have linuxqq && { skip "linuxqq 已装"; return 0; }
  local URL="${QQ_URL:-}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 QQ_URL，从备份恢复"; return 0; }
  install_deb "qq.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi