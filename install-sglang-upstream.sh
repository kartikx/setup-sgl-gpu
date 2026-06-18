#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/sgl-upstream}"
UPSTREAM_SGLANG_VERSION="${UPSTREAM_SGLANG_VERSION:-0.5.4}"

log() {
  echo "[install-sglang-upstream] $*"
}

ACTIVATE_SCRIPT="${UV_VENV_DIR}/bin/activate"
if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
  echo "Venv activate script not found: $ACTIVATE_SCRIPT"
  echo "Set UV_VENV_DIR to your uv venv path and re-run."
  exit 1
fi

# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"
export PATH="$HOME/.local/bin:${PATH}"

log "Installing upstream SGLang from PyPI"
uv pip install --reinstall "sglang==${UPSTREAM_SGLANG_VERSION}"

log "Installing sglang-router"
uv pip install --upgrade sglang-router

log "Verifying upstream sglang import"
python -c "import sglang; print(sglang.__file__)"
uv pip show "sglang" | grep -E '^Version: '"${UPSTREAM_SGLANG_VERSION}"'$'
uv pip show sglang-router >/dev/null

log "Done."
