#!/usr/bin/env bash
# component: apt-base — B 组常用 apt 包（官方 Debian 源）
set -uo pipefail
ID=apt-base; TYPE=apt; ORDER=10; DESC="B 组常用 apt 包"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  apt_install git gh curl wget vim ripgrep \
    git-gui gitk git-cola rabbitvcs-thunar rabbitvcs-cli keepassxc \
    xfce4-docklike-plugin bluetooth bluez blueman libspa-0.2-bluetooth
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi