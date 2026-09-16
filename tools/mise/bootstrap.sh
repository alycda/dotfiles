#!/bin/sh
# Set up the macOS account that has no Nix and no admin rights.
#
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/tools/mise/bootstrap.sh | sh
#
# POSIX sh because it runs before anything from this repo is installed. Safe
# to run again: every step checks before it changes anything.
#
# It does not run the steps that ask questions (SSH key passphrase, gh login).
# Piped from curl, stdin is the script itself, so a prompt would read the rest
# of this file as its answer. For the same reason every command below that
# could read stdin gets </dev/null. Those steps are printed at the end.
#
# Needs git, which on macOS comes from the Command Line Tools. Installing them
# needs an admin, so this checks for them rather than trying.

set -eu

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/alycda/dotfiles.git}"
MISE="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

say() { printf 'bootstrap: %s\n' "$*"; }

# Point $1 at $2. A link that is already right is left alone; anything else
# at $1 is moved aside, never deleted.
link() {
  if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then
    say "$1 already links to $2"
    return
  fi
  if [ -e "$1" ] || [ -L "$1" ]; then
    backup="$1.bak.$(date +%Y%m%d%H%M%S)"
    mv "$1" "$backup"
    say "moved the existing $1 to $backup"
  fi
  mkdir -p "$(dirname "$1")"
  ln -s "$2" "$1"
  say "linked $1 -> $2"
}

# 1. The checkout. https, because the repo is public: no key or login exists
#    yet. `mise run gh-login` switches the remote to SSH afterwards.
if [ -e "$DOTFILES/.git" ]; then
  say "$DOTFILES already exists"
else
  if [ "$(uname -s)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
    say "git needs the Command Line Tools; ask an admin to run: xcode-select --install"
    exit 1
  fi
  git clone "$REPO_URL" "$DOTFILES" </dev/null
fi

# 2. mise, and its activate line in .zshrc. mise.run/zsh does both, but it only
#    recognises the line it wrote itself, so check for any activate line first.
if grep -qs 'mise activate zsh' "$ZSHRC"; then
  say "$ZSHRC already activates mise"
  [ -x "$MISE" ] || curl -fsSL https://mise.run </dev/null | sh
else
  curl -fsSL https://mise.run/zsh </dev/null | sh
fi

# 3. Config shared with the Nix accounts, used in place from the checkout.
link "$HOME/.config/mise" "$DOTFILES/tools/mise"
link "$HOME/.config/helix" "$DOTFILES/tools/helix"

gitconfig="$DOTFILES/tools/git/config"
if git config --global --get-all include.path 2>/dev/null | grep -qxF "$gitconfig"; then
  say "$HOME/.gitconfig already includes $gitconfig"
else
  git config --global --add include.path "$gitconfig"
  say "added an include of $gitconfig to $HOME/.gitconfig"
fi

# 4. The tools listed in tools/mise/config.toml.
"$MISE" install </dev/null

cat <<EOF

bootstrap: done. Open a new shell, then run the steps that ask questions:
  mise run gh-login         # SSH key, gh login, and the checkout's remote to SSH
  mise run macos-defaults
  mise run dock
EOF
