#!/usr/bin/env bash
# component: input-method — fcitx5 校验/安装（启用 WindInput 需用户在设置里手动开）
set -uo pipefail
ID=input-method; TYPE=script; ORDER=70; DESC="fcitx5 输入法"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  if have fcitx5; then skip "fcitx5 已装，请在 设置→输入法 启用 WindInput"; return 0; fi
  apt_install fcitx5 fcitx5-chinese-addons fcitx5-config-qt
  skip "已装 fcitx5，请在 设置→输入法 启用 WindInput 并重新登录"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi