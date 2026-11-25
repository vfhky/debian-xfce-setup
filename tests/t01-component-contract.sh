#!/usr/bin/env bash
# Task 1 test: component_main three-state contract
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/common.sh"

fail=0
assert_contains(){ local hay="$1" needle="$2" msg="$3"; if [[ "$hay" == *"$needle"* ]]; then echo "ok: $msg"; else echo "FAIL: $msg (missing '$needle')"; fail=1; fi; }
assert_eq(){ if [ "$1" = "$2" ]; then echo "ok: $3"; else echo "FAIL: $3 (got '$1' want '$2')"; fail=1; fi; }

# case 1: skip -> __RESULT__|t|skip| , exit 0
ID=t; TYPE=t; ORDER=0; DESC=d
body(){ skip "no url"; }
out=$(DRY_RUN=1 component_main 2>&1); rc=$?
assert_contains "$out" "__RESULT__|t|skip|" "skip emits result line"
assert_eq "$rc" "0" "skip exits 0"

# case 2: fail -> __RESULT__|t|fail| , exit 1
body(){ return 3; }
out=$(DRY_RUN=1 component_main 2>&1); rc=$?
assert_contains "$out" "__RESULT__|t|fail|" "fail emits result line"
assert_eq "$rc" "1" "fail exits 1"

exit "$fail"