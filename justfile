# This repo's recipes. The HUID task recipes are global (tools/just, linked to
# ~/.config/just by mise), imported here so `just task` works without -g.
# Import this checkout's copy only: ~/.config/just is the same directory once
# linked, and importing both defines every recipe twice, which just rejects.
import './tools/just/justfile'

[private]
_default:
    @just --list

[group('nix')]
dev:
    nix --extra-experimental-features 'nix-command flakes' develop

# MACRO.MESO.MICRO
bump effort:
    tools/effver/bump-effver {{ effort }}

# Check VERSION and CHANGELOG.md in every commit of REVSET (default: the stack not on trunk yet)
check-effver revset='':
    tools/effver/check-effver --jj {{ quote(revset) }}

# Setup recipes are one-time steps you run by hand, written so that running
# one again does nothing. Never make them run automatically, e.g. from a hook:
# a login prompt with no terminal attached just hangs. On a new machine, mise
# is not active in the shell yet: run the first one as `mise exec -- just
# identity`, which also runs the two it depends on.

# Create an SSH key for GitHub, unless one exists
[group('setup')]
ssh-key:
    @tools/setup/ssh-key

# Log gh in over SSH, unless it already is
[group('setup')]
gh-login: ssh-key
    @tools/setup/gh-login

# Set git and jj identity from the logged-in GitHub account
[group('setup')]
identity: gh-login
    @tools/setup/identity

# Without a daemon, docker's own error names a socket path, not the fix.
[private]
docker-daemon:
    @docker info >/dev/null 2>&1 || { echo "No Docker daemon is running: start OrbStack or Docker Desktop (README.md, Docker)." >&2; exit 1; }

# Build the image with this checkout's home-manager generation (see Dockerfile)
[group('docker')]
docker-build: docker-daemon
    docker build -t dotfiles .

# Run that image, with the current directory at /work
[group('docker')]
docker-run: docker-daemon
    docker run -it --rm -e TERM="$TERM" -v {{ quote(invocation_directory()) }}:/work dotfiles

# Create or edit an agenix secret, secrets/NAME.age (needs the dev shell)
[group('secrets')]
edit-secret name:
    tools/secrets/edit-secret {{ quote(name) }}
