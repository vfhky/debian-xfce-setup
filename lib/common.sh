#!/usr/bin/env bash
# lib/common.sh — 共享库：路径/日志/dry-run + 组件契约 component_main
# 被 components/*.sh 与 init.sh source。无副作用（除定义函数/变量）。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENTS_DIR="${COMPONENTS_DIR:-$REPO_ROOT/components}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"

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
# profile_ids <file> — 每行一个组件 id（# 注释）；兼容末行无换行
profile_ids(){
  local ln
  while IFS= read -r ln || [ -n "$ln" ]; do
    ln="${ln%%#*}"; ln="${ln//[[:space:]]/}"
    [ -n "$ln" ] && printf '%s\n' "$ln"
  done < "$1"
}

# ---- 安装器（失败一律返回非零）----
# install_deb <out-name> <url>：PKG_DIR 本地优先，否则下载后 apt install
install_deb(){
  local out="$1" url="$2" lp=""
  if [ -n "${PKG_DIR:-}" ]; then
    if   [ -f "$PKG_DIR/$out" ]; then lp="$PKG_DIR/$out"
    elif [ -f "$PKG_DIR/$(basename "$url")" ]; then lp="$PKG_DIR/$(basename "$url")"; fi
  fi
  if [ -n "$lp" ]; then
    if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] apt install -y %s\n' "$lp"; return 0; fi
    apt install -y "$lp"; return $?
  fi
  if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] wget -q -O %s %s && apt install -y %s\n' "$out" "$url" "$out"; return 0; fi
  local d f; d=$(mktemp -d); f="$d/$out"
  if wget -q -O "$f" "$url"; then apt install -y "$f"; local rc=$?; rm -rf "$d"; return $rc
  else warn "下载失败：$url"; rm -rf "$d"; return 1; fi
}
# gh_latest_deb <owner/repo> <regex>：github.com releases/latest + expanded_assets（避开 api 限流）
gh_latest_deb(){
  local repo="$1" pat="$2" tag page url
  if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] 取 GitHub 最新 %s 的 .deb (%s)\n' "$repo" "$pat"; return 0; fi
  tag=$(curl -sSI "https://github.com/$repo/releases/latest" 2>/dev/null | tr -d '\r' | awk -F/ '/^location:/{print $NF}' | tail -1)
  if [ -n "$tag" ]; then
    page=$(curl -sSL "https://github.com/$repo/releases/expanded_assets/$tag" 2>/dev/null)
    url=$(printf '%s' "$page" | grep -oE "/$repo/releases/download/[^\"]+\.deb" | grep -iE "$pat" | head -1)
    url="${url:+https://github.com$url}"
  fi
  if [ -z "$url" ]; then warn "GitHub 未匹配到 .deb：$repo — https://github.com/$repo/releases/latest"; return 1; fi
  install_deb "$(basename "$url")" "$url"
}
apt_install(){ if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] apt install -y %s\n' "$*"; return 0; fi; apt install -y "$@"; }
# add_apt_repo_dearmor <name> <keyring-url> <list-line>：下载 key 去 armor + 写 list（Chrome/Sublime）
add_apt_repo_dearmor(){
  local name="$1" keyurl="$2" line="$3" keyring="/usr/share/keyrings/$name.gpg"
  if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] add-apt-repo %s (dearmor key %s)\n' "$name" "$keyurl"; return 0; fi
  wget -qO- "$keyurl" | gpg --dearmor -o "$keyring" || return 1
  printf '%s\n' "$line" > "/etc/apt/sources.list.d/$name.list" || return 1
  apt-get update || return 1
}
# add_apt_repo_prebuilt <name> <keyring-url> <list-url>：下载现成 key+list（Tailscale）
add_apt_repo_prebuilt(){
  local name="$1" keyurl="$2" listurl="$3" keyring="/usr/share/keyrings/$name.gpg"
  if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] add-apt-repo %s (prebuilt key+list)\n' "$name"; return 0; fi
  curl -fsSL "$keyurl" -o "$keyring" || return 1
  curl -fsSL "$listurl" -o "/etc/apt/sources.list.d/$name.list" || return 1
  apt-get update || return 1
}

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