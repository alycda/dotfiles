# Composes `task` rather than repeating its HUID and collision logic - it reads
# the path that recipe prints on stdout.
#
# Create a task and open it in $EDITOR (helix by default)
task-edit title:
    #!/usr/bin/env bash
    set -euo pipefail
    file="$(just task {{ quote(title) }})"
    exec "${EDITOR:-hx}" "$file"

# Create a task directory named with a UTC HUID and seed its TASK.md.
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
    printf '%s\n' "${id}/TASK.md"

# Package the HUID Tasks VS Code extension and install it into VS Code.
[working-directory: "extensions/vscode-huid-tasks"]
# Node is only needed to package the VSIX, not to run the extension (VS Code
# ships its own), so without npx on PATH it is fetched into the Nix store for
# this one command and left for nix-collect-garbage.
vscode-tasks-install:
    #!/usr/bin/env bash
    set -euo pipefail
    vsce=(npx --yes @vscode/vsce package --no-dependencies --skip-license --allow-missing-repository -o huid-tasks.vsix)
    if command -v npx >/dev/null; then
        "${vsce[@]}"
    else
        nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#nodejs --command "${vsce[@]}"
    fi
    code --install-extension huid-tasks.vsix --force
