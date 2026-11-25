#!/usr/bin/env bash
# init-system.sh — 向后兼容 shim：转发到组件化编排器 init.sh
# （旧的单体入口保留此名，老命令 `sudo bash init-system.sh ...` 仍可用）
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$HERE/init.sh" "$@"