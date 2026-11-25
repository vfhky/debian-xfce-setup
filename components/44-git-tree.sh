#!/usr/bin/env bash
# component: git-tree — Git-Tree（开源，优先 GitHub 最新 .deb）
set -uo pipefail
ID=git-tree; TYPE=github; ORDER=44; DESC="Git-Tree（GitHub 最新）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have git-tree && { skip "git-tree 已装"; return 0; }
  gh_latest_deb git-tree-app/gittree 'Git-Tree.*amd64\.deb'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi