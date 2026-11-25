#!/usr/bin/env bash
# Task 7 test: script components well-formed; 50-nvidia forwards --dry-run; skip paths.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"; cd "$REPO"
fail=0
asrt(){ if [ "$2" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
has(){ [[ "$1" == *"$2"* ]]; }

comps="50-nvidia 60-user-tools 61-sdkm 70-input-method 90-telegram"
for c in $comps; do bash -n "components/$c.sh"; asrt "$c syntax" $?; done

# 50-nvidia forwards --dry-run (root-free: dry-run only prints the invocation)
out=$(DRY_RUN=1 bash components/50-nvidia.sh 2>&1); rc=$?
asrt "nvidia exit 0" $([ "$rc" = 0 ]; echo $?)
has "$out" "init-nvidia-driver.sh --dry-run"; asrt "nvidia forwards --dry-run" $?

# the rest: run in dry-run, exit 0, emit result line
for c in 60-user-tools 61-sdkm 70-input-method 90-telegram; do
  id="${c#*-}"; out=$(DRY_RUN=1 bash "components/$c.sh" 2>&1); rc=$?
  asrt "$c exit 0" $([ "$rc" = 0 ]; echo $?)
  has "$out" "__RESULT__|$id|"; asrt "$c result line" $?
done
# sdkm skip (either not-found or already-there guidance -> always skip)
out=$(DRY_RUN=1 bash components/61-sdkm.sh 2>&1); has "$out" "⊘"; asrt "sdkm skips" $?

out=$(bash init.sh --list 2>&1)
for id in nvidia user-tools sdkm input-method telegram; do has "$out" "$id"; asrt "list shows $id" $?; done
exit "$fail"