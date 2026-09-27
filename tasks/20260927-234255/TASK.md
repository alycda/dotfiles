# Biome formatting for the extension's JavaScript

- STATUS: OPEN
- TAGS: ci, formatting, vscode

## Description

The extension's CI runs `biome lint`, which is clean, but not biome's
formatter. None of the JavaScript matches biome's formatting, including the
original `extension.js`: with 2-space indents, `biome format` would change 41
lines of `extension.js`, 6 of `tasks.js`, 27 of `test/tasks.test.js` and 39 of
`test/contract.test.js`, mostly line width and wrapping. So enforcing it was
left out of the CI commit as a separate decision.

To decide:

- **Settings.** A `biome.json`, or flags as `jj fix` uses for JSON today
  (`--indent-style=space --indent-width=...`). biome can also read
  `.editorconfig` (`formatter.useEditorconfig`), which keeps one source of
  truth for indentation. Line width: biome's default of 80, or wider.
- **Where it runs.** Add JavaScript to the biome tool in `jj fix` (its patterns
  cover only JSON now), so formatting happens before commit, like TOML,
  Markdown and JSON.
- **CI.** Swap `biome lint` for `biome ci`, which lints and checks formatting
  without writing, so an unformatted change fails.
- **The reformat itself.** One formatting-only commit, kept apart from any
  behaviour change so it's easy to review and to skip in blame.
