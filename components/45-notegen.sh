#!/usr/bin/env bash
# component: notegen — NoteGen（GitHub release 直链，默认已填；可 NOTEGEN_URL 覆盖）
set -uo pipefail
ID=notegen; TYPE=url; ORDER=45; DESC="NoteGen（可选）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have notegen && { skip "notegen 已装"; return 0; }
  local URL="${NOTEGEN_URL:-https://github.com/codexu/note-gen/releases/download/note-gen-v0.39.2/NoteGen_0.39.2_amd64.deb}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 NOTEGEN_URL"; return 0; }
  install_deb "notegen.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi