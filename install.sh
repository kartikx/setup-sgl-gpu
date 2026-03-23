sudo apt update
sudo apt install zsh

wget https://github.com/junegunn/fzf/releases/download/v0.67.0/fzf-0.67.0-linux_amd64.tar.gz
tar -xzf fzf-0.67.0-linux_amd64.tar.gz
sudo mv fzf /usr/bin/
fzf --version

curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

sudo chsh -s $(which zsh) $USER

# install nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> .zshrc

sudo timedatectl set-timezone America/Chicago

# install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc