#!/bin/sh
# One command to set up any of my machines or accounts (issue #29).
#
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/install.sh | sh -s -- --mise
#
# With no mode it only reports what this machine and account can do and which
# mode fits; it changes nothing. A mode has to be chosen explicitly, because
# detection can't know what you want: an account with working Nix might still
# prefer mise. See README "Fastest path to a working environment" for the tree
# this follows.
#
# POSIX sh because it runs before anything from this repo is installed. Piped
# from curl, this script's stdin IS the script, so nothing below may read stdin:
# commands that could get </dev/null, and prompts only come from sudo, which
# reads the terminal directly. See
# docs/solutions/runtime-errors/curl-piped-dev-sh-cannot-attach-stdin-to-tty.md

set -eu

REPO_URL="${REPO_URL:-https://github.com/alycda/dotfiles.git}"
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
REF="${REF:-}"
PROFILE="${PROFILE:-}"
MODE=""

usage() {
  cat <<'USAGE'
usage: install.sh [--nix | --mise] [--profile NAME] [--ref BRANCH]

  (no mode)       report what this account can do and recommend a mode
  --mise          no Nix, no admin: clone, then tools/mise/bootstrap.sh
  --nix           macOS admin: install Nix if missing, then darwin-rebuild
                  anyone else with working Nix: home-manager (needs --profile)
  --profile NAME  flake configuration (default on macOS: this Mac's hostname)
  --ref BRANCH    clone this branch instead of the default one

env: DOTFILES (default ~/dotfiles), REPO_URL, REF, PROFILE
USAGE
}

say() { printf 'install: %s\n' "$*"; }
die() { printf 'install: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --nix | --mise) MODE="${1#--}" ;;
    --profile) [ $# -gt 1 ] || die "--profile needs a name"; PROFILE="$2"; shift ;;
    --ref) [ $# -gt 1 ] || die "--ref needs a branch"; REF="$2"; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

OS="$(uname -s)"
case "$OS" in
  Darwin | Linux) ;;
  *) die "unsupported OS: $OS" ;;
esac

# --- What this account can do ------------------------------------------------

is_admin() {
  [ "$(id -u)" = 0 ] && return 0
  case "$OS" in
    Darwin) id -Gn | tr ' ' '\n' | grep -qx admin ;;
    Linux) id -Gn | tr ' ' '\n' | grep -qxE 'sudo|wheel' ;;
  esac
}

# Flakes without editing /etc/nix/nix.conf: nix-darwin takes that file over on
# its first switch anyway.
NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}experimental-features = nix-command flakes"
export NIX_CONFIG

load_nix() {
  command -v nix >/dev/null 2>&1 && return 0
  for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    # shellcheck disable=SC1090
    if [ -f "$f" ]; then . "$f"; return 0; fi
  done
  return 1
}

# absent: no Nix on this machine. denied: Nix is installed, but this account
# can't reach the daemon (not in nix-users). usable: nix commands work.
# `command -v nix` alone is not enough: a non-admin account on a nix-darwin Mac
# has nix on PATH and still gets "daemon-socket/socket: Permission denied".
nix_state() {
  if ! load_nix; then
    if [ -e /nix/var/nix ]; then echo denied; else echo absent; fi
    return
  fi
  if nix store info </dev/null >/dev/null 2>&1 || nix store ping </dev/null >/dev/null 2>&1; then
    echo usable
  else
    echo denied
  fi
}

nix_access_fix() {
  case "$OS" in
    Darwin) echo "ask an admin to run: sudo dseditgroup -o edit -a $(id -un) -t user nix-users" ;;
    Linux) echo "ask an admin to allow $(id -un) in /etc/nix/nix.conf (allowed-users) or the nix-users group" ;;
  esac
}

NIX_STATE="$(nix_state)"
if is_admin; then ADMIN=yes; else ADMIN=no; fi

if [ -z "$MODE" ]; then
  say "$OS, account $(id -un), admin: $ADMIN, Nix: $NIX_STATE"
  case "$NIX_STATE:$ADMIN" in
    usable:yes | absent:yes)
      if [ "$OS" = Darwin ]; then
        say "recommended: --nix (installs Nix if missing, then darwin-rebuild switch)"
      else
        say "recommended: --nix --profile <name> (home-manager switch)"
      fi ;;
    usable:no)
      say "recommended: --nix --profile <name> (home-manager switch), or --mise"
      say "note: home-manager profiles hardcode their user; see issue #29" ;;
    denied:*)
      say "recommended: --mise; for Nix instead, $(nix_access_fix)" ;;
    absent:no)
      say "recommended: --mise (installing Nix needs an admin)" ;;
  esac
  say "nothing changed. Rerun with a mode, e.g.: curl -fsSL <url> | sh -s -- --mise"
  exit 0
fi

# --- The checkout --------------------------------------------------------------

# An existing checkout is used as it is: no pull, since it may be a jj repo
# with work in progress.
clone() {
  if [ -e "$DOTFILES/.git" ]; then
    say "using the existing checkout at $DOTFILES"
    return
  fi
  if [ "$OS" = Darwin ] && xcode-select -p >/dev/null 2>&1; then
    set -- git
  elif [ "$OS" = Linux ] && command -v git >/dev/null 2>&1; then
    set -- git
  elif [ "$NIX_STATE" = usable ]; then
    # Avoids needing the Command Line Tools (macOS) or a system git (Linux).
    set -- nix shell nixpkgs#git -c git
  elif [ "$OS" = Darwin ]; then
    die "git needs the Command Line Tools; ask an admin to run: xcode-select --install"
  else
    die "git is not installed"
  fi
  if [ -n "$REF" ]; then
    "$@" clone --branch "$REF" "$REPO_URL" "$DOTFILES" </dev/null
  else
    "$@" clone "$REPO_URL" "$DOTFILES" </dev/null
  fi
}

