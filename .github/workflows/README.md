# CI

`lint.yml` and `test.yml` run on every push and pull request. They need
neither Nix nor mise. Actions are pinned to commit SHAs, with the tag in a
comment.

## editorconfig

`editorconfig-checker` checks every file against `.editorconfig`: charset,
line endings, final newline, trailing whitespace and indentation. Markdown
indentation is left to rumdl (`jj fix`), since list continuations align with
the item's text.

`.editorconfig-checker.json` excludes files that aren't ours to reformat:

- `LICENSE`, `LICENSES/`: license texts, as published.
- `*.age`: encrypted secrets.
- `.devcontainer-lock.json`: written by the devcontainer CLI.
- `tools/jj-stash/`: vendored, kept identical to upstream.

## shellcheck

`shellcheck` (a pinned release, verified by checksum) runs on every shell
script that `.github/scripts/shell-files` finds: `*.sh` and `*.bats` files,
and anything whose shebang runs sh, bash, dash, ksh or bats. zsh is left out
(shellcheck doesn't support it), and so is the vendored `tools/jj-stash/`. The
shell inside `justfile` recipes isn't a file, so it isn't checked. Run it
locally with `.github/scripts/shell-files -0 | xargs -0 shellcheck`.

## reuse

`reuse lint` checks that every file declares its license and copyright.
`REUSE.toml` does that by path, so no file needs a header. Everything is
CC-BY-4.0, as the README says, except code and config, which are MIT, and
Markdown and cheatsheets, which stay CC-BY-4.0 wherever they sit. The texts are
in `LICENSES/`. When a new kind of file fails this check, add it to the right
annotation in `REUSE.toml`.

## bats

`test.yml` runs every [bats](https://github.com/bats-core/bats-core) suite in
`tests/`, with the `just` version mise pins. `tests/huid-tasks.bats` checks the
HUID task recipes against the spec in `tasks/README.md`: the HUID and its
collision handling, the TASK.md template, `task-edit`, and every task already
in the repo. Run them locally with `bats tests`.
