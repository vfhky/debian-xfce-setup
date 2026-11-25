#!/usr/bin/env bash
# Task 3 test: orchestrator (list / three-state summary / unknown id / crash isolation)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
COMMON="$REPO/lib/common.sh"
fail=0
asrt(){ if [ "$2" = 0 ]; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
has(){ [[ "$1" == *"$2"* ]]; }

tmp=$(mktemp -d); comp="$tmp/components"; logs="$tmp/logs"; mkdir -p "$comp"
mk(){ local f="$comp/$1" id="$2" st="$3" body
  case "$st" in
    ok)    body='body(){ log "ok ran"; }';;
    fail)  body='body(){ log "fail ran"; return 3; }';;
    skip)  body='body(){ skip "nope"; }';;
    crash) body='body(){ log "crash now"; exit 7; }';;
  esac
  cat > "$f" <<EOF
#!/usr/bin/env bash
set -uo pipefail
ID=$id; TYPE=test; ORDER=0; DESC="$id desc"
source "$COMMON"
$body
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then component_main; fi
EOF
}
mk 00-a.sh a ok; mk 10-b.sh b fail; mk 20-c.sh c skip; mk 30-d.sh d crash
export COMPONENTS_DIR="$comp" LOG_DIR="$logs"

# (1) --list
out=$(bash "$REPO/init.sh" --list 2>&1); rc=$?
asrt "list exits 0" $([ "$rc" = 0 ]; echo $?)
for id in a b c d; do has "$out" "$id"; asrt "list shows $id" $?; done

# (2) run --dry-run: three states, nonzero, crash isolated (a still ran)
out=$(bash "$REPO/init.sh" --dry-run 2>&1); rc=$?
asrt "run exits nonzero" $([ "$rc" -ne 0 ]; echo $?)
has "$out" "✓"; asrt "summary has ok" $?
has "$out" "✗"; asrt "summary has fail" $?
has "$out" "⊘"; asrt "summary has skip" $?
has "$out" "__RESULT__|a|ok|"; asrt "a ran despite d crash" $?
has "$out" "总计: ✓1 ✗2 ⊘1"; asrt "summary counts 1/2/1" $?

# (3) unknown id
out=$(bash "$REPO/init.sh" --dry-run zzz 2>&1); rc=$?
asrt "unknown id nonzero" $([ "$rc" -ne 0 ]; echo $?)

rm -rf "$tmp"
exit "$fail"