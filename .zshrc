#-------
# enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# zet the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# download zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# history
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# aliases
alias ls='ls --color'
alias vim='nvim'
alias c='clear'
alias e="exit"
alias c="clear"
alias py="python3"
alias python="python3"
alias pip="pip3"
alias venva="source .venv/bin/activate"

# global alias
alias -g v="nvim"
alias -g cfv="~/.config/nvim/init.vim"
alias -g cfz="~/.zshrc"
alias -g cfa="~/.aerospace.toml"
alias -g cft="~/.config/ghostty/config"
alias -g xc="xclip -selection clipboard"

## make a directory and cd into it
mkcd() {
    mkdir $1 && cd $1
}

## copy contents of a file into the system clipboard
fcp() {
   cat $1 | pbcopy
}

## vim + fzf - opens selected file in vim
vzf() {
  local file
  file=$(fzf)
  [ -n "$file" ] && vim "$file"
}

mkghrepo() { 
    reponame=${PWD##*/} && git init && gh repo create "$reponame" --public --source=. --remote=origin;
}



# vim mode in shell
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# UV configuration
export BASE_DIR="${BASE_DIR:-/mnt/data}"
export UCX_VERSION="${UCX_VERSION:-1.19.0}"
export UV_CACHE_DIR="$HOME/.cache/uv"
# export UV_LINK_MODE=copy
# export UV_PYTHON_INSTALL_DIR="$BASE_DIR/uv/python"
# export UV_TOOLCHAIN_DIR="$BASE_DIR/uv/toolchains"
# export UV_VENV_BASE_DIR="$BASE_DIR/envs"
export PATH="$HOME/.local/bin:$PATH"

# UCX
export UCX_HOME="${UCX_HOME:-$BASE_DIR/ucx-${UCX_VERSION}}"
export PATH=$UCX_HOME/bin:$PATH
export LD_LIBRARY_PATH="$UCX_HOME/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$UCX_HOME/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# HF
export HF_HOME=/opt/dlami/nvme/hf_cache
export HF_HUB_CACHE=/opt/dlami/nvme/hf_cache
# export HF_HOME=/mnt/data/hf_cache
# export HF_HUB_CACHE=/mnt/data/hf_cache
# Keep HF_TOKEN out of git-tracked files; set it in your shell/session manager.

export CUDA_HOME=/usr/local/cuda
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

# NIXL runtime libs: hardcode default SGLang venv even when no venv is active.
export SGLANG_VENV_PATH="${SGLANG_VENV_PATH:-/home/ubuntu/envs/sgl-a100}"
if [[ -d "${SGLANG_VENV_PATH}" ]]; then
  export LD_LIBRARY_PATH="${SGLANG_VENV_PATH}/lib:${SGLANG_VENV_PATH}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
fi

# NIXL meson-python runtime libs/plugins (needed for UCX plugin loading)
NIXL_MESONPY_LIBS="${SGLANG_VENV_PATH}/lib/python3.12/site-packages/.nixl.mesonpy.libs"
if [[ -d "${NIXL_MESONPY_LIBS}" ]]; then
  export LD_LIBRARY_PATH="${NIXL_MESONPY_LIBS}/plugins:${NIXL_MESONPY_LIBS}:${LD_LIBRARY_PATH:-}"
fi
unset NIXL_MESONPY_LIBS
#
# shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Ensure git aliases exist (idempotent)
ensure_git_alias() {
  local name="$1"
  local value="$2"

  if ! git config --global --get "alias.$name" >/dev/null; then
    git config --global "alias.$name" "$value"
  fi
}

ensure_git_alias st "status"
ensure_git_alias ci "commit"
ensure_git_alias co "checkout"
ensure_git_alias br "branch"
ensure_git_alias lg "log --oneline --graph --decorate --all"
