# HUID Tasks

VS Code extension that lists open tasks from `tasks/<HUID>/TASK.md` in an
"Open Tasks" view in the Explorer sidebar. Each row shows the task's title with
its creation time, parsed from the HUID and rendered in local time, in greyed
text. Clicking a row opens its `TASK.md`. Newest first.

A task is listed when its `- STATUS:` line reads `OPEN` (case-insensitive). The
view refreshes when any `TASK.md` is created, changed, or deleted.

Plain CommonJS, no dependencies, no build step.

## Run

- Develop: open this repo in VS Code and run the "Run HUID Tasks extension"
  launch configuration (F5). It opens an Extension Development Host on this
  workspace.
- Install: `huid-tasks-vscode` (in `tasks/scripts/`) zips the extension into a
  VSIX and installs it with `code --install-extension`, or with the VS Code
  server's CLI in a devcontainer. No Node is needed. It runs after every
  `mise install`, and on attach in both devcontainers.
