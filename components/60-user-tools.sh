#!/usr/bin/env bash
# component: user-tools — uv / claude（用户级，command -v 幂等）
set -uo pipefail
ID=user-tools; TYPE=script; ORDER=60; DESC="uv / claude（用户级）"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
body(){
  as_user 'command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh'
  as_user 'command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash'
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then component_main; fi