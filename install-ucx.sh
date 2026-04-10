#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
UCX_VERSION="${UCX_VERSION:-1.19.0}"
UCX_INSTALL_DIR="${UCX_INSTALL_DIR:-${BASE_DIR}/ucx-${UCX_VERSION}}"
GDRCOPY_DIR="${GDRCOPY_DIR:-${BASE_DIR}/gdrcopy}"
UCX_SRC_PARENT="${UCX_SRC_PARENT:-${BASE_DIR}/src}"
UCX_SRC_DIR="${UCX_SRC_DIR:-${UCX_SRC_PARENT}/ucx-${UCX_VERSION}}"
UCX_TARBALL="${UCX_TARBALL:-${UCX_SRC_PARENT}/ucx-${UCX_VERSION}.tar.gz}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"

if [ -x "${UCX_INSTALL_DIR}/bin/ucx_info" ]; then
    echo "UCX already installed at ${UCX_INSTALL_DIR}; skipping."
    exit 0
fi

sudo apt update
sudo apt install -y build-essential autoconf automake libtool pkg-config \
    libnuma-dev rdma-core libibverbs-dev

mkdir -p "${BASE_DIR}" "${UCX_SRC_PARENT}" "$(dirname "${GDRCOPY_DIR}")"

cd "${BASE_DIR}"
if [ -d "${GDRCOPY_DIR}/.git" ]; then
    cd "${GDRCOPY_DIR}"
else
    git clone https://github.com/NVIDIA/gdrcopy.git "${GDRCOPY_DIR}"
    cd "${GDRCOPY_DIR}"
fi

make prefix="${GDRCOPY_DIR}" CUDA="${CUDA_HOME}" all install

if [ ! -f "${UCX_TARBALL}" ]; then
    wget -O "${UCX_TARBALL}" "https://github.com/openucx/ucx/releases/download/v${UCX_VERSION}/ucx-${UCX_VERSION}.tar.gz"
fi

if [ ! -d "${UCX_SRC_DIR}" ]; then
    tar -xzf "${UCX_TARBALL}" -C "${UCX_SRC_PARENT}"
fi

cd "${UCX_SRC_DIR}"

./configure                          \
	--prefix=${UCX_INSTALL_DIR}      \
    --enable-shared                    \
    --disable-static                   \
    --disable-doxygen-doc              \
    --enable-optimizations             \
    --enable-cma                       \
    --enable-devel-headers             \
    --with-cuda=${CUDA_HOME}           \
    --with-verbs                       \
    --with-dm                          \
    --with-gdrcopy=${GDRCOPY_DIR}      \
    --enable-mt
  
make -j$(nproc)
make install

"${UCX_INSTALL_DIR}/bin/ucx_info" -d | grep "cuda"
