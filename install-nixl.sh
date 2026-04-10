#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UCX_VERSION="${UCX_VERSION:-1.19.0}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/sgl-a100}"
NIXL_DIR="${NIXL_DIR:-${BASE_DIR}/nixl}"
NIXL_REPO_URL="${NIXL_REPO_URL:-https://github.com/ai-dynamo/nixl.git}"
UCX_PATH="${UCX_PATH:-${UCX_INSTALL_DIR:-${BASE_DIR}/ucx-${UCX_VERSION}}}"
CUDA_WHEEL="${CUDA_WHEEL:-cu13}" # cu12 or cu13
FORCE_REINSTALL="${FORCE_REINSTALL:-0}"
INSTALL_HEADERS="${INSTALL_HEADERS:-true}"

log() {
  echo "[install-nixl] $*"
}

if [[ "$CUDA_WHEEL" != "cu12" && "$CUDA_WHEEL" != "cu13" ]]; then
  echo "Unsupported CUDA_WHEEL='$CUDA_WHEEL'. Use 'cu12' or 'cu13'."
  exit 1
fi

ACTIVATE_SCRIPT="${UV_VENV_DIR}/bin/activate"
if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
  echo "Venv activate script not found: $ACTIVATE_SCRIPT"
  echo "Set UV_VENV_DIR to your uv venv path and re-run."
  exit 1
fi

if [[ ! -f "${UCX_PATH}/include/ucp/api/ucp.h" ]]; then
  echo "UCX headers not found at: ${UCX_PATH}/include/ucp/api/ucp.h"
  echo "Set UCX_PATH to the UCX install prefix (e.g. ${BASE_DIR}/ucx-${UCX_VERSION})."
  exit 1
fi

# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"
export PATH="$HOME/.local/bin:${PATH}"

PKG_NAME="nixl-${CUDA_WHEEL}"

if [[ "$FORCE_REINSTALL" != "1" ]] && [[ -f "${UV_VENV_DIR}/lib/libnixl.so" ]]; then
  if python -c "import nixl" >/dev/null 2>&1; then
    log "${PKG_NAME} appears installed and importable; skipping. Set FORCE_REINSTALL=1 to rebuild."
    uv pip list | grep -E '^nixl(-cu12|-cu13)?[[:space:]]' || true
    exit 0
  fi
fi

log "Installing build-time Python tooling in active venv"
uv pip install -U tomlkit meson ninja pybind11 build setuptools wheel

if [[ -d "${NIXL_DIR}/.git" ]]; then
  log "Updating existing nixl repo at ${NIXL_DIR}"
  git -C "$NIXL_DIR" pull --ff-only
else
  if [[ -e "$NIXL_DIR" ]]; then
    echo "Path exists and is not a git repo: $NIXL_DIR"
    exit 1
  fi
  log "Cloning nixl repo to ${NIXL_DIR}"
  mkdir -p "$(dirname "$NIXL_DIR")"
  git clone "$NIXL_REPO_URL" "$NIXL_DIR"
fi

cd "$NIXL_DIR"

log "Configuring NIXL Python wheel name for ${PKG_NAME}"
./contrib/tomlutil.py --wheel-name "$PKG_NAME" pyproject.toml

log "Removing old nixl packages from active venv"
python -m pip uninstall -y nixl nixl-cu12 nixl-cu13 || true

log "Installing local nixl package without resolving from PyPI"
uv pip install --no-deps .

log "Building NIXL native libs with Meson (libdir=lib for loader compatibility)"
rm -rf build
meson setup build \
  --prefix="$UV_VENV_DIR" \
  --libdir=lib \
  -Ducx_path="$UCX_PATH" \
  -Dinstall_headers="$INSTALL_HEADERS"
ninja -C build
ninja -C build install

log "Installing nixl meta wheel without resolving from PyPI"
uv pip install --no-deps build/src/bindings/python/nixl-meta/nixl-*-py3-none-any.whl

if [[ ! -f "${UV_VENV_DIR}/lib/libnixl.so" ]]; then
  echo "Expected shared library missing: ${UV_VENV_DIR}/lib/libnixl.so"
  exit 1
fi

log "Verifying nixl import"
python -c "import nixl; _ = nixl.nixl_agent('agent1')"
uv pip list | grep -E '^nixl(-cu12|-cu13)?[[:space:]]'

log "Done."