# --- --mise ------------------------------------------------------------------------

if [ "$MODE" = mise ]; then
  clone
  [ -f "$DOTFILES/tools/mise/bootstrap.sh" ] ||
    die "$DOTFILES has no tools/mise/bootstrap.sh; update that checkout, or set DOTFILES to a new path"
  export DOTFILES REPO_URL
  sh "$DOTFILES/tools/mise/bootstrap.sh" </dev/null
  exit 0
fi

# --- --nix ---------------------------------------------------------------------

# Every Nix path ends at ragenix decrypting secrets with this key. Activation
# carries on without it, so warn rather than stop.
if [ ! -f "$HOME/.age/personal-key.txt" ]; then
  say "warning: no ~/.age/personal-key.txt; activation continues without decrypted secrets (no git identity). Copy it from another machine first if you can."
fi

case "$NIX_STATE" in
  denied) die "Nix is installed but this account can't use it; $(nix_access_fix). Or use --mise." ;;
  absent)
    [ "$ADMIN" = yes ] || die "installing Nix needs an admin account. Use --mise instead."
    say "installing Nix (multi-user); sudo will ask for your password"
    curl -fsSL https://nixos.org/nix/install </dev/null | sh -s -- --daemon --yes
    load_nix || die "Nix installed, but not on PATH in this shell. Open a new terminal and rerun."
    ;;
esac

clone
flake="$DOTFILES"

names() { nix eval --raw "$flake#$1" --apply 'c: builtins.concatStringsSep " " (builtins.attrNames c)' </dev/null; }
eval_raw() { nix eval --raw "$flake#$1" </dev/null; }

if [ "$OS" = Darwin ] && [ "$ADMIN" = yes ]; then
  available="$(names darwinConfigurations)"
  if [ -z "$PROFILE" ]; then
    PROFILE="$(scutil --get LocalHostName | tr '[:upper:]' '[:lower:]')"
  fi
  case " $available " in
    *" $PROFILE "*) ;;
    *) die "no darwinConfiguration named '$PROFILE' (available: $available). Pass --profile." ;;
  esac

  primary="$(eval_raw "darwinConfigurations.$PROFILE.config.system.primaryUser")"
  [ "$primary" = "$(id -un)" ] ||
    die "darwinConfigurations.$PROFILE is for user '$primary', not '$(id -un)'. Run this as $primary."

  # nix-darwin's homebrew module drives brew; it doesn't install it.
  [ -x /opt/homebrew/bin/brew ] ||
    die "Homebrew is missing. Install it first: https://brew.sh"
  owner="$(stat -f %Su /opt/homebrew)"
  [ "$owner" = "$primary" ] ||
    die "/opt/homebrew is owned by $owner; nix-darwin runs brew as $primary. Fix with: sudo chown -R $primary /opt/homebrew"

  remote_taps="$(nix eval --raw "$flake#darwinConfigurations.$PROFILE.config.homebrew.taps" \
    --apply 'ts: builtins.concatStringsSep " " (map (t: t.name) (builtins.filter (t: (t.clone_target or null) != null) ts))' \
    </dev/null 2>/dev/null || true)"
  if [ -n "$remote_taps" ]; then
    say "warning: Homebrew taps with their own clone URL ($remote_taps) need GitHub access (SSH key or gh login) during the switch"
  fi

  say "building darwinConfigurations.$PROFILE"
  system="$(nix build --no-link --print-out-paths "$flake#darwinConfigurations.$PROFILE.system" </dev/null)"

  # First switch only: nix-darwin refuses to overwrite these unmanaged files.
  if [ ! -e /run/current-system ]; then
    for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
      if [ -e "$f" ] && [ ! -L "$f" ]; then
        sudo mv "$f" "$f.before-nix-darwin"
        say "moved $f to $f.before-nix-darwin"
      fi
    done
  fi

  say "switching; sudo will ask for your password"
  # sudo drops the environment, so hand NIX_CONFIG (flakes) through env.
  sudo env "NIX_CONFIG=$NIX_CONFIG" "$system/sw/bin/darwin-rebuild" switch --flake "$flake#$PROFILE" </dev/null
else
  available="$(names homeConfigurations)"
  [ -n "$PROFILE" ] || die "home-manager needs --profile (available: $available)"
  case " $available " in
    *" $PROFILE "*) ;;
    *) die "no homeConfiguration named '$PROFILE' (available: $available)" ;;
  esac

  # The profiles hardcode their user (issue #29), and activating one as the
  # wrong user writes into someone else's home directory paths.
  user="$(eval_raw "homeConfigurations.\"$PROFILE\".config.home.username")"
  home="$(eval_raw "homeConfigurations.\"$PROFILE\".config.home.homeDirectory")"
  if [ "$user" != "$(id -un)" ] || [ "$home" != "$HOME" ]; then
    die "homeConfigurations.$PROFILE is for $user ($home), not $(id -un) ($HOME). See issue #29, or use --mise."
  fi

  say "building homeConfigurations.$PROFILE"
  activation="$(nix build --no-link --print-out-paths "$flake#homeConfigurations.\"$PROFILE\".activationPackage" </dev/null)"
  say "activating"
  HOME_MANAGER_BACKUP_EXT=hm-backup "$activation/activate" </dev/null
fi

say "done. Open a new shell, then log in once on this machine: just _login"
