# the first recipe is the default
_default: check

update:
    nix flake update

check:
    nix flake check

check-all:
    nix flake check --all-systems

# Run all linters (statix + deadnix)
[group('lint')]
lint: lint-statix lint-deadnix

# Check for Nix anti-patterns with statix
[group('lint')]
lint-statix:
    nix run nixpkgs#statix -- check .

# Check for unused code with deadnix
[group('lint')]
lint-deadnix:
    nix run nixpkgs#deadnix -- .

# Run all CI checks locally (lint + flake check)
[group('lint')]
ci: lint check

export USER := shell("whoami")

manager := if os() == "macos" { "darwin-rebuild" } else { "home-manager" }

# may require sudo
_rebuild USER="alyssa@dev":
    {{manager}} switch --flake .#{{USER}}

# darwin requires sudo, so we use home-manager for non-sudo "code" user on OSX
_rebuild-code:
    home-manager switch -b backup --flake .#code

# requires sudo
[group('darwin')]
darwin-generations:
    darwin-rebuild --list-generations

# requires sudo
[group('darwin')]
rollback-to generation:
    darwin-rebuild --switch-generation {{generation}}

# queries and lists all packages installed in the current user's profile
_list-env:
    nix-env -qaP

# displays the packages currently installed in a specified profile
_list-profile:
    nix profile list

[group('darwin')]
build-dry-run-darwin USER:
    nix build .#darwinConfigurations.{{USER}}.system --dry-run

build-dry-run USER:
    nix build --dry-run --json .#homeConfigurations."{{USER}}".activationPackage 2>&1 | head -20

eval USER:
    nix eval --json .#homeConfigurations."{{USER}}".config.home.stateVersion

# parse file for correct syntax
_nix-check file:
    nix-instantiate --parse {{file}}

# Step 1 on every machine (after activation - see README bootstrap tree).
# Deliberately interactive: per-device OAuth tokens, no agenix-carried PAT
# (the README's "Why no encrypted PAT?" note has the trade-offs).
_login:
    gh auth login --web
    claude login

# Build the dev container image from this checkout
[group('docker')]
docker-build:
    ./docker/dev.sh build-local

# Run the dev container, mounting the current directory at /work
[group('docker')]
docker-run dir=invocation_directory():
    ./docker/dev.sh run {{dir}}

# Assemble the combined agent instruction capsule (public layers + local overlay)
[group('agents')]
agents-capsule:
    #!/usr/bin/env bash
    set -euo pipefail
    agents="$HOME/.agents"
    printf 'Agent instruction capsule\n'
    printf 'Source: alycda/dotfiles + private overlay\n'
    printf 'Generated: %s\n' "$(date +%Y-%m-%d)"
    printf 'Version/hash: %s\n' "$(git -C {{justfile_directory()}} rev-parse --short HEAD 2>/dev/null || echo unknown)"
    # AGENTS.md first: the capsule must carry the entrypoint's precedence and
    # composition contract, not just the layer bodies. Its @import lines are
    # dropped — inert in a paste, and the layers are inlined right below.
    for f in AGENTS.md company-values.md personal-constitution.md instructions.private.md; do
      if [ -f "$agents/$f" ]; then
        printf '\n<!-- %s -->\n\n' "$f"
        sed '/^@/d' "$agents/$f"
      fi
    done

# Copy the compiled capsule to the clipboard (macOS pbcopy)
[group('agents')]
agents-copy:
    just agents-capsule | pbcopy && echo "Copied agent capsule to clipboard"

# Resolve the age identity ragenix needs, or explain how to get one. Extracted
# so edit-secret and rekey-secrets share one answer to "where is the key".
_age-identity:
    #!/usr/bin/env bash
    set -euo pipefail
    key="${RAGENIX_IDENTITY:-$HOME/.age/personal-key.txt}"
    if [ ! -f "$key" ]; then
      echo "No age identity at $key" >&2
      echo "Copy it from a machine that has it, e.g.:" >&2
      echo "  docker cp ~/.age/personal-key.txt <container>:/root/.age/personal-key.txt" >&2
      exit 1
    fi
    echo "$key"

# Edit an age-encrypted secret, e.g. `just edit-secret personal/git-config.age`
[group('secrets')]
edit-secret path:
    #!/usr/bin/env bash
    set -euo pipefail
    # ragenix's CLI reads neither our Nix config nor the rules' location. It
    # hunts for SSH keys in ~/.ssh (which the dev container doesn't have) and
    # defaults --rules to ./secrets.nix (ours lives in secrets/), so both flags
    # are needed on every invocation. Forgetting -i surfaces as "No usable
    # identity", which reads like a lost key rather than a missing flag. The
    # identity path matches age.identityPaths in home-manager/modules/git.nix;
    # keep the two in step.
    key="$(just _age-identity)"
    # Recipes run from the repo root, so accept the path as typed from either
    # here ('secrets/personal/x.age') or from inside secrets/ ('personal/x.age').
    rel="{{ path }}"
    # $EDITOR is a required argument that merely defaults from the environment,
    # so an unset EDITOR fails with a clap usage dump rather than anything
    # actionable — exactly the confusion this recipe exists to prevent.
    exec ragenix --rules secrets/secrets.nix -i "$key" \
      --editor "${EDITOR:-hx}" -e "secrets/${rel#secrets/}"

# Re-encrypt every secret for the recipients in secrets/secrets.nix
[group('secrets')]
rekey-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    key="$(just _age-identity)"
    ragenix --rules secrets/secrets.nix -i "$key" --rekey
