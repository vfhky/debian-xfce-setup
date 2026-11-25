#!/usr/bin/env bash
# Task 6 test: url components (proprietary/internal) — real default URLs wired; override works;
# only the no-public-URL one (nyaterm) skips. Fake `dpkg` so have-gate never masks URL logic.
# (Open-source apps moved to github type in t05; only wechat/qq/nyaterm remain url.)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"; cd "$REPO"
fail=0
asrt(){ if [ "$2" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
has(){ [[ "$1" == *"$2"* ]]; }

fakebin=$(mktemp -d); printf '#!/bin/sh\nexit 1\n' > "$fakebin/dpkg"; chmod +x "$fakebin/dpkg"

# comp | 期望默认主机
rows="
40-wechat|dldir1v6.qq.com
41-qq|qqdl.gtimg.cn
"
for c in 40-wechat 41-qq 43-nyaterm; do bash -n "components/$c.sh"; asrt "$c syntax" $?; done

while IFS='|' read -r c host; do
  [ -z "$c" ] && continue
  out=$(PATH="$fakebin:$PATH" DRY_RUN=1 bash "components/$c.sh" 2>&1); rc=$?
  asrt "$c default->exit0" $([ "$rc" = 0 ]; echo $?)
  has "$out" "[dry-run]"; asrt "$c default->dry-run" $?
  has "$out" "$host"; asrt "$c default->host $host" $?
done <<< "$rows"

# override works (representative)
out=$(PATH="$fakebin:$PATH" WECHAT_URL=https://e/x.deb DRY_RUN=1 bash components/40-wechat.sh 2>&1)
has "$out" "x.deb"; asrt "override WECHAT_URL honored" $?

# nyaterm: no public url -> skip
out=$(PATH="$fakebin:$PATH" DRY_RUN=1 bash components/43-nyaterm.sh 2>&1)
has "$out" "⊘"; asrt "nyaterm (no url)->skip" $?

out=$(bash init.sh --list 2>&1)
for id in wechat qq nyaterm; do has "$out" "$id"; asrt "list shows $id" $?; done
rm -rf "$fakebin"
exit "$fail"