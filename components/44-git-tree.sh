#!/usr/bin/env bash
# component: git-tree — Git-Tree（官方直链；URL 留空则跳过）
set -uo pipefail
ID=git-tree; TYPE=url; ORDER=44; DESC="Git-Tree"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have git-tree && { skip "git-tree 已装"; return 0; }
  local URL="${GIT_TREE_URL:-}"
  [ -z "${URL//[[:space:]]/}" ] && { skip "未配置 GIT_TREE_URL，从备份恢复"; return 0; }
  install_deb "git-tree.deb" "$URL"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi