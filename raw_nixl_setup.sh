#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UCX_VERSION="${UCX_VERSION:-1.20}"
UV_VENV_DIR="${UV_VENV_DIR:-${BASE_DIR}/envs/sgl-a100}"
UCX_INSTALL_DIR="${UCX_INSTALL_DIR:-${BASE_DIR}/ucx-${UCX_VERSION}}"
NIXL_DIR="${NIXL_DIR:-${BASE_DIR}/nixl}"
UCX_SRC_DIR="${UCX_SRC_DIR:-${BASE_DIR}/ucx}"

# same env as sglang
source "${UV_VENV_DIR}/bin/activate"
export PATH="$HOME/.local/bin:$PATH"

# optional safety snapshot
uv pip freeze > "${BASE_DIR}/sgl-a100.pre-nixl.lock"

# system deps
sudo apt update
sudo apt install -y build-essential cmake pkg-config autoconf automake libtool \
  libnuma-dev rdma-core libibverbs-dev ninja-build

# UCX (README-tested branch is 1.20.x)
cd "${BASE_DIR}"
rm -rf "${UCX_SRC_DIR}"
mkdir -p "$(dirname "${UCX_SRC_DIR}")"
git clone https://github.com/openucx/ucx.git "${UCX_SRC_DIR}"
cd "${UCX_SRC_DIR}"
git checkout v1.20.x
./autogen.sh
./contrib/configure-release-mt \
  --prefix="${UCX_INSTALL_DIR}" \
  --enable-shared \
  --disable-static \
  --disable-doxygen-doc \
  --enable-optimizations \
  --enable-cma \
  --enable-devel-headers \
  --with-cuda=/usr/local/cuda \
  --with-verbs \
  --with-dm
make -j"$(nproc)"
make -j"$(nproc)" install-strip
"${UCX_INSTALL_DIR}/bin/ucx_info" -d | grep -i cuda

# NIXL (CUDA 13 variant)
cd "${BASE_DIR}"
rm -rf "${NIXL_DIR}"
git clone https://github.com/ai-dynamo/nixl.git "${NIXL_DIR}"
cd "${NIXL_DIR}"

uv pip install -U tomlkit meson ninja pybind11 build setuptools wheel

./contrib/tomlutil.py --wheel-name nixl-cu13 pyproject.toml

uv pip install --no-deps .
meson setup build \
  --prefix="${UV_VENV_DIR}" \
  --libdir=lib \
  -Ducx_path="${UCX_INSTALL_DIR}" \
  -Dinstall_headers=true
ninja -C build
ninja -C build install
uv pip install --no-deps build/src/bindings/python/nixl-meta/nixl-*-py3-none-any.whl

# verify
python -c "import nixl; a=nixl.nixl_agent('agent1'); print('nixl ok')"
uv pip list | grep -E 'nixl|sglang|torch|torchvision|transformers'
