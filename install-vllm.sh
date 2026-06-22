#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/vllm}"
VLLM_PACKAGE_SPEC="${VLLM_PACKAGE_SPEC:-vllm}"
VLLM_ROUTER_PACKAGE_SPEC="${VLLM_ROUTER_PACKAGE_SPEC:-vllm-router}"

log() {
  echo "[install-vllm] $*"
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

log "Installing vLLM package: ${VLLM_PACKAGE_SPEC}"
uv pip install --reinstall --upgrade "${VLLM_PACKAGE_SPEC}"

log "Installing vLLM router package: ${VLLM_ROUTER_PACKAGE_SPEC}"
uv pip install --reinstall --upgrade "${VLLM_ROUTER_PACKAGE_SPEC}"

log "Verifying vLLM imports and CLIs"
python -c "import vllm; import vllm_router.launch_router; print(vllm.__file__)"
vllm --help >/dev/null
python -m vllm_router.launch_router --help >/dev/null
uv pip show vllm >/dev/null
uv pip show vllm-router >/dev/null

log "Done."
