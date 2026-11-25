#!/usr/bin/env bash
# lib/common.sh — 共享库：路径/日志/dry-run + 组件契约 component_main
# 被 components/*.sh 与 init.sh source。无副作用（除定义函数/变量）。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENTS_DIR="$REPO_ROOT/components"
LOG_DIR="$REPO_ROOT/logs"

: "${DRY_RUN:=0}"; : "${STRICT:=0}"
for _a in "$@"; do case "$_a" in --dry-run) DRY_RUN=1;; --strict) STRICT=1;; esac; done

REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
REAL_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6 || true)"
[ -n "$REAL_HOME" ] || REAL_HOME="${HOME:-/root}"
PKG_DIR="${PKG_DIR:-$REAL_HOME/reinstall-pkgs}"
RESULT_STATE=ok

log(){  printf '%s\n' "$*"; }
warn(){ printf '⚠ %s\n' "$*" >&2; }
ok(){   printf '✓ %s\n' "$*"; }
fail(){ printf '✗ %s\n' "$*" >&2; }
die(){  printf '错误: %s\n' "$*" >&2; exit 1; }
skip(){ RESULT_STATE=skip; printf '⊘ %s\n' "$*" >&2; return 0; }

run(){ if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$*"; else eval "$@"; fi; }
as_user(){ if [ "$DRY_RUN" = 1 ]; then printf '[dry-run][user %s] %s\n' "$REAL_USER" "$*"; else sudo -u "$REAL_USER" -H bash -lc "$*"; fi; }
have(){ dpkg -s "$1" >/dev/null 2>&1; }

# component_main — 读 ID/TYPE/ORDER/DESC，在当前 shell 跑 body（保留 skip 状态），
# 输出经日志文件回放，末尾打印 __RESULT__|<id>|<ok|skip|fail>|<ms>；fail 退出 1，余 0。
component_main(){
  local id="${ID:-?}" type="${TYPE:-?}" order="${ORDER:-0}" desc="${DESC:-}"
  local tmp rc start end ms
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  tmp=$(mktemp); RESULT_STATE=ok
  {
    printf '\n\033[1;36m--- [%s] %s (type=%s order=%s) ---\033[0m\n' "$id" "$desc" "$type" "$order"
    start=$(date +%s%3N 2>/dev/null || date +%s)
    body; rc=$?
  } 1>"$tmp" 2>&1
  end=$(date +%s%3N 2>/dev/null || date +%s)
  [ "${rc:-0}" -ne 0 ] && RESULT_STATE=fail
  ms=$(( end - start ))
  {
    cat "$tmp"
    case "$RESULT_STATE" in
      fail) printf '✗ %s failed (exit %s)\n' "$id" "${rc:-?}" ;;
      skip) printf '⊘ %s skipped\n' "$id" ;;
      *)    printf '✓ %s ok\n' "$id" ;;
    esac
    printf '__RESULT__|%s|%s|%s\n' "$id" "$RESULT_STATE" "$ms"
  } | tee -a "$LOG_DIR/$id.log"
  rm -f "$tmp"
  [ "$RESULT_STATE" = fail ] && exit 1 || exit 0
}