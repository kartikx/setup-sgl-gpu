# setup-sgl-gpu

Bootstrap a fresh AWS GPU VM for the SGLang + UCX + NIXL workflow.

The main entrypoint is `automated/bootstrap-gpu.sh`. Run `part1`, add credentials, then run `part2`.

## Prerequisites

Provision a GPU VM with:

- NVIDIA drivers and `nvidia-smi`
- CUDA at `/usr/local/cuda`, or pass `CUDA_HOME=/path/to/cuda`
- `sudo` access
- network egress to GitHub, Hugging Face, and package mirrors

## Fresh VM Flow

```bash
ssh ubuntu@<instance-ip>

git clone https://github.com/kartikx/setup-sgl-gpu.git
cd setup-sgl-gpu

./generate-keys.sh
# Add the printed public key to GitHub.

./automated/bootstrap-gpu.sh part1

ssh -T git@github.com
./automated/set-hf-token.sh <your-hf-token>  # optional
source ~/.zshrc

BASE_DIR="$HOME" ./automated/bootstrap-gpu.sh part2
source ~/.zshrc
```

After `part2`, `SGLANG_VENV_PATH` points at the created venv.

## One-Shot Run

Use this only after the default GitHub key exists and GitHub access already works:

```bash
BASE_DIR="$HOME" ./automated/bootstrap-gpu.sh all
source ~/.zshrc
```

## Defaults

With `BASE_DIR="$HOME"`:

- venv: `$HOME/envs/sgl-a100`
- sglang repo: `$HOME/sglang`
- benchmarking repo: `$HOME/sglang-nixl-benchmarking`
- nixl repo: `$HOME/nixl`
- UCX install: `$HOME/ucx-1.19.0`
- GitHub SSH key: `$HOME/.ssh/id_ed25519_github`

Common overrides:

```bash
BASE_DIR="$HOME"
CUDA_HOME=/usr/local/cuda
INSTALL_CODEX=0
INSTALL_DOTFILES=0
SET_DEFAULT_SHELL=0
SKIP_GITHUB_CHECK=1
```

## Troubleshooting

If CUDA is not under `/usr/local/cuda`, pass the correct path to `part2`:

```bash
BASE_DIR="$HOME" CUDA_HOME=/path/to/cuda ./automated/bootstrap-gpu.sh part2
```

If `import nixl` fails with `libnixl.so: cannot open shared object file`:

```bash
source "$HOME/envs/sgl-a100/bin/activate"
export LD_LIBRARY_PATH="$HOME/envs/sgl-a100/lib:$HOME/envs/sgl-a100/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
python -c "import nixl; print('nixl ok')"
```
