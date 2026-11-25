#!/usr/bin/env bash
# component: sourcelist — 启用 apt contrib non-free（deb822 与 classic 两种格式）
set -uo pipefail
ID=sourcelist; TYPE=script; ORDER=0; DESC="启用 contrib non-free"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  local changed=0 f
  shopt -s nullglob
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    grep -qE '^Components:.*\bcontrib\b' "$f" 2>/dev/null && continue
    grep -qE '^deb [^#].*\bcontrib\b' "$f" 2>/dev/null && continue
    if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] 给 $f 补 contrib non-free"; changed=1; continue; fi
    cp -a "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ "$f" == *.sources ]]; then
      grep -qE '^Components:' "$f" && sed -i -E 's/^(Components:[^\n]*)\bmain\b/\1main contrib non-free/' "$f"
    else
      sed -i -E '/^deb [^#]/ s/ main non-free-firmware$/ main contrib non-free non-free-firmware/; /^deb [^#]/ s/ main$/ main contrib non-free/' "$f"
    fi
    changed=1
  done
  [ "$changed" = 1 ] || skip "contrib non-free 已启用"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi