# vscode-huid: integration tests in a real VS Code

- STATUS: OPEN
- TAGS: ci, vscode, testing

## Description

The unit and contract tests (`extensions/vscode-huid-tasks/test/`) run the
extension's logic in plain Node, and the `types` job checks it against the
1.74 API. Neither runs the extension inside VS Code. That's the one gap left:
activation, the tree view and the refresh command, as a user sees them.

- **Harness.** `@vscode/test-cli` with `@vscode/test-electron`: download VS
  Code, open a fixture workspace, run mocha tests in the extension host. On
  Linux CI it needs a display (`xvfb-run`).
- **Versions.** Run against the oldest VS Code in `engines` (1.74) and the
  current stable, so a raised `engines` floor is a deliberate choice.
- **Fixture.** A small workspace with `tasks/<HUID>/TASK.md` files: open,
  closed, suffixed, lowercase `open`, and one without a title.
- **What to check:**
  - The extension activates because of `workspaceContains:tasks/*/TASK.md`,
    and not in a workspace without tasks.
  - The Open Tasks view lists the fixture's OPEN tasks, newest first, with
    the labels and descriptions `tasks.js` computes.
  - Creating, editing and deleting a TASK.md updates the view (the file
    watcher), and so does the refresh command.
  - Clicking a task opens its file.
- **Cost.** It's the only check that needs npm dependencies (dev-only, kept
  out of the VSIX by `files`) and a VS Code download, and it takes minutes. So
  it should be its own job, run only when the extension changes, like
  `extension.yml`.
