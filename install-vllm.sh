#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/vllm}"
VLLM_PACKAGE_SPEC="${VLLM_PACKAGE_SPEC:-vllm}"
VLLM_ROUTER_PACKAGE_SPEC="${VLLM_ROUTER_PACKAGE_SPEC:-vllm-router}"
FIX_TORCHVISION="${FIX_TORCHVISION:-1}"

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

if [[ "$FIX_TORCHVISION" == "1" ]]; then
  TORCHVISION_REPAIR="$(python - <<'PY'
import re
import sys

try:
    import torch
except Exception as exc:
    print(f"ERROR: failed to import torch: {exc}", file=sys.stderr)
    sys.exit(1)

version = torch.__version__.split("+", 1)[0]
match = re.match(r"^2\.(\d+)\.(\d+)", version)
if not match:
    print(f"SKIP unsupported torch version format: {torch.__version__}")
    sys.exit(0)

torch_minor = int(match.group(1))
torch_patch = int(match.group(2))
torchvision_version = f"0.{torch_minor + 15}.{torch_patch}"

cuda_version = torch.version.cuda
if cuda_version is None:
    index_url = "https://download.pytorch.org/whl/cpu"
else:
    cuda_match = re.match(r"^(\d+)\.(\d+)", cuda_version)
    if not cuda_match:
        print(f"SKIP unsupported torch CUDA version format: {cuda_version}")
        sys.exit(0)
    index_url = f"https://download.pytorch.org/whl/cu{cuda_match.group(1)}{cuda_match.group(2)}"

print(f"{torchvision_version} {index_url}")
PY
)"

  if [[ "$TORCHVISION_REPAIR" == SKIP* ]]; then
    log "$TORCHVISION_REPAIR"
  else
    read -r TORCHVISION_VERSION TORCHVISION_INDEX_URL <<<"$TORCHVISION_REPAIR"
    log "Installing torchvision==${TORCHVISION_VERSION} from ${TORCHVISION_INDEX_URL}"
    uv pip install --reinstall --no-deps \
      --index-url "$TORCHVISION_INDEX_URL" \
      "torchvision==${TORCHVISION_VERSION}"
  fi
fi

log "Verifying vLLM imports and CLIs"
python -c "import torchvision; from torchvision.ops import nms; print('torchvision nms ok')"
python -c "import vllm; import vllm_router.launch_router; print(vllm.__file__)"
vllm --help >/dev/null
python -m vllm_router.launch_router --help >/dev/null
uv pip show vllm >/dev/null
uv pip show vllm-router >/dev/null

log "Done."
