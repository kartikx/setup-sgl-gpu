export UCX_VERSION=1.20.0
export UCX_INSTALL_DIR=/mnt/data/ucx-${UCX_VERSION}
export CUDA_HOME=/usr/local/cuda
export UCX_ARCHIVE_URL="https://github.com/openucx/ucx/archive/refs/tags/v${UCX_VERSION}.tar.gz"

if [ -x "${UCX_INSTALL_DIR}/bin/ucx_info" ]; then
    echo "UCX already installed at ${UCX_INSTALL_DIR}; skipping."
    exit 0
fi

sudo apt update
sudo apt install -y build-essential autoconf automake libtool pkg-config \
    libnuma-dev rdma-core libibverbs-dev

cd /mnt/data
if [ -d /mnt/data/gdrcopy/.git ]; then
    cd /mnt/data/gdrcopy
else
    git clone git@github.com:NVIDIA/gdrcopy.git /mnt/data/gdrcopy
    cd /mnt/data/gdrcopy
fi

make prefix=/mnt/data/gdrcopy CUDA=/usr/local/cuda all install

cd /mnt/data
wget -O ucx-${UCX_VERSION}.tar.gz "${UCX_ARCHIVE_URL}"
tar -xzf ucx-${UCX_VERSION}.tar.gz
cd ucx-${UCX_VERSION}

./configure                          \
	--prefix=${UCX_INSTALL_DIR}      \
    --enable-shared                    \
    --disable-static                   \
    --disable-doxygen-doc              \
    --enable-optimizations             \
    --enable-cma                       \
    --enable-devel-headers             \
    --with-cuda=$CUDA_HOME         \
    --with-verbs                       \
    --with-dm                          \
    --with-gdrcopy=/mnt/data/gdrcopy   \
    --enable-mt
  
make -j$(nproc)
make install

"${UCX_INSTALL_DIR}/bin/ucx_info" -d | grep "cuda"
