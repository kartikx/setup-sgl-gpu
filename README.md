# setup-sgl-gpu

Bootstrap a fresh AWS GPU VM for this SGLang + UCX + NIXL workflow.

The main entrypoint is `automated/bootstrap-gpu.sh`. It is intentionally split into two phases so you can do the manual credential setup in between.

## Fresh Instance Flow

### 1. Provision the VM

Bring up a fresh GPU instance with:

- NVIDIA drivers working
- CUDA installed
- `nvidia-smi` available
- `sudo` access
- network egress to GitHub, Hugging Face, and package mirrors

This repo assumes CUDA is at `/usr/local/cuda`. If not, set `CUDA_HOME` when you run the bootstrap script.

### 2. SSH into the VM

Example:

```bash
ssh ubuntu@<instance-ip>
```

### 3. Clone this repo

```bash
git clone https://github.com/kartikx/setup-sgl-gpu.git
cd setup-sgl-gpu
```

### 4. Run part 1

This installs the base packages, shell tools, `uv`, Prometheus, optional Codex CLI, copies the tracked dotfiles into `$HOME`, switches the default shell to `zsh`, and generates a GitHub SSH key.

```bash
./automated/bootstrap-gpu.sh part1
```

The default `part1` behavior also:

- generates a GitHub SSH key by running `generate-keys.sh`
- switches your default shell to `zsh`

If you want to disable either one:

```bash
GENERATE_GITHUB_KEY=0 SET_DEFAULT_SHELL=0 ./automated/bootstrap-gpu.sh part1
```

### 5. Manual steps between part 1 and part 2

Do these before continuing:

1. Verify the GPU stack is usable:

```bash
nvidia-smi
ls /usr/local/cuda
```

If CUDA is not at `/usr/local/cuda`, note the actual path and pass `CUDA_HOME=/path/to/cuda` to `part2`.

2. Verify Prometheus is installed:

```bash
prometheus --version
```

3. Configure GitHub access on the VM.

If you used `GENERATE_GITHUB_KEY=1`, the script already printed the public key. Add that key to GitHub.

If you did not, run:

```bash
./generate-keys.sh
```

Then add the printed public key to GitHub and verify:

```bash
ssh -T git@github.com
```

4. Optional: set your Hugging Face token in `~/.zshrc`:

```bash
./automated/set-hf-token.sh <your-hf-token>
source ~/.zshrc
```

### 6. Run part 2

This clones the dependent repos, creates the SGLang venv, records `SGLANG_VENV_PATH` in `~/.zshrc`, installs UCX, installs NIXL, and runs smoke checks.

For the common case where everything should live under your home directory:

```bash
BASE_DIR="$HOME" ./automated/bootstrap-gpu.sh part2
```

If CUDA lives elsewhere:

```bash
BASE_DIR="$HOME" CUDA_HOME=/path/to/cuda ./automated/bootstrap-gpu.sh part2
```

### 7. Reload shell config

After `part2`, reload your shell config so the new exports are available in the current shell:

```bash
source ~/.zshrc
```

At this point, `SGLANG_VENV_PATH` should be set to the created venv path.

## One-shot Run

Once GitHub access is already configured on the VM, you can run both phases in one go:

```bash
BASE_DIR="$HOME" ./automated/bootstrap-gpu.sh all
```

Or with key generation during `part1`:

```bash
BASE_DIR="$HOME" GENERATE_GITHUB_KEY=1 ./automated/bootstrap-gpu.sh all
```

In practice, `all` is most useful only after the VM already has working GitHub access.

## Default Layout

With `BASE_DIR="$HOME"`, the script uses:

- venv: `$HOME/envs/sgl-a100`
- sglang repo: `$HOME/sglang`
- benchmarking repo: `$HOME/sglang-nixl-benchmarking`
- nixl repo: `$HOME/nixl`
- UCX install: `$HOME/ucx-1.19.0`

## Useful Options

```bash
BASE_DIR="$HOME"
CUDA_HOME=/usr/local/cuda
INSTALL_CODEX=0
INSTALL_DOTFILES=0
SET_DEFAULT_SHELL=1
GENERATE_GITHUB_KEY=1
SKIP_GITHUB_CHECK=1
```

## Troubleshooting

If `import nixl` fails with `libnixl.so: cannot open shared object file`, make sure the venv library path is in `LD_LIBRARY_PATH` for the current shell:

```bash
source "$HOME/envs/sgl-a100/bin/activate"
export LD_LIBRARY_PATH="$HOME/envs/sgl-a100/lib:$HOME/envs/sgl-a100/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
python -c "import nixl; print('nixl ok')"
```
