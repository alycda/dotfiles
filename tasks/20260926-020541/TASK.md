# Install jj-stash: park commit chains out of every jj UI, restore them unchanged

- STATUS: OPEN
- TAGS: issue-183

## Description

see: https://github.com/alycda/dotfiles/issues/183

`jj-stash` parks chains of commits out of every jj UI (`jj log`, VisualJJ, jjk) and brings them back unchanged. I wrote it while curating this repo's fan-out, because VisualJJ has no revset setting, so `revsets.log` can't declutter it. For now it runs from a scratch copy by full path. It needs a real home here.

- Source, README (design, limits) and tests: https://github.com/alycda/jj/tree/jj-stash/contrib/jj-stash
- Upstream feature request for a native version: jj-vcs/jj#10268. If jj grows `hide`/`unhide`, this should be retired.

## Where the script should live

Vendor it rather than fetch it from the jj fork: it's one bash file, and it should change with this repo, not with jj. Something like `tools/jj/stash` or `tools/jj-stash/`, with the two test scripts next to it.

## Install on both kinds of account

It ships with jj, so, like the jujutsu skill (tasks/20260925-062442), it has to work wherever jj does:

- **Nix / home-manager:** `writeShellApplication` with `runtimeInputs` of bash, jj, git and coreutils. `writeShellApplication` runs shellcheck, so expect to fix or silence a few warnings.
- **mise (no Nix):** needs **bash 4 or later**, because `pop` uses associative arrays and `mapfile`. macOS's `/bin/bash` is 3.2. Either mise provides a newer bash (check whether one is available and pinnable), or document the command as Nix-only. It can be linked into `~/.local/bin` through the root `mise.toml`'s `[dotfiles]`.

## Already in place

- `.claude/stashes/` is in `.gitignore`: `usnoouov`, "ignore: .claude/stashes, jj-stash plaintext".
- The script also writes that rule into `.git/info/exclude` on every push, pop and `index`. The `.gitignore` rule alone doesn't protect the stash files when a commit older than it is checked out.

## When installing

- The 28 existing stashes were made with the scratch copy. They use the same `refs/jj-stash/*` layout, so the installed version picks them up unchanged.
- Run `jj-stash index` once afterwards, with any devcontainer closed. It writes `.claude/stashes/INDEX.md` and adds the exclude rule, which the real repo doesn't have yet.
- Current pop order: `pr-88` needs `docs-readme`. `jj-stash pop --with-deps pr-88` handles both.
- Stashes are local only: `jj git push` doesn't push `refs/jj-stash/*`. Decide whether `.claude/stashes/` should be backed up.

## Open questions

- **Name.** Keep `jj-stash`, or use `hide` / `unhide` to match Sapling and git-branchless?
- **Entry point.** A plain command, a `just` recipe, or a jj alias (`jj stash …`) if the pinned jj can alias to an external command.
- **Tests.** `test-deps.sh` and `test-index.sh` only run against a throwaway copy of the repo. Should there be a `just` recipe that builds that copy and runs them?
