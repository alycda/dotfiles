# presenterm-lsp

A language server and headless checker for [presenterm](https://github.com/mfontanini/presenterm) decks.

```
presenterm-lsp                  # speak LSP over stdio
presenterm-lsp --check FILE...  # print diagnostics, exit 1 on any error
presenterm-lsp --check --format json FILE...
```

## Why

presenterm has no way to answer "does this deck build?" outside an interactive
terminal. `--validate-overflows` needs a real screen to measure against, and on
a build error presenterm does not exit with a diagnostic — it opens its TUI and
displays the error in-app, waiting for the file to change. Verified against
0.16.1: a broken deck run under `script -qec` hangs until killed.

It also stops at the *first* error, so a typo on slide 2 hides everything after
it. This walks the whole document and reports every problem at once.

## What it checks

Everything in presenterm's `InvalidPresentation` that is decidable statically:

| | |
|---|---|
| comment commands | unknown/mistyped commands, with a "did you mean", honouring `options.command_prefix` and presenterm's ignore rules (`vim:`, `{{{`, `//`, multi-line) |
| layouts | `column` with no `column_layout`, re-entering the current column, column index out of range, empty and zero-sized layouts, content emitted before entering a column |
| values | `font_size` outside 1–7, `list_item_newlines` of 0 |
| front matter | invalid YAML, unknown keys, unknown options, unknown theme name (suppressed when `theme.path` is set) |
| images | missing files, unknown attributes, malformed `width` percentages |
| snippets | unknown `+attributes`, `+id:` on a non-`+exec` block, duplicate ids, `snippet_output:` with no matching id |
| includes | missing files, cycles, front matter in an included file, and an error count for problems inside one |

Plus completion (commands, theme names, front matter and `options` keys,
alignment values), hover docs, a slide outline via document symbols, and
go-to-definition on `include:` targets and image paths.

## Fidelity

`src/command.rs` is a deliberate mirror of presenterm's
`src/presentation/builder/comment.rs`: the enum, its `serde` attributes and the
`serde_yaml` `singleton_map` deserialization are copied verbatim, so the set of
comments accepted here is the set presenterm accepts — including aliases like
`newlines` and the fact that `comment:` is a real no-op command rather than an
ignored comment. Upstream's own test cases are mirrored in the unit tests.

Pinned to **presenterm 0.16.1** (`MIRRORED_PRESENTERM_VERSION`). When bumping,
diff `src/command.rs` against upstream's `CommentCommand` and
`should_ignore_comment`, and re-check the built-in theme list in
`BUILTIN_THEMES` against upstream's `themes/`.

## Activation

Editors attach this to plain `markdown`. The server decides per buffer whether
the document is a presenterm deck — front matter, or a comment that parses as a
real command — and stays silent otherwise, so ordinary prose gets no squiggles.
A comment that *fails* to parse is deliberately not evidence of a deck; a stray
`<!-- pasue -->` in a blog post switches nothing on.

`--check` bypasses the heuristic: naming a file explicitly is an assertion that
it is a deck.

Overrides: LSP `initializationOptions.alwaysActivate`, or a filename of
`slides.md`, `deck.md` or `*.presenterm.md`.

## Editor wiring

Installed and configured by `home-manager/modules/tools/presenterm.nix`; built
by `lib/presenterm-lsp.nix`.

- **helix** — `home-manager/modules/tools/helix.nix` lists it under the
  `markdown` language alongside `harper-ls`.
- **crush** — `home-manager/modules/tools/crush.nix` writes an `lsp.presenterm`
  entry into `crush.json`.
- **VS Code** — the extension in `editors/vscode/`, built from an
  `importNpmLock` pin of `vscode-languageclient` and placed in
  `~/.vscode/extensions`. The server's absolute store path is substituted in at
  build time because VS Code launched from Finder does not inherit a login
  shell's `PATH`.

## Development

```sh
cargo test          # unit tests + fixture decks under tests/fixtures/
cargo run -- --check ../../../RustConf2026/slides.md
```
