#!/usr/bin/env bash
# component: wechat — 微信（官方直链；URL 留空则跳过）
set -uo pipefail
ID=wechat; TYPE=url; ORDER=40; DESC="微信 WeChat"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have wechat && { skip "wechat 已装"; return 0; }
  local URL="${WECHAT_URL:-}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 WECHAT_URL，从备份恢复"; return 0; }
  install_deb "wechat.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi