# This repo's recipes. The HUID task recipes are global (tools/just, linked to
# ~/.config/just by mise), imported here so `just task` works without -g.
# Import this checkout's copy only: ~/.config/just is the same directory once
# linked, and importing both defines every recipe twice, which just rejects.
import './tools/just/justfile'

[private]
_default:
    @just --list

# Flakes are still experimental, and a fresh Nix install has them off.
nix := "nix --extra-experimental-features 'nix-command flakes'"

# This machine's configuration. On a Mac, an admin's is named after its
# host, as darwin-rebuild picks it, but lowercased: macOS capitalizes the
# name (Shesfast) and the flake's are lowercase. An account without admin
# can't run darwin-rebuild, so its is a home of its own, named after its
# user and architecture as on Linux (the devcontainer, the Docker image):
# code@aarch64-darwin, vscode@aarch64-linux.
machine := if os() == "macos" { if shell('id -Gn') =~ '(^| )admin( |$)' { shell('scutil --get LocalHostName | tr "[:upper:]" "[:lower:]"') } else { shell('whoami') + '@' + arch() + '-darwin' } } else { shell('whoami') + '@' + arch() + '-linux' }

# A name with an @ is a home-manager configuration, run without root and
# moving a file it takes over to <file>.backup, as the devcontainer's first
# switch does. One without is a Mac's nix-darwin configuration, as root.
darwin := if machine =~ '@' { "" } else { "darwin" }

[group('nix')]
dev:
    {{ nix }} develop

# Check the flake for every system, failing rather than updating flake.lock
[group('nix')]
check:
    {{ nix }} flake check --all-systems --no-update-lock-file

# Update flake.lock: every input, or only the ones named
[group('nix')]
update *inputs:
    {{ nix }} flake update {{ inputs }}

# Build and switch run from the flake: the versions flake.lock pins, and
# the first switch works before either CLI is installed.

# Build this machine's configuration, or NAME's, into ./result
[group('nix')]
build name=machine:
    {{ nix }} run .#{{ if name =~ '@' { "home-manager" } else { "darwin-rebuild" } }} -- build --flake .#{{ quote(name) }}

# Build this machine's configuration, or NAME's, and switch to it
[group('nix')]
switch name=machine:
    {{ if name =~ '@' { nix + " run .#home-manager -- switch -b backup" } else { "sudo " + nix + " run .#darwin-rebuild -- switch" } }} --flake .#{{ quote(name) }}

# Generations and rollback use the CLI the last switch installed, not the
# flake's: they are for when the checkout is what's broken.

# List the generations switched to
[group('nix')]
generations:
    {{ if darwin == "darwin" { "darwin-rebuild --list-generations" } else { "home-manager generations" } }}

# Switch back to the generation before the current one
[group('nix')]
rollback:
    {{ if darwin == "darwin" { "sudo darwin-rebuild --rollback" } else { "home-manager switch --rollback" } }}

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

# Run that image, with the current directory at /work and ~/.age read-only
# (if the host has it), so the entrypoint installs the agenix secrets
[group('docker')]
docker-run: docker-daemon
    docker run -it --rm -e TERM="$TERM" {{ if path_exists(home_directory() / ".age") == "true" { "-v " + quote(home_directory() / ".age") + ":/root/.age:ro" } else { "" } }} -v {{ quote(invocation_directory()) }}:/work dotfiles

# Create or edit an agenix secret, secrets/NAME.age (needs the dev shell)
[group('secrets')]
edit-secret name:
    tools/secrets/edit-secret {{ quote(name) }}
