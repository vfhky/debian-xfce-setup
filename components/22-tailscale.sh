#!/usr/bin/env bash
# component: tailscale — Tailscale（官方现成 key+list，自包含）
# 注：keyring 名用 tailscale-archive-keyring，匹配官方 .list 里的 signed-by 路径
set -uo pipefail
ID=tailscale; TYPE=apt_repo; ORDER=22; DESC="Tailscale"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  have tailscale && { skip "tailscale 已装"; return 0; }
  add_apt_repo_prebuilt tailscale-archive-keyring \
    "https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg" \
    "https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list"
  apt_install tailscale
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi