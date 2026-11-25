#!/usr/bin/env bash
# component: sublime — Sublime Text（官方 apt 仓库，自包含）
set -uo pipefail
ID=sublime; TYPE=apt_repo; ORDER=21; DESC="Sublime Text"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have sublime-text && { skip "sublime-text 已装"; return 0; }
  add_apt_repo_dearmor sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/sublime-text.gpg] https://download.sublimetext.com/apt/stable/ stable main"
  apt_install sublime-text
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi