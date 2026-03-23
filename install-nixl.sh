#!/usr/bin/env bash
set -euo pipefail

UV_VENV_DIR="${UV_VENV_DIR:-/mnt/data/envs/vllm-source/.venv}"
NIXL_DIR="${NIXL_DIR:-$HOME/nixl}"
UCX_PATH="${UCX_PATH:-/mnt/data/ucx-1.19.0/lib/ucx}"
INSTALL_PREFIX="${INSTALL_PREFIX:-$UV_VENV_DIR}"

ACTIVATE_SCRIPT="${UV_VENV_DIR}/bin/activate"
if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
  echo "Venv activate script not found: $ACTIVATE_SCRIPT"
  echo "Set UV_VENV_DIR to your uv venv path and re-run."
  exit 1
fi

# shellcheck disable=SC1090
source "$ACTIVATE_SCRIPT"

uv pip install meson

if [[ -d "${NIXL_DIR}/.git" ]]; then
  git -C "$NIXL_DIR" pull --ff-only
else
  git clone https://github.com/ai-dynamo/nixl "$NIXL_DIR"
fi
cd "$NIXL_DIR"

rm -rf build
mkdir build

uv run --active meson setup build \
    --prefix="$INSTALL_PREFIX" \
    --libdir=lib \
    -Ducx_path="$UCX_PATH" \
    -Dinstall_headers=true

uv run --active meson compile -C build
uv run --active meson install -C build

echo "Verifying nixl in active uv environment..."
if ! uv pip list | grep -E '^nixl[[:space:]]'; then
  echo "nixl was not found in the active uv environment."
  exit 1
fi
