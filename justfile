_default:
    @just --list

# Composes `task` rather than repeating its HUID and collision logic - it reads
# the path that recipe prints on stdout.
#
# Create a task and open it in $EDITOR (helix by default)
[group('huid')]
task-edit title:
    #!/usr/bin/env bash
    set -euo pipefail
    file="$(just task {{ quote(title) }})"
    exec "${EDITOR:-hx}" "$file"

# Create a task directory named with a UTC HUID and seed its TASK.md.
[group('huid')]
[working-directory: "tasks"]
task title:
    #!/usr/bin/env bash
    set -euo pipefail
    id="$(date -u +%Y%m%d-%H%M%S)"
    if [ -e "${id}" ]; then
        # HUIDs are only unique at human speed. The documented remedy for a
        # collision is to wait one second and generate a new one.
        sleep 1
        id="$(date -u +%Y%m%d-%H%M%S)"
    fi
    if [ -e "${id}" ]; then
        echo "HUID still colliding on ${id}; use an explicit suffix" >&2
        exit 1
    fi
    mkdir -p "${id}"
    printf '# %s\n\n- STATUS: OPEN\n- TAGS:\n\n## Description\n\n' {{ quote(title) }} > "${id}/TASK.md"
    # Relative to the justfile, where recipes run by default (task-edit does),
    # not to tasks/, where this one runs.
    printf 'tasks/%s\n' "${id}/TASK.md"

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

# gh-login uses SSH, so this runs first. The key gets the default name
# (id_ed25519). The Host block below makes ssh store the passphrase in the
# macOS keychain on first use and reload the key after a reboot. Without it,
# GitHub only works while some other key (e.g. tangled.org's) is in the agent.
# UseKeychain is macOS-only; IgnoreUnknown keeps the block valid for Linux ssh,
# which otherwise rejects the whole config file.
#
# Create an SSH key for GitHub, unless one exists
[group('setup')]
ssh-key:
    #!/usr/bin/env sh
    set -eu
    if [ -f ~/.ssh/id_ed25519 ]; then
      echo "ssh: ~/.ssh/id_ed25519 already exists"
    else
      mkdir -p ~/.ssh && chmod 700 ~/.ssh
      ssh-keygen -t ed25519 -C "$(whoami)@$(hostname -s)" -f ~/.ssh/id_ed25519
    fi
    if ! grep -qx 'Host github.com' ~/.ssh/config 2>/dev/null; then
      printf '\nHost github.com\n    AddKeysToAgent yes\n    IgnoreUnknown UseKeychain\n    UseKeychain yes\n    IdentityFile ~/.ssh/id_ed25519\n' >> ~/.ssh/config
      echo "ssh: added a github.com block to ~/.ssh/config"
    fi

# Logging in with --git-protocol ssh offers to upload ~/.ssh/id_ed25519.pub.
# If gh was already logged in, upload the key directly unless GitHub has it.
# Last, a checkout cloned over https can't push: this account has no git
# credential helper. Switch origin to SSH once GitHub accepts the key (ssh -T
# exits 1 even on success, hence the grep). Recipes run from the justfile's
# directory, so the remote is this checkout's; in a jj repo jj sets it.
#
# Log gh in over SSH, unless it already is
[group('setup')]
gh-login: ssh-key
    #!/usr/bin/env sh
    set -eu
    if ! gh auth status >/dev/null 2>&1; then
      gh auth login --git-protocol ssh
    elif gh ssh-key list 2>/dev/null | grep -qF "$(cut -d' ' -f2 ~/.ssh/id_ed25519.pub)"; then
      echo "gh: logged in, and GitHub has ~/.ssh/id_ed25519.pub"
    else
      gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(whoami)@$(hostname -s)"
    fi
    remote=$(git remote get-url origin 2>/dev/null || true)
    case "$remote" in
      https://github.com/*)
        if ssh -T -o StrictHostKeyChecking=accept-new git@github.com 2>&1 | grep -q "successfully authenticated"; then
          url="git@github.com:${remote#https://github.com/}"
          if jj root >/dev/null 2>&1; then
            jj git remote set-url origin "$url"
          else
            git remote set-url origin "$url"
          fi
          echo "gh: origin now pushes over SSH ($url)"
        else
          echo "gh: GitHub doesn't accept the SSH key yet; origin stays on $remote"
        fi
        ;;
    esac

# gh is authenticated by the time this runs, and it knows who you are.
# tools/git/config carries no [user] block, so reading identity back out of
# git (`git config --get user.name`) would give an empty string.
#
# .email is not guaranteed. It is only populated when the profile email is
# public or the token carries the user:email scope, and `gh auth login`
# grants neither by default - so fall back to the GitHub noreply address,
# which GitHub still attributes to the account.
#
# git identity goes to ~/.gitconfig (global), never to tools/git/config,
# which is tracked and must stay identity-free.
#
# jj note: `jj config set --user` writes ~/.config/jj/config.toml, and jj
# merges ~/.config/jj/conf.d/*.toml OVER that file. Nothing here puts a
# [user] block in conf.d for exactly that reason - it would silently win
# over every later `jj config set`. Verified on jj 0.45.1.
#
# Set git and jj identity from the logged-in GitHub account
[group('setup')]
identity: gh-login
    #!/usr/bin/env sh
    set -eu
    if ! gh auth status >/dev/null 2>&1; then
      echo "identity: gh is not logged in; run 'just gh-login' first" >&2
      exit 1
    fi

    name=$(gh api user --jq '.name // .login')
    email=$(gh api user --jq '.email // empty')
    if [ -z "$email" ]; then
      email=$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')
      echo "identity: profile email not visible to this token, using $email"
    fi

    if git config --global --get user.name >/dev/null 2>&1; then
      echo "git:  user.name already set to $(git config --global --get user.name)"
    else
      git config --global user.name "$name"
      echo "git:  set user.name to $name"
    fi
    if git config --global --get user.email >/dev/null 2>&1; then
      echo "git:  user.email already set to $(git config --global --get user.email)"
    else
      git config --global user.email "$email"
      echo "git:  set user.email to $email"
    fi

    # `jj config get` exits 0 whether or not the key is set, so the guard has to
    # look at the output rather than the exit code.
    if ! command -v jj >/dev/null 2>&1; then
      echo "jj:   not installed, skipping"
    elif [ -n "$(jj config get user.name 2>/dev/null)" ] && [ -n "$(jj config get user.email 2>/dev/null)" ]; then
      echo "jj:   already configured as $(jj config get user.name) <$(jj config get user.email)>"
    else
      jj config set --user user.name "$name"
      jj config set --user user.email "$email"
      echo "jj:   set user.name/user.email to $name <$email>"
    fi
