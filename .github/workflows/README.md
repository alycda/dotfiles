# CI

`lint.yml` and `test.yml` run on every push and pull request. They need
neither Nix nor mise. `devcontainer.yml`, `extension.yml` and `nix.yml` run
when their files change. Actions are pinned to commit SHAs, with the tag in a
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
in the repo. `tests/zsh.bats` checks `tools/zsh/interactive.zsh`: it parses and
loads silently, its options, key bindings and aliases, typing `..` or a
directory's name at a real prompt (driven through `zpty`), and the chpwd hook
in jj and git repositories. `tests/mise.bats` checks the root `mise.toml`: it's
formatted, its `[dotfiles]` apply to a clean HOME and a second apply changes
nothing, zsh started there gets the config, and a bad version pin fails an
install (a dry run only warns, so the job's real `mise install` is the check).
`tests/import-issue.bats` checks `just import-issue` against a stubbed `gh`:
the HUID from when the issue was opened, the TASK.md for open and closed
issues, argument checks, and importing twice or into a taken second. One test
sends the real query to GitHub. It runs only when `GH_TOKEN` is set, which
the job sets from its own token. Run them locally with `bats tests`, or
`GH_TOKEN="$(gh auth token)" bats tests` to include that test.

## devcontainer

`devcontainer.yml` checks the Nix devcontainer in three jobs:

- **config:** biome parses `.devcontainer.json` strictly (the devcontainer
  CLI's own parser accepts truncated JSONC), the CLI reads it, and `outdated`
  shows the locked features against their latest releases.
- **build:** builds with `--experimental-frozen-lockfile`, so a lock that no
  longer matches the config fails, then checks `jj` and `nix` run inside. It
  skips `postAttachCommand`, which needs an attached VS Code.
- **prebuild:** pushes the image to `ghcr.io/<repo>/devcontainer:nix`. It only
  runs when started by hand from the Actions tab, so nothing is published
  until you choose to.

## nix

`nix.yml` checks the flake in three jobs:

- **check:** `nix flake check --all-systems` evaluates every output for every
  system the flake lists, with `--no-update-lock-file` so a `flake.lock` that
  no longer matches the inputs fails. nixfmt, from the flake's own nixpkgs,
  checks every `*.nix` file.
- **shell:** builds the dev shell on each system (Linux x86_64 and arm64, and
  an Apple Silicon Mac) and checks `jj` and `just` run inside.
- **home:** switches the devcontainer profile for a `vscode` user that already
  has a `~/.zshrc`, like the image's oh-my-zsh one. home-manager must take it
  over, keeping the old one as `~/.zshrc.backup`. Then
  `.github/scripts/check-hm-zsh` checks an interactive zsh: home-manager's
  defaults (history sharing, compinit, `EDITOR`) and everything
  `tools/zsh/interactive.zsh` sets. It also runs when `tools/zsh/` changes.

## extension

`extension.yml` checks the HUID Tasks extension:

- **unit:** `node --test` runs `test/` on Node 20 and 22: the logic in
  `tasks.js` against `tasks/README.md`, and contract tests against the
  manifest, the repo's tasks, and a task `just task` really creates.
- **types:** `tsc --checkJs` against the typings for the oldest VS Code in
  `engines` (1.74) and its Node (16), to catch an API that VS Code lacks.
  Not strict.
- **lint:** `biome lint`.
- **package:** `vsce package`, as `just vscode-tasks-install` does, then checks
  the VSIX holds every file the extension needs and none of its tests.

Run the tests locally with `node --test extensions/vscode-huid-tasks/test/*.test.js`.
