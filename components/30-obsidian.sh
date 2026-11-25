#!/usr/bin/env bash
# component: obsidian — Obsidian（GitHub 最新 .deb）
set -uo pipefail
ID=obsidian; TYPE=github; ORDER=30; DESC="Obsidian（GitHub 最新）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have obsidian && { skip "obsidian 已装"; return 0; }
  gh_latest_deb obsidianmd/obsidian-releases 'obsidian.*amd64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi