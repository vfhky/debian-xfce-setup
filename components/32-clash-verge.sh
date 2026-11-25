#!/usr/bin/env bash
# component: clash-verge — Clash Verge（GitHub 最新 .deb）
set -uo pipefail
ID=clash-verge; TYPE=github; ORDER=32; DESC="Clash Verge（GitHub 最新）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have clash-verge && { skip "clash-verge 已装"; return 0; }
  gh_latest_deb clash-verge-rev/clash-verge-rev 'clash.*verge.*amd64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi