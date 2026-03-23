# same env as sglang
source /mnt/data/envs/sgl-a100/bin/activate
export PATH="$HOME/.local/bin:$PATH"

# optional safety snapshot
uv pip freeze > /mnt/data/sgl-a100.pre-nixl.lock

# system deps
sudo apt update
sudo apt install -y build-essential cmake pkg-config autoconf automake libtool \
  libnuma-dev rdma-core libibverbs-dev ninja-build

# UCX (README-tested branch is 1.20.x)
cd /mnt/data
rm -rf ucx
git clone https://github.com/openucx/ucx.git
cd ucx
git checkout v1.20.x
./autogen.sh
./contrib/configure-release-mt \
  --prefix=/mnt/data/ucx-1.20 \
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
/mnt/data/ucx-1.20/bin/ucx_info -d | grep -i cuda

# NIXL (CUDA 13 variant)
cd /mnt/data
rm -rf nixl
git clone https://github.com/ai-dynamo/nixl.git
cd nixl

uv pip uninstall -y nixl nixl-cu12 nixl-cu13 || true
uv pip install -U tomlkit meson ninja pybind11 build setuptools wheel

# select CUDA 13 package name
./contrib/tomlutil.py --wheel-name nixl-cu13 pyproject.toml

# source install flow
uv pip install .
meson setup build \
  --prefix=/mnt/data/envs/sgl-a100 \
  -Ducx_path=/mnt/data/ucx-1.20 \
  -Dinstall_headers=true
ninja -C build
ninja -C build install
uv pip install build/src/bindings/python/nixl-meta/nixl-*-py3-none-any.whl

# verify
python -c "import nixl; a=nixl.nixl_agent('agent1'); print('nixl ok')"
uv pip list | grep -E 'nixl|sglang|torch|torchvision|transformers'
