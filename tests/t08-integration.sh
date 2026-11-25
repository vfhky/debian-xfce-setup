#!/usr/bin/env bash
# Task 8 test: integration — full syntax, --list, profile filtering, shim parity
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"; cd "$REPO"
fail=0
asrt(){ if [ "$2" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
has(){ [[ "$1" == *"$2"* ]]; }
hasnt(){ [[ "$1" != *"$2"* ]]; }

# all bash -n green
for f in lib/common.sh init.sh components/*.sh; do bash -n "$f"; asrt "syntax $f" $?; done

# --list lists every component id
out=$(bash init.sh --list 2>&1); asrt "list exit 0" $?
for id in sourcelist apt-base chrome sublime tailscale obsidian rustdesk clash-verge \
          wechat qq windinput nyaterm git-tree nvidia user-tools sdkm input-method telegram; do
  has "$out" "$id"; asrt "list shows $id" $?
done

# profile filters: desktop includes chrome, excludes wechat
out=$(bash init.sh --profile desktop --dry-run 2>&1); rc=$?
asrt "profile desktop exit 0" $([ "$rc" = 0 ]; echo $?)
has "$out" "__RESULT__|chrome|"; asrt "profile ran chrome" $?
hasnt "$out" "__RESULT__|wechat|"; asrt "profile skipped wechat" $?

# shim parity: init-system.sh == init.sh (compare id|state, ignore ms)
a=$(bash init-system.sh --dry-run 2>&1 | grep -E '^__RESULT__\|' | cut -d'|' -f2,3 | sort)
b=$(bash init.sh       --dry-run 2>&1 | grep -E '^__RESULT__\|' | cut -d'|' -f2,3 | sort)
asrt "shim parity with init.sh" $([ "$a" = "$b" ]; echo $?)
exit "$fail"