#!/usr/bin/env bash
# component: chrome — Google Chrome（官方 apt 仓库，自包含）
set -uo pipefail
ID=chrome; TYPE=apt_repo; ORDER=20; DESC="Google Chrome"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have google-chrome-stable && { skip "google-chrome-stable 已装"; return 0; }
  add_apt_repo_dearmor google-chrome "https://dl.google.com/linux/linux_signing_key.pub" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"
  apt_install google-chrome-stable
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi