ssh-keygen -t ed25519 -C "aws-$(hostname)-github" -f ~/.ssh/id_ed25519_github

chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519_github
chmod 644 ~/.ssh/id_ed25519_github.pub

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github

cat >> ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config

cat ~/.ssh/id_ed25519_github.pub

# Preload GitHub host key so first SSH connect is non-interactive.
touch ~/.ssh/known_hosts
if ! ssh-keygen -F github.com >/dev/null; then
  ssh-keyscan -H github.com >> ~/.ssh/known_hosts
fi
chmod 644 ~/.ssh/known_hosts

# Test SSH to GitHub without prompting for host authenticity.
ssh -o StrictHostKeyChecking=yes -T git@github.com || true
