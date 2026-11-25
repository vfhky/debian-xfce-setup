#!/usr/bin/env bash
# component: sdkm — 运行时 Node/Go（由 sdkm 管理；本组件只做存在性校验与指引）
set -uo pipefail
ID=sdkm; TYPE=script; ORDER=61; DESC="sdkm 运行时(Node/Go)"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  if [ -x "$REAL_HOME/.sdkm/sdkm" ]; then
    skip "已存在 ~/.sdkm，请用： sdkm install node 26.13.0 / go 1.27.3"
  else
    skip "未找到 ~/.sdkm，从备份恢复后再装 Node 26.13.0 / Go 1.27.3"
  fi
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi