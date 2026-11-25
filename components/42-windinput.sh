#!/usr/bin/env bash
# component: windinput — 清风输入法 WindInput（开源，优先 GitHub 最新 .deb）
set -uo pipefail
ID=windinput; TYPE=github; ORDER=42; DESC="清风输入法 WindInput（GitHub 最新）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have windinput && { skip "windinput 已装"; return 0; }
  gh_latest_deb huanfeng/WindInput 'WindInput-.*linux-amd64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi