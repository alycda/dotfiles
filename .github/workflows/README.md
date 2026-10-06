# CI

`lint.yml` and `test.yml` run on every push and pull request. Neither needs
Nix, and only `test.yml` needs mise. Actions are pinned to commit SHAs, with
the tag in a comment.

## editorconfig

`editorconfig-checker` checks every file against `.editorconfig`: charset,
line endings, final newline, trailing whitespace and indentation. Markdown
indentation is left alone, since list continuations align with the item's
text, and `.claude/settings.json` keeps the two spaces Claude Code writes.

`.editorconfig-checker.json` excludes files that aren't ours to reformat:

- `LICENSE`, `LICENSES/`: license texts, as published.

Run it locally with `editorconfig-checker`.

## shellcheck

`shellcheck` (a pinned release, verified by checksum) runs on every shell
script that `.github/scripts/shell-files` finds: `*.sh` and `*.bats` files,
and anything whose shebang runs sh, bash, dash, ksh or bats. zsh is left out
(shellcheck doesn't support it). The shell inside `justfile` recipes isn't a
file, so it isn't checked. Run it locally with
`.github/scripts/shell-files -0 | xargs -0 shellcheck`.

## reuse

`reuse lint` checks that every file declares its license and copyright.
`REUSE.toml` does that by path, so no file needs a header: everything is MIT,
as `LICENSE` and the README say. The SPDX text is in `LICENSES/`. A file that
needs another license gets its own annotation in `REUSE.toml`, after the
general one, since the last match wins.

## effver

`tools/effver/check-effver HEAD` checks `VERSION` and `CHANGELOG.md` against
EffVer in every commit of the history, which needs the full clone
(`fetch-depth: 0`). It's the git form of `just check-effver`, which checks
only the jj stack not on trunk yet. The rules are in the script's header.

## bats

`test.yml` runs every [bats](https://github.com/bats-core/bats-core) suite in
`tests/`, with the `just` version it pins.

- `tests/tasks.bats` checks the HUID task recipes in the `justfile` against
  the spec in `tasks/README.md`: the HUID and its collision handling, the
  TASK.md template, `task-edit`, and every task already in the repo.
- `tests/effver.bats` checks `tools/effver/bump-effver`: which number each
  effort bumps, in `0.x` and after, where the new changelog heading goes, and
  that a bad effort or a missing `VERSION` fails. It checks `check-effver`
  against small git histories, one rule each.
- `tests/mise.bats` checks that the root `mise.toml` is formatted, and the
  job's own `mise install` checks that its tools install.

Run them locally with `bats tests`.
