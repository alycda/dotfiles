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
    # Relative to the justfile, where recipes run by default (task-edit does),
    # not to tasks/, where this one runs.
    printf 'tasks/%s\n' "${id}/TASK.md"

# Node is only needed to package the VSIX, not to run the extension (VS Code
# ships its own), so without npx on PATH it is fetched into the Nix store for
# this one command and left for nix-collect-garbage.
#
# Package the HUID Tasks VS Code extension and install it into VS Code.
[working-directory: "extensions/vscode-huid-tasks"]
vscode-tasks-install:
    #!/usr/bin/env bash
    set -euo pipefail
    stage="$(mktemp -d)"
    trap 'rm -rf "$stage"' EXIT
    mkdir "$stage/extension"
    cp package.json extension.js README.md "$stage/extension/"
    (cd "$stage" && zip -qr huid-tasks.vsix extension)
    # `code` works on the desktop and in a VS Code terminal. In a devcontainer
    # lifecycle command it is the base image's wrapper, which exits 127 because
    # VS Code only puts its CLI on the terminal's PATH. The server's own CLI
    # installs into the same extensions dir; take the newest server.
    if code --version >/dev/null 2>&1; then
        cli=code
    else
        shopt -s nullglob
        servers=(~/.vscode-server/bin/*/bin/code-server ~/.vscode-server/cli/servers/*/server/bin/code-server)
        [ ${#servers[@]} -gt 0 ] || { echo "no VS Code CLI: neither code nor a VS Code server found" >&2; exit 127; }
        cli="$(ls -t "${servers[@]}" | head -1)"
    fi
    "$cli" --install-extension "$stage/huid-tasks.vsix" --force
