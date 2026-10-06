# CI

`lint.yml` and `test.yml` run on every push and pull request, and
`devcontainer.yml` and `nix.yml` when their files change. On the runner
itself only `nix.yml` needs Nix, and only `test.yml` needs mise. Actions are
pinned to commit SHAs, with the tag in a comment.

## editorconfig

`editorconfig-checker` checks every file against `.editorconfig`: charset,
line endings, final newline, trailing whitespace and indentation. Markdown
indentation is left alone, since list continuations align with the item's
text, `.claude/settings.json` keeps the two spaces Claude Code writes, and
`tools/git/config` the tabs git writes.

`.editorconfig-checker.json` excludes files that aren't ours to reformat:

- `LICENSE`, `LICENSES/`: license texts, as published.
- `.devcontainer-lock.json`: written by the devcontainer CLI.

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
- `tests/zsh.bats` checks `tools/zsh/interactive.zsh`: it parses and loads
  silently, its options, key bindings and aliases, typing `..` or a
  directory's name at a real prompt (driven through `zpty`), and the chpwd
  hook in jj and git repositories. jj comes from the root `mise.toml`; the
  job checks it's there, since the jj tests skip without it.
- `tests/configs.bats` checks the plain-file configs `[dotfiles]` links: every
  TOML file parses (`tools/helix/config.toml` included; helix itself starts
  on a broken one), jj loads `tools/jujutsu/config` and git
  `tools/git/config`, and neither sets identity, which would override the
  account's own.
- `tests/mise.bats` checks the root `mise.toml`: it's formatted, its
  `[dotfiles]` apply to a clean HOME and a second apply changes nothing, zsh
  started there gets the config, and a bad version pin fails an install (a
  dry run only warns, so the job's real `mise install` is the check).

Run them locally with `bats tests`.

## devcontainer

`devcontainer.yml` checks both devcontainers when their files change, in
three jobs:

- **config:** biome parses `.devcontainer.json` and
  `.devcontainer/mise/devcontainer.json` strictly (the devcontainer CLI's own
  parser accepts truncated JSONC), the CLI reads both, and `outdated` shows
  the locked features against their latest releases.
- **nix:** builds `.devcontainer.json` with `--experimental-frozen-lockfile`,
  so a lock that no longer matches the config fails. Its create command
  hooks direnv in, allows `.envrc` and builds the flake's dev shell; then
  `nix` runs inside, and `jj` and `just` through `direnv exec`, as a terminal
  there gets them. A second load must report nix-direnv's cache, since
  without nix-direnv direnv's own `use flake` still works, uncached and
  silently. It also runs when `.envrc` or the flake changes.
- **mise:** builds `.devcontainer/mise/`, whose create commands install mise
  and its tools and apply `[dotfiles]`, then checks a zsh that sources
  `~/.zshrc` gets `just`, `jj` and `hx` and the `AUTO_CD` that
  `interactive.zsh` sets.

develop's `prebuild` job, which pushes the image to GHCR, isn't here:
whether to publish images is still open.

## nix

`nix.yml` checks the flake in two jobs:

- **check:** `nix flake check --all-systems` evaluates every output for every
  system the flake lists, with `--no-update-lock-file` so a `flake.lock` that
  no longer matches the inputs fails. nixfmt, from the flake's own nixpkgs,
  checks every `*.nix` file.
- **shell:** builds the dev shell on each system (Linux x86_64 and arm64, and
  an Apple Silicon Mac) and checks `jj` and `just` run inside.

develop's third job, **home**, checks a home-manager profile, which comes
later.
