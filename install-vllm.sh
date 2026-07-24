#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/vllm}"
VLLM_PACKAGE_SPEC="${VLLM_PACKAGE_SPEC:-vllm}"
VLLM_ROUTER_PACKAGE_SPEC="${VLLM_ROUTER_PACKAGE_SPEC:-vllm-router}"
INSTALL_VLLM_PACKAGES="${INSTALL_VLLM_PACKAGES:-1}"
FIX_TORCHVISION="${FIX_TORCHVISION:-1}"
UNINSTALL_BROKEN_TORCHVISION="${UNINSTALL_BROKEN_TORCHVISION:-1}"
VERIFY_VLLM="${VERIFY_VLLM:-1}"

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

ensure_torchvision_usable_or_absent() {
  local failure_message="$1"

  if python - <<'PY' >/dev/null 2>&1
import importlib.util
import sys

if importlib.util.find_spec("torchvision") is None:
    sys.exit(0)

import torchvision
from torchvision.ops import nms
PY
  then
    log "torchvision is usable or absent"
    return
  fi

  if [[ "$UNINSTALL_BROKEN_TORCHVISION" != "1" ]]; then
    log "$failure_message"
    return 1
  fi

  log "$failure_message; uninstalling torchvision so transformers skips it"
  uv pip uninstall -y torchvision || true
}

repair_torchvision() {
  if [[ "$FIX_TORCHVISION" != "1" ]]; then
    log "Skipping torchvision repair because FIX_TORCHVISION=$FIX_TORCHVISION"
    return
  fi

  local repair_spec
  repair_spec="$(python - <<'PY'
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

  if [[ "$repair_spec" == SKIP* ]]; then
    log "$repair_spec"
    ensure_torchvision_usable_or_absent "torchvision compatibility could not be inferred and installed torchvision is broken"
    return
  fi

  local torchvision_version
  local torchvision_index_url
  read -r torchvision_version torchvision_index_url <<<"$repair_spec"

  log "Installing torchvision==${torchvision_version} from ${torchvision_index_url}"
  if ! uv pip install --reinstall --no-deps \
      --index-url "$torchvision_index_url" \
      "torchvision==${torchvision_version}"; then
    if [[ "$UNINSTALL_BROKEN_TORCHVISION" != "1" ]]; then
      return 1
    fi
    log "torchvision repair install failed; uninstalling torchvision so transformers skips it"
    uv pip uninstall -y torchvision || true
    return
  fi

  ensure_torchvision_usable_or_absent "torchvision import is still broken after installing the matching wheel"
}

if [[ "$INSTALL_VLLM_PACKAGES" == "1" ]]; then
  log "Installing vLLM package: ${VLLM_PACKAGE_SPEC}"
  uv pip install --reinstall --upgrade "${VLLM_PACKAGE_SPEC}"

  log "Installing vLLM router package: ${VLLM_ROUTER_PACKAGE_SPEC}"
  uv pip install --reinstall --upgrade "${VLLM_ROUTER_PACKAGE_SPEC}"
else
  log "Skipping vLLM package install because INSTALL_VLLM_PACKAGES=$INSTALL_VLLM_PACKAGES"
fi

repair_torchvision

if [[ "$VERIFY_VLLM" == "1" ]]; then
  log "Verifying vLLM imports and CLIs"
  python - <<'PY'
import importlib.util

if importlib.util.find_spec("torchvision") is None:
    print("torchvision not installed; transformers will skip it")
else:
    import torchvision
    from torchvision.ops import nms
    print("torchvision nms ok")
PY
  python -c "import vllm; import vllm_router.launch_router; print(vllm.__file__)"
  vllm --help >/dev/null
  python -m vllm_router.launch_router --help >/dev/null
  uv pip show vllm >/dev/null
  uv pip show vllm-router >/dev/null
else
  log "Skipping vLLM verification because VERIFY_VLLM=$VERIFY_VLLM"
fi

log "Done."
