#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UCX_VERSION="${UCX_VERSION:-1.19.0}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/sgl-a100}"
NIXL_DIR="${NIXL_DIR:-${BASE_DIR}/nixl}"
NIXL_REPO_URL="${NIXL_REPO_URL:-https://github.com/ai-dynamo/nixl.git}"
NIXL_COMMIT="${NIXL_COMMIT:-420c39c1000274d32f49cea5024e1e094492e695}"
UCX_PATH="${UCX_PATH:-${UCX_INSTALL_DIR:-${BASE_DIR}/ucx-${UCX_VERSION}}}"
FORCE_REINSTALL="${FORCE_REINSTALL:-0}"
INSTALL_HEADERS="${INSTALL_HEADERS:-true}"

log() {
  echo "[install-nixl] $*"
}

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
export LD_LIBRARY_PATH="${UV_VENV_DIR}/lib:${UV_VENV_DIR}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

if [[ "$FORCE_REINSTALL" != "1" ]]; then
  if python -c "import nixl" >/dev/null 2>&1; then
    log "nixl appears installed and importable; skipping. Set FORCE_REINSTALL=1 to rebuild."
    uv pip list | grep -E '^nixl[[:space:]]' || true
    exit 0
  fi
fi

log "Installing build-time Python tooling in active venv"
uv pip install -U patchelf meson-python cmake ninja pybind11 build setuptools wheel

if [[ -d "${NIXL_DIR}/.git" ]]; then
  log "Updating existing nixl repo at ${NIXL_DIR}"
  git -C "$NIXL_DIR" fetch --all --tags
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

if ! git rev-parse --verify "${NIXL_COMMIT}^{commit}" >/dev/null 2>&1; then
  echo "Requested NIXL_COMMIT not found: ${NIXL_COMMIT}"
  exit 1
fi
log "Checking out pinned NIXL commit: ${NIXL_COMMIT}"
git checkout -f "${NIXL_COMMIT}"
git show --no-patch --oneline "${NIXL_COMMIT}"

log "Removing old nixl packages from active venv"
uv pip uninstall -y nixl nixl-cu12 nixl-cu13 || true

log "Building/installing NIXL from pinned commit via meson-python"
python -m pip install --no-build-isolation --force-reinstall \
  --config-settings=setup-args=-Ducx_path="${UCX_PATH}" \
  --config-settings=setup-args=-Dinstall_headers="${INSTALL_HEADERS}" \
  .

# Persist NIXL loader paths whenever this venv is activated.
# Without this, plugin loading can fail in fresh shells with:
#   libucp.so.0 / libplugin_UCX.so not found
ACTIVATE_MARKER="# >>> nixl/ucx runtime libs >>>"
if ! grep -qF "$ACTIVATE_MARKER" "$ACTIVATE_SCRIPT"; then
  log "Persisting NIXL runtime library paths into ${ACTIVATE_SCRIPT}"
  cat >> "$ACTIVATE_SCRIPT" <<'EOF'

# >>> nixl/ucx runtime libs >>>
if [ -n "${VIRTUAL_ENV:-}" ]; then
  _NIXL_MESONPY_LIBS="$(python - <<'PY'
import sysconfig
print(sysconfig.get_paths().get('purelib', ''))
PY
)"
  _NIXL_MESONPY_LIBS="${_NIXL_MESONPY_LIBS}/.nixl.mesonpy.libs"
  _NIXL_MESONPY_PLUGINS="${_NIXL_MESONPY_LIBS}/plugins"
  _UCX_PREFIX="__UCX_PREFIX__"
  export LD_LIBRARY_PATH="${_UCX_PREFIX}/lib:${_NIXL_MESONPY_PLUGINS}:${_NIXL_MESONPY_LIBS}:${VIRTUAL_ENV}/lib:${VIRTUAL_ENV}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
  unset _NIXL_MESONPY_LIBS _NIXL_MESONPY_PLUGINS _UCX_PREFIX
fi
# <<< nixl/ucx runtime libs <<<
EOF
  sed -i "s|__UCX_PREFIX__|${UCX_PATH}|g" "$ACTIVATE_SCRIPT"
fi

log "Verifying nixl import"
python -c "import nixl; from nixl._api import nixl_agent; _ = nixl_agent('agent1')"
uv pip list | grep -E '^nixl[[:space:]]'

log "Done."
