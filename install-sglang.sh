#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/sgl-a100}"
SGLANG_DIR="${SGLANG_DIR:-${BASE_DIR}/sglang}"

log() {
  echo "[install-sglang] $*"
}

ACTIVATE_SCRIPT="${UV_VENV_DIR}/bin/activate"
if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
  echo "Venv activate script not found: $ACTIVATE_SCRIPT"
  echo "Set UV_VENV_DIR to your uv venv path and re-run."
  exit 1
fi

if [[ ! -f "${SGLANG_DIR}/python/pyproject.toml" ]]; then
  echo "SGLang python package not found at: ${SGLANG_DIR}/python/pyproject.toml"
  echo "Set SGLANG_DIR to your sglang repo checkout and re-run."
  exit 1
fi

# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"
export PATH="$HOME/.local/bin:${PATH}"

cd "$SGLANG_DIR"

log "Reinstalling SGLang after UCX/NIXL setup"
uv pip install --reinstall -e "python" --prerelease=allow
uv pip install --upgrade matplotlib transformers

log "Verifying sglang import"
python -c "import sglang; print(sglang.__file__)"

log "Done."
