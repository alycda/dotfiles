# Changelog

Versions follow [EffVer](https://jacobtomlinson.dev/effver/):
`MACRO.MESO.MICRO`, where the number that changes says how much effort it
takes to adopt the change. Macro: a large effort. Meso: some effort. Micro:
no effort. In `0.x` the format is `0.MACRO.MICRO`.

Each heading is `## <version> (<effort>) - <date>`. `just bump <effort>`
adds one, and `just check-effver` checks it against `VERSION`.

## 0.1.3 (micro) - 2026-10-03

- Two devcontainers, both on Debian bookworm. The default has jj and just
  from the Nix feature. `.devcontainer/mise/` has only mise: it installs the
  tools before VS Code attaches, then applies `[dotfiles]`. VS Code
  recommends the Dev Containers extension.
- Outside the devcontainers, VS Code keeps git source control again, next
  to VisualJJ. To turn git off where VisualJJ or JJK is installed, the two
  lines to copy are commented in `.vscode/settings.json`.

## 0.1.2 (meso) - 2026-10-03

- gh, Claude Code and tmux from mise. Claude Code is exempt from mise's
  minimum release age.
- Setup recipes for a new machine: `just identity` creates an SSH key, logs
  `gh` in, and sets git and jj identity from the GitHub account.
- Every just recipe calls a script, in `tasks/scripts/` or `tools/`.
- Plain-file configs for helix, zsh, jujutsu, git and just live in `tools/`,
  and `mise dotfiles apply` links them into `$HOME`. The helix config moves
  there from `.helix/`.
- The HUID task recipes are global: `just -g task "Title"` works in any
  directory, writing to `tasks/` where there is one and to the globally
  ignored `.tasks/` elsewhere. In this repo, `just task` is unchanged.
- sem, weave and inspect from mise, with the entity-level-git skill. The
  jujutsu skill resolves conflicts with weave.
- just is pinned to 1.58.
- Ignores Claude Code's local files and worktrees, and Nix and direnv
  output.
- VS Code recommends the Claude Code extension.

To adopt: `mise install`, for the new tools and the just pin. Then
`mise dotfiles apply`: until it links the helix config, helix in this repo
no longer shows hidden files in its file picker. It leaves existing files
alone: `mise dotfiles apply --dry-run` names them; move them aside, or merge
them into `tools/`, before applying.

## 0.1.1 (meso) - 2026-10-02

- Jujutsu 0.45.1 from mise, with a jujutsu skill for Claude Code (and
  `.agents/`) and jj cheatsheets in `.cheat/` (cheat, also from mise)
- compound-engineering plugin for Claude Code (its ce-commit skill), and its
  `CONCEPTS.md`
- `tools/effver/check-effver` checks `VERSION` and `CHANGELOG.md` in every
  commit of a range: `just check-effver [REVSET]`
- VS Code: recommends the jj extensions, turns off git source control and
  Copilot chat

To adopt: `mise install`. In VS Code, install the recommended jj extensions
(jjk, VisualJJ): git source control is off, so without them there is none.
Claude Code asks once to trust the compound-engineering marketplace.

## 0.1.0 (macro) - 2026-10-01

- Versioned with EffVer: `VERSION`, this changelog, and `just bump <effort>`
  to start the next version. MIT license.
- helix, just and taskbook from mise, with helix as `$EDITOR`.
- Tasks tracked in `tasks/`, one directory per HUID: `just task "Title"`
  creates one, and `just task-edit "Title"` also opens it.
- EditorConfig, and VS Code settings with recommended extensions for the
  file types here. helix shows hidden files in its file picker.
- Ignores OS clutter, jj's store and VS Code workspace files.

To adopt: install mise (see README.md), then `mise install`.
