#!/usr/bin/env bash
# init.sh — 编排器：发现 components/*.sh，选择/组合，隔离子进程执行，三态汇总。
# 用法: sudo bash init.sh [--dry-run] [--strict] [--list] [--profile <name>] [id...]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"   # 提供 REPO_ROOT/COMPONENTS_DIR/LOG_DIR/DRY_RUN/STRICT/die 等

DO_LIST=0; PROFILE=""; IDS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --list) DO_LIST=1; shift;;
    --dry-run|--strict) shift;;                 # common.sh 已解析
    --profile) PROFILE="${2:-}"; shift 2;;
    --profile=*) PROFILE="${1#*=}"; shift;;
    --) shift; while [ $# -gt 0 ]; do IDS+=("$1"); shift; done;;
    -*) shift;;
    *) IDS+=("$1"); shift;;
  esac
done

# 发现 + 建 id→file 映射（按文件名排序）
declare -A BYID=(); ALL=()
while IFS= read -r f; do
  b=$(basename "$f"); id="${b#*-}"; id="${id%.sh}"
  ALL+=("$f"); BYID["$id"]="$f"
done < <(ls -1 "$COMPONENTS_DIR"/*.sh 2>/dev/null | sort)

# --list：source 读元数据（守卫阻止执行 body）
if [ "$DO_LIST" = 1 ]; then
  [ ${#ALL[@]} -gt 0 ] || die "未发现组件：$COMPONENTS_DIR"
  for f in "${ALL[@]}"; do
    ( source "$f"; printf '%-14s %-8s %-4s %s\n' "$ID" "$TYPE" "$ORDER" "$DESC" )
  done
  exit 0
fi

# 真装需 root（dry-run 免）
if [ "$DRY_RUN" != 1 ]; then [ "${EUID:-$(id -u)}" -eq 0 ] || die "请用 sudo 运行：  sudo bash $0 $*"; fi

# 选择集：profile > argv id > 全部
run_files=(); unknown=()
if [ -n "$PROFILE" ]; then
  pf="$HERE/profiles/$PROFILE.conf"; [ -f "$pf" ] || die "profile 不存在：$pf"
  mapfile -t sel < <(profile_ids "$pf")
  for id in "${sel[@]}"; do [ -n "${BYID[$id]:-}" ] && run_files+=("${BYID[$id]}") || unknown+=("$id"); done
elif [ ${#IDS[@]} -gt 0 ]; then
  for id in "${IDS[@]}"; do [ -n "${BYID[$id]:-}" ] && run_files+=("${BYID[$id]}") || unknown+=("$id"); done
else
  run_files=("${ALL[@]}")
fi
[ ${#unknown[@]} -gt 0 ] && die "未知组件 id：${unknown[*]}（用 --list 查看）"
[ ${#run_files[@]} -gt 0 ] || die "没有要运行的组件"

# 隔离执行 + 解析 __RESULT__ + 汇总
cargs=(); [ "$DRY_RUN" = 1 ] && cargs+=(--dry-run)
declare -a S_ID S_ST S_MS; nok=0; nf=0; ns=0
log "运行 ${#run_files[@]} 个组件（dry_run=$DRY_RUN）"
for f in "${run_files[@]}"; do
  b=$(basename "$f"); id="${b#*-}"; id="${id%.sh}"
  out=$(DRY_RUN="$DRY_RUN" bash "$f" "${cargs[@]}" 2>&1); rc=$?
  printf '%s\n' "$out"
  rl=$(printf '%s\n' "$out" | grep -E '^__RESULT__\|' | tail -1)
  if [ -n "$rl" ]; then st=$(printf '%s' "$rl" | cut -d'|' -f3); ms=$(printf '%s' "$rl" | cut -d'|' -f4)
  else st=fail; ms=0; warn "组件 $id 未输出结果行（崩溃/退出 $rc）→ 记 ✗"; fi
  S_ID+=("$id"); S_ST+=("$st"); S_MS+=("$ms")
  case "$st" in ok) nok=$((nok+1));; skip) ns=$((ns+1));; *) nf=$((nf+1));; esac
  if [ "$st" = fail ] && [ "$STRICT" = 1 ]; then warn "--strict：遇 ✗ 停止"; break; fi
done

printf '\n\033[1m=== 汇总 ===\033[0m\n'
sym(){ case "$1" in ok) printf '✓';; skip) printf '⊘';; *) printf '✗';; esac; }
for i in "${!S_ID[@]}"; do printf '  %-14s %s  %sms\n' "${S_ID[$i]}" "$(sym "${S_ST[$i]}")" "${S_MS[$i]}"; done
printf '总计: ✓%d ✗%d ⊘%d\n' "$nok" "$nf" "$ns"
[ "$nf" -gt 0 ] && exit 1 || exit 0