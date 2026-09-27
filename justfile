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
