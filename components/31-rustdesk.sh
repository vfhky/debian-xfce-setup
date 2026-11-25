#!/usr/bin/env bash
# component: rustdesk — RustDesk（GitHub 最新 .deb）
set -uo pipefail
ID=rustdesk; TYPE=github; ORDER=31; DESC="RustDesk（GitHub 最新）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have rustdesk && { skip "rustdesk 已装"; return 0; }
  gh_latest_deb rustdesk/rustdesk 'rustdesk-.*x86_64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi