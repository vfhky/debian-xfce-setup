#!/usr/bin/env bash
# Task 2 test: installers (install_deb local-first, gh_latest_deb, dry-run)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/common.sh"
fail=0
assert_contains(){ if [[ "$1" == *"$2"* ]]; then echo "ok: $3"; else echo "FAIL: $3 (missing '$2')"; fail=1; fi; }
assert_not_contains(){ if [[ "$1" != *"$2"* ]]; then echo "ok: $3"; else echo "FAIL: $3 (unexpected '$2')"; fail=1; fi; }
assert_rc(){ if [ "$1" = "$2" ]; then echo "ok: $3"; else echo "FAIL: $3 (got '$1' want '$2')"; fail=1; fi; }

# (1) dry-run download path
out=$(DRY_RUN=1 install_deb x.deb https://example.com/x.deb 2>&1); rc=$?
assert_rc "$rc" 0 "dry-run download exits 0"
assert_contains "$out" "[dry-run]" "download dry-run prints marker"

# (2) local-first: PKG_DIR has the file -> use it, no wget
pd=$(mktemp -d); : > "$pd/x.deb"; PKG_DIR="$pd"
out=$(DRY_RUN=1 install_deb x.deb https://example.com/x.deb 2>&1); rc=$?
assert_rc "$rc" 0 "local-first exits 0"
assert_contains "$out" "$pd/x.deb" "local-first uses local path"
assert_not_contains "$out" "wget" "local-first skips wget"
rm -rf "$pd"; PKG_DIR=""

# (3) gh no-match returns non-zero (real mode: nonexistent repo -> no match, no install)
out=$(gh_latest_deb nonexistent-owner-xyz/nope 'x\.deb' 2>&1); rc=$?
assert_rc "$rc" 1 "gh no-match returns non-zero"

exit "$fail"