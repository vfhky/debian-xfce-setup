#!/usr/bin/env bash
# Task 6 test: url components — empty URL -> skip (no wget); set URL -> dry-run download.
# Uses a fake `dpkg` (always "not installed") so the have-gate never masks the URL logic.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"; cd "$REPO"
fail=0
asrt(){ if [ "$2" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
has(){ [[ "$1" == *"$2"* ]]; }
hasnt(){ [[ "$1" != *"$2"* ]]; }

fakebin=$(mktemp -d); printf '#!/bin/sh\nexit 1\n' > "$fakebin/dpkg"; chmod +x "$fakebin/dpkg"
comps="40-wechat 41-qq 42-windinput 43-nyaterm 44-git-tree"
for c in $comps; do bash -n "components/$c.sh"; asrt "$c syntax" $?; done

for c in $comps; do
  id="${c#*-}"; out=$(PATH="$fakebin:$PATH" DRY_RUN=1 bash "components/$c.sh" 2>&1); rc=$?
  asrt "$c empty-url exit 0" $([ "$rc" = 0 ]; echo $?)
  has "$out" "⊘"; asrt "$c empty-url skips" $?
  hasnt "$out" "wget"; asrt "$c empty-url no wget" $?
  has "$out" "__RESULT__|$id|skip|"; asrt "$c empty-url result skip" $?
done

# set URL -> dry-run download (representative: wechat)
out=$(PATH="$fakebin:$PATH" WECHAT_URL=https://e/x.deb DRY_RUN=1 bash components/40-wechat.sh 2>&1)
has "$out" "[dry-run]"; asrt "set-url prints dry-run" $?
has "$out" "x.deb"; asrt "set-url shows file" $?

out=$(bash init.sh --list 2>&1)
for id in wechat qq windinput nyaterm git-tree; do has "$out" "$id"; asrt "list shows $id" $?; done
rm -rf "$fakebin"
exit "$fail"