#!/usr/bin/env bash
# Task 5 test: github-latest components well-formed + runnable (install-state independent)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"; cd "$REPO"
fail=0
asrt(){ if [ "$2" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
has(){ [[ "$1" == *"$2"* ]]; }

comps="30-obsidian 31-rustdesk 32-clash-verge"
for c in $comps; do bash -n "components/$c.sh"; asrt "$c syntax" $?; done
for c in $comps; do
  id="${c#*-}"; out=$(DRY_RUN=1 bash "components/$c.sh" 2>&1); rc=$?
  asrt "$c exit 0" $([ "$rc" = 0 ]; echo $?)
  has "$out" "__RESULT__|$id|"; asrt "$c emits result line" $?
done
out=$(bash init.sh --list 2>&1)
for id in obsidian rustdesk clash-verge; do has "$out" "$id"; asrt "list shows $id" $?; done
exit "$fail"