# Changelog

Versions follow [EffVer](https://jacobtomlinson.dev/effver/):
`MACRO.MESO.MICRO`, where the number that changes says how much effort it
takes to adopt the change. Macro: a large effort. Meso: some effort. Micro:
no effort. In `0.x` the format is `0.MACRO.MICRO`.

Each heading is `## <version> (<effort>) - <date>`. `just bump <effort>`
adds one, and `just check-effver` checks it against `VERSION`.

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
