# CI

`lint.yml` and `test.yml` run on every push and pull request. Neither needs
Nix, and only `test.yml` needs mise. Actions are pinned to commit SHAs, with
the tag in a comment.

## editorconfig

`editorconfig-checker` checks every file against `.editorconfig`: charset,
line endings, final newline, trailing whitespace and indentation. Markdown
indentation is left alone, since list continuations align with the item's
text, `.claude/settings.json` keeps the two spaces Claude Code writes, and
`tools/git/config` the tabs git writes.

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

## links

`.github/scripts/check-links` fails on a tracked symlink whose target is
missing: `AGENTS.md` points at `CLAUDE.md`, and each skill in
`.agents/skills/` at its directory in `.claude/skills/`.

## skills

`.github/scripts/check-skills` checks each skill's `SKILL.md` frontmatter, in
`.claude/skills/` and `.agents/skills/`, against the
[Agent Skills spec](https://agentskills.io/specification): it parses as YAML,
`name` is lowercase with single hyphens, at most 64 characters, and matches
its directory, and `description` is at most 1024 characters. A loader skips a
skill that fails these, often without saying so. It needs mikefarah's `yq`,
which the runner has.

## effver

`tools/effver/check-effver HEAD` checks `VERSION` and `CHANGELOG.md` against
EffVer in every commit of the history, which needs the full clone
(`fetch-depth: 0`). It's the git form of `just check-effver`, which checks
only the jj stack not on trunk yet. The rules are in the script's header.

## bats

`test.yml` runs every [bats](https://github.com/bats-core/bats-core) suite in
`tests/`, with the `just` version it pins.

- `tests/tasks.bats` checks the global HUID task recipes (`tools/just`, run
  as `just -g` runs them, with `tasks/scripts` on `PATH` as mise puts it)
  against the spec in `tasks/README.md`: the HUID and its collision handling,
  the TASK.md template, `task-edit`, where a task goes (`tasks/`, else
  `.tasks/`, or `TASKS_DIR`), that the repo's `justfile` imports them, and
  every task already in the repo.
- `tests/effver.bats` checks `tools/effver/bump-effver`: which number each
  effort bumps, in `0.x` and after, where the new changelog heading goes, and
  that a bad effort or a missing `VERSION` fails. It checks `check-effver`
  against small git histories, one rule each.
- `tests/cheat.bats` checks that cheat, with `tools/cheat/conf.yml`, lists
  and shows every sheet in `.cheat/`: one sheet whose front matter doesn't
  parse stops cheat for all of them.
- `tests/mise.bats` checks the root `mise.toml`: it's formatted, its
  `[dotfiles]` apply to a clean HOME and a second apply changes nothing, zsh
  started there gets the config, and a bad version pin fails an install (a
  dry run only warns, so the job's real `mise install` is the check).

Run them locally with `bats tests`.
