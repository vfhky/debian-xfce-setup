#!/usr/bin/env bash
# component: nyaterm — NyaTerm（开源，优先 GitHub 最新 .deb）
set -uo pipefail
ID=nyaterm; TYPE=github; ORDER=43; DESC="NyaTerm（GitHub 最新）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have nyaterm && { skip "nyaterm 已装"; return 0; }
  gh_latest_deb nyakang/nyaterm 'NyaTerm.*linux_x64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi