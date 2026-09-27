# Install jj-stash: park commit chains out of every jj UI, restore them unchanged

- STATUS: OPEN
- TAGS: issue-183

## Description

see: https://github.com/alycda/dotfiles/issues/183

`jj-stash` parks chains of commits out of every jj UI (`jj log`, VisualJJ, jjk) and brings them back unchanged. I wrote it while curating this repo's fan-out, because VisualJJ has no revset setting, so `revsets.log` can't declutter it. For now it runs from a scratch copy by full path. It needs a real home here.

- Source, README (design, limits) and tests: https://github.com/alycda/jj/tree/jj-stash/contrib/jj-stash
- Upstream feature request for a native version: jj-vcs/jj#10268. If jj grows `hide`/`unhide`, this should be retired.

## Where the script lives

Vendored in `tools/jj-stash/`, unchanged, with its README and all three test scripts. `tools/jj-stash/UPSTREAM` records the source commit, `alycda/jj@1f1aafa`.

## Install on both kinds of account

It ships with jj, so, like the jujutsu skill (tasks/20260925-062442), it has to work wherever jj does:

- **Nix / home-manager:** `writeShellApplication` with `runtimeInputs` of bash, jj, git and coreutils. `writeShellApplication` runs shellcheck, so expect to fix or silence a few warnings.
- **mise (no Nix):** done. The root `mise.toml` links it into `~/.local/bin`. It needs **bash 4 or later** (`pop` uses associative arrays and `mapfile`), and mise's registry has no bash, so on a Mac with no Nix `env bash` finds `/bin/bash` 3.2 and the script fails at its first `declare -A`. On a Mac with nix-darwin, `env bash` resolves to the system profile's bash 5.x; the devcontainers have Debian's bash 5.x. The script has no version check of its own.
- **shellcheck** reports 7 info-level notes (SC2086 ×4, SC2016 ×3), all in the vendored script. `writeShellApplication` will need them fixed or excluded.

## Since the issue was opened

The fork gained `drop` (8d52960): it forgets a stash without restoring it,
deleting the refs, plaintext and index row, and prints the `jj new` that brings
the chain back until `jj util gc`. Then 1f1aafa narrowed when `drop` refuses,
by kind of dependency:

- **roots:** another stash's root sits on a commit parked here. Popping it
  would revive the dropped commits, so the drop is refused.
- **reattach:** another stash was only detached from a commit parked here (a
  lane cut out of a merge). The drop is allowed, with a note naming them.

`test-drop.sh` (24 cases) came with it.

## Already in place

- `.claude/stashes/` is in `.gitignore`: `usnoouov`, "ignore: .claude/stashes, jj-stash plaintext".
- The script also writes that rule into `.git/info/exclude` on every push, pop and `index`. The `.gitignore` rule alone doesn't protect the stash files when a commit older than it is checked out.

## When installing

- The existing stashes (27 as of 2026-09-27, in `~/WIP/jj-dotfiles`, not this checkout) were made with the scratch copy. They use the same `refs/jj-stash/*` layout, so the installed version picks them up unchanged.
- Run `jj-stash index` once afterwards, with any devcontainer closed. It writes `.claude/stashes/INDEX.md` and adds the exclude rule, which the real repo doesn't have yet.
- `pr-88` and `docs-readme`, the dependent pair this list used to name, are no longer parked (checked 2026-09-27). `jj-stash list` shows what each remaining stash needs popped first, and `pop --with-deps` handles the order.
- Stashes are local only: `jj git push` doesn't push `refs/jj-stash/*`. Decide whether `.claude/stashes/` should be backed up.

## Open questions

- **Name.** Keep `jj-stash`, or use `hide` / `unhide` to match Sapling and git-branchless? Upstream (jj-vcs/jj#10268), the one reply so far suggests `jj archive` with an `archived()` revset, since jj already uses "hidden" for something else. It also points at per-revision metadata (jj-vcs/jj#8166) as a possible native basis, and suggests asking UIs to honour `revsets.log`: jj-view already does.
- **Entry point.** Currently a plain command (`jj-stash`). A jj alias also works on jj 0.45: `stash = ["util", "exec", "--", "jj-stash"]` gives `jj stash …`. It has to be in user-level config, such as the repo scope in `tools/jujutsu/config`, because jj ignores aliases from `--config`.
- **Tests.** `test-deps.sh`, `test-drop.sh` and `test-index.sh` are pinned to change IDs in a lab copy of `~/WIP/jj-dotfiles`, and refuse to run outside a `scratchpad/lab` directory, so they can't run against this repo as they stand. Should there be a `just` recipe that builds that lab copy and runs them?
