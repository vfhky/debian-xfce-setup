#!/usr/bin/env bash
# component: notegen — NoteGen（开源，优先 GitHub 最新 .deb；可选）
set -uo pipefail
ID=notegen; TYPE=github; ORDER=45; DESC="NoteGen（GitHub 最新，可选）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have notegen && { skip "notegen 已装"; return 0; }
  gh_latest_deb codexu/note-gen 'NoteGen.*amd64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi