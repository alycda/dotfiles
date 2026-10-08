#!/bin/sh
# Set up felixia, the 2012 x86_64 Mac on macOS 10.15.8: a pinned mise and the
# tools in tools/mise/felixia.toml. install.sh is the one command for every
# other machine; this one exists because felixia can't take mise's `latest`.
#
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/install-felixia.sh | sh
#
# mise.run would install the newest mise, and `mise self-update` would too, so
# this fetches one release from GitHub and checks it against that release's
# SHASUMS256.txt. 2026.9.11 is the mise that installed felixia's pinned tools
# on 2026-09-18. To move the pin, run the new version on felixia first:
# `MISE_VERSION=x sh install-felixia.sh`, then `mise --version` and
# `mise install`.
#
# POSIX sh because it runs before anything from this repo is installed. Piped
# from curl, this script's stdin IS the script, so nothing below may read
# stdin. Safe to run again: every step checks before it changes anything.

set -eu

REPO_URL="${REPO_URL:-https://github.com/alycda/dotfiles.git}"
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
REF="${REF:-}"
MISE_VERSION="${MISE_VERSION:-2026.9.11}"
MISE="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
CONFIG="$DOTFILES/tools/mise/felixia.toml"

say() { printf 'install-felixia: %s\n' "$*"; }
die() { printf 'install-felixia: %s\n' "$*" >&2; exit 1; }

# Anything at $1 is moved aside, never deleted.
move_aside() {
  backup="$1.bak.$(date +%Y%m%d%H%M%S)"
  mv "$1" "$backup"
  say "moved the existing $1 to $backup"
}

[ "$(uname -s)" = Darwin ] || die "this is felixia's installer; elsewhere use install.sh"
[ "$(uname -m)" = x86_64 ] || die "felixia is x86_64; this Mac is $(uname -m). Use install.sh"

# --- The checkout --------------------------------------------------------------

# An existing checkout is used as it is: no pull, since it may be a jj repo
# with work in progress.
if [ -e "$DOTFILES/.git" ]; then
  say "using the existing checkout at $DOTFILES"
else
  xcode-select -p >/dev/null 2>&1 ||
    die "git needs the Command Line Tools; ask an admin to run: xcode-select --install"
  if [ -n "$REF" ]; then
    git clone --branch "$REF" "$REPO_URL" "$DOTFILES" </dev/null
  else
    git clone "$REPO_URL" "$DOTFILES" </dev/null
  fi
fi
[ -f "$CONFIG" ] ||
  die "$DOTFILES has no tools/mise/felixia.toml; update that checkout, or set DOTFILES to a new path"

# --- mise, at the pinned version -------------------------------------------------

have="$("$MISE" --version 2>/dev/null </dev/null | awk '{print $1}' || true)"
if [ "$have" = "$MISE_VERSION" ]; then
  say "$MISE is already mise $MISE_VERSION"
else
  asset="mise-v$MISE_VERSION-macos-x64.tar.gz"
  url="https://github.com/jdx/mise/releases/download/v$MISE_VERSION"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  say "downloading $asset"
  curl -fsSL -o "$tmp/$asset" "$url/$asset" </dev/null
  curl -fsSL -o "$tmp/SHASUMS256.txt" "$url/SHASUMS256.txt" </dev/null
  # The file lists every asset as ./name; check only this one.
  want="$(awk -v a="./$asset" '$2 == a || $2 == substr(a, 3) {print $1}' "$tmp/SHASUMS256.txt")"
  [ -n "$want" ] || die "SHASUMS256.txt for v$MISE_VERSION does not list $asset"
  got="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
  [ "$got" = "$want" ] || die "$asset: sha256 $got, but the release lists $want"
  tar -xzf "$tmp/$asset" -C "$tmp" </dev/null
  mkdir -p "$(dirname "$MISE")"
  if [ -e "$MISE" ] || [ -L "$MISE" ]; then move_aside "$MISE"; fi
  mv "$tmp/mise/bin/mise" "$MISE"
  say "installed $("$MISE" --version </dev/null) at $MISE"
fi

# The activate line in .zshrc. felixia's login shell is zsh.
if grep -qs 'mise activate zsh' "$ZSHRC"; then
  say "$ZSHRC already activates mise"
else
  # shellcheck disable=SC2016 # $(...) is for .zshrc to expand, not this script
  printf '\neval "$(%s activate zsh)"\n' "$MISE" >>"$ZSHRC"
  say "added mise activate to $ZSHRC"
fi

# --- The config ------------------------------------------------------------------

# felixia's earlier setup linked the whole ~/.config/mise to a directory in a
# checkout. A file linked inside that link would land in the checkout, so the
# directory link is moved aside first and ~/.config/mise becomes a plain
# directory again.
dir="$HOME/.config/mise"
if [ -L "$dir" ]; then move_aside "$dir"; fi
mkdir -p "$dir"
if [ -L "$dir/config.toml" ] && [ "$(readlink "$dir/config.toml")" = "$CONFIG" ]; then
  say "$dir/config.toml already links to $CONFIG"
else
  if [ -e "$dir/config.toml" ] || [ -L "$dir/config.toml" ]; then move_aside "$dir/config.toml"; fi
  ln -s "$CONFIG" "$dir/config.toml"
  say "linked $dir/config.toml -> $CONFIG"
fi

# --- The tools -------------------------------------------------------------------

# From $HOME, so a project mise.toml in the working directory can't add to it.
cd "$HOME"
"$MISE" install </dev/null
say "tv: $("$MISE" exec -- tv --version </dev/null 2>&1 || echo 'did not run; see above')"

say "done. Open a new shell. Never run mise self-update here; rerun this instead."
