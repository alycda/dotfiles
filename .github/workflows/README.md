# CI

`lint.yml` and `test.yml` run on every push and pull request, and need
neither Nix nor mise. Actions are pinned to commit SHAs, with the tag in a comment.

## editorconfig

`editorconfig-checker` checks every file against `.editorconfig`: charset,
line endings, final newline, trailing whitespace and indentation.

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

## bats

`test.yml` runs every [bats](https://github.com/bats-core/bats-core) suite in
`tests/`, with the `just` version it pins. `tests/tasks.bats` checks the HUID
task recipes in the `justfile` against the spec in `tasks/README.md`: the HUID
and its collision handling, the TASK.md template, `task-edit`, and every task
already in the repo. `tests/effver.bats` checks `tools/effver/bump-effver`:
which number each effort bumps, in `0.x` and after, where the new changelog
heading goes, and that a bad effort or a missing `VERSION` fails. Run them
locally with `bats tests`.
