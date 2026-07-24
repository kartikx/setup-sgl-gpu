# setup-sgl-gpu

Bootstrap a fresh AWS GPU VM for the SGLang + UCX + NIXL workflow.

The main GPU entrypoint is `automated/bootstrap-gpu.sh`. Run `part1`, add credentials, then run `part2`.

For a CPU-only VM, use `setup-cpu.sh` after creating the GitHub SSH key.

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

After `part2`, `SGLANG_VENV_PATH`, `SGLANG_UPSTREAM_VENV_PATH`, and `VLLM_VENV_PATH` point at the created venvs.

## CPU VM Flow

Use this for a non-GPU VM that only needs the shared developer tooling and shell setup.

```bash
ssh ubuntu@<instance-ip>

git clone https://github.com/kartikx/setup-sgl-gpu.git
cd setup-sgl-gpu

./generate-keys.sh
# Add the printed public key to GitHub.

ssh -T git@github.com
./setup-cpu.sh
source ~/.zshrc
```

`setup-cpu.sh` installs the common base packages, `uv`, Codex CLI, `fzf`, `zoxide`, `nvim`, tracked dotfiles, sets the p10k prompt label to `aws-cpu`, and sets zsh as the default shell. Codex installation, dotfile installation, and the default-shell change are enabled by default. It does not install CUDA, UCX, NIXL, SGLang, or create venvs.

## One-Shot Run

Use this only after the default GitHub key exists and GitHub access already works:

```bash
BASE_DIR="$HOME" ./automated/bootstrap-gpu.sh all
source ~/.zshrc
```

## Defaults

With `BASE_DIR="$HOME"`:

- venv: `$HOME/envs/sgl-a100`
- upstream venv: `$HOME/envs/sgl-upstream`
- vLLM venv: `$HOME/envs/vllm`
- sglang repo: `$HOME/sglang`
- benchmarking repo: `$HOME/sglang-nixl-benchmarking`
- nixl repo: `$HOME/nixl`
- UCX install: `$HOME/ucx-1.19.0`
- GitHub SSH key: `$HOME/.ssh/id_ed25519_github`

`part2` now provisions the upstream comparison environment after the primary `sgl-a100` flow succeeds:

1. Install UCX once.
2. Install NIXL into `$HOME/envs/sgl-a100`.
3. Install the forked SGLang checkout into `$HOME/envs/sgl-a100`.
4. Smoke test the primary env.
5. Create `$HOME/envs/sgl-upstream`.
6. Install NIXL into `$HOME/envs/sgl-upstream`.
7. Install `sglang==0.5.4.post1` from PyPI into `$HOME/envs/sgl-upstream`.
8. Install `sglang-router` into `$HOME/envs/sgl-upstream`.
9. Smoke test the upstream env.
10. Create `$HOME/envs/vllm`.
11. Install `vllm` and `vllm-router` into `$HOME/envs/vllm`.
12. Install NIXL into `$HOME/envs/vllm`.
13. Re-check `torchvision` compatibility and smoke test the vLLM env.

Common overrides:

```bash
BASE_DIR="$HOME"
CUDA_HOME=/usr/local/cuda
INSTALL_CODEX=1
INSTALL_DOTFILES=1
SET_DEFAULT_SHELL=1
CPU_REMOTE_NAME=aws-cpu
SKIP_GITHUB_CHECK=1
VLLM_PACKAGE_SPEC=vllm
VLLM_ROUTER_PACKAGE_SPEC=vllm-router
FIX_TORCHVISION=1
UNINSTALL_BROKEN_TORCHVISION=1
```

Set `INSTALL_CODEX=0`, `INSTALL_DOTFILES=0`, or `SET_DEFAULT_SHELL=0` only when you want to skip those default actions.

## Troubleshooting

If CUDA is not under `/usr/local/cuda`, pass the correct path to `part2`:

```bash
BASE_DIR="$HOME" CUDA_HOME=/path/to/cuda ./automated/bootstrap-gpu.sh part2
```

If the vLLM smoke check fails with `RuntimeError: operator torchvision::nms does not exist`,
the vLLM venv has a `torch` / `torchvision` wheel mismatch. Re-run the vLLM installer,
which repairs `torchvision` by default and uninstalls it if the matching wheel still fails:

```bash
BASE_DIR="$HOME" UV_VENV_DIR="$HOME/envs/vllm" INSTALL_VLLM_PACKAGES=0 ./install-vllm.sh
```

To keep a broken `torchvision` install instead of removing it:

```bash
UNINSTALL_BROKEN_TORCHVISION=0 BASE_DIR="$HOME" UV_VENV_DIR="$HOME/envs/vllm" INSTALL_VLLM_PACKAGES=0 ./install-vllm.sh
```

If `import nixl` fails with `libnixl.so: cannot open shared object file`:

```bash
source "$HOME/envs/sgl-a100/bin/activate"
export LD_LIBRARY_PATH="$HOME/envs/sgl-a100/lib:$HOME/envs/sgl-a100/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
python -c "import nixl; print('nixl ok')"
```
