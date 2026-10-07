# Changelog

Versions follow [EffVer](https://jacobtomlinson.dev/effver/):
`MACRO.MESO.MICRO`, where the number that changes says how much effort it
takes to adopt the change. Macro: a large effort. Meso: some effort. Micro:
no effort. In `0.x` the format is `0.MACRO.MICRO`.

Each heading is `## <version> (<effort>) - <date>`. `just bump <effort>`
adds one, and `just check-effver` checks it against `VERSION`.

## 0.1.8 (meso) - 2026-10-06

- nix-darwin builds the first real Mac, with a primary user: the admin who runs
  darwin-rebuild and the owner of its Homebrew.
- `darwin/homebrew.nix`: Homebrew managed by nix-darwin for the hosts that
  import it. Nothing is removed, updated or upgraded unless a host opts in,
  and `brew shellenv` moves to `/etc/zshrc`, since home-manager owns
  `~/.zprofile`. tart imports it; its empty Brewfile left every formula in
  place and brew on `PATH` in an interactive zsh.
- `/etc/zshrc` runs `compinit -i`, so an account without home-manager no longer
  gets compaudit's prompt at every login about completion dirs owned by the admin's
  Homebrew or the shared Nix profile.
- `just brew-upgrade`: upgrade Homebrew's formulae and casks between switches,
  since the module only does that on activation when a host opts in.
- Still to define, in task 20261003-082724: shesfast's casks, defaults and
  profile.

To adopt: nothing changes until shesfast switches to its configuration.

## 0.1.7 (meso) - 2026-10-06

- nix-darwin, for the Macs: `darwin/configuration.nix` for the system,
  with home-manager as its module for the primary user, so a Mac gets the
  same configs, tools and secrets as the devcontainer. Minimal so far:
  flakes, zsh, and no Homebrew.
- One Mac so far, `tart`: user `admin` in a Tart VM cloned from Cirrus
  Labs' macOS base image, for trying a switch on a throwaway Mac.
  `sudo nix run .#darwin-rebuild -- switch --flake .#tart` applies it.
- Profiles (`home-manager/profiles/`): `dev` for the containers, the VM
  and `code`, `home` and `work` for the two Macs to come. `home` and
  `work` are empty for now.
- The dev profile has Rust (rustup, bacon, cc, pkg-config; the first
  switch installs the stable toolchain and rust-analyzer, and goes on
  without them when offline), docker's CLI, and nil for Nix in helix.
- `code@aarch64-darwin`: a Mac account without sudo, on the dev profile.
  It switches its own home with
  `nix run .#home-manager -- switch -b backup --flake .#code@aarch64-darwin`.
- `just check`, `update`, `build`, `switch`, `generations` and `rollback`
  apply the flake to the account they run in: nix-darwin for an admin on
  a Mac, home-manager for anyone else (`code`) and on Linux.
- The README says how to edit `/etc/nix/nix.conf` on a Mac without
  nix-darwin: flakes on for every command, and the daemon limited to the
  `nix-users` group.

To try nix-darwin on a Mac: the first switch stops on `/etc/bashrc` and
`/etc/zshrc`; rename each to `<file>.before-nix-darwin` and switch again.
home-manager then moves `~/.zprofile` to `~/.zprofile.backup`, and
whatever it held stops running, such as Homebrew's `brew shellenv`.

## 0.1.6 (micro) - 2026-10-04

- Secrets with agenix: home-manager installs every `.age` file under
  `secrets/` into `~/.local/share/agenix/`, decrypted with the age key at
  `~/.age/personal-key.txt`. Without the key it warns and goes on.
- `just edit-secret NAME` creates or edits `secrets/NAME.age`, encrypted to
  the keys in `secrets/recipients.txt`. It needs the dev shell, which now
  has rage and ragenix.
- The Nix devcontainer mounts the host's `~/.age` read-only, and creates
  the directory on the host first if it is missing.
- The Docker image installs the secrets when the container starts, if
  `~/.age` is mounted; `just docker-run` mounts it when the host has one.
- On macOS, the dev shell and `edit-secret` work. Installing secrets there
  waits for nix-darwin.

To use secrets: put an age key at `~/.age/personal-key.txt` (mode 600,
ending in a newline), add its public key to `secrets/recipients.txt`, then
`just edit-secret NAME` in the dev shell.

## 0.1.5 (meso) - 2026-10-03

- home-manager: the configs in `tools/` and the tools from mise, for a Nix
  account. It takes over zsh and direnv. sem, weave, inspect and taskbook's
  Rust port are the same release binaries as mise's, patched to run from
  the Nix store.
- The Nix devcontainer applies it when the container is created, and gets
  direnv from it.
- A Dockerfile: an image with the home-manager generation built in, for
  `docker run` on a machine without Nix. `just docker-build` and
  `just docker-run`.

To adopt: rebuild the Nix devcontainer. Its create command now switches to
home-manager (`vscode@<arch>-linux`), which takes over zsh and keeps the old
`~/.zshrc` as `~/.zshrc.backup`. The Docker image is optional:
`just docker-build`. Nothing changes on the Mac or in the mise setup.

## 0.1.4 (meso) - 2026-10-03

- A Nix flake with a dev shell (`nix develop`), for macOS on Apple silicon
  and Linux. It only has `jj` and `just` for now.
- `.envrc` loads that dev shell through direnv and nix-direnv. On a machine
  without direnv it does nothing.
- The Nix devcontainer gets jj and just from the dev shell instead of the
  Nix feature: it installs direnv, hooks it into bash and zsh, and builds
  the shell when the container is created. VS Code loads the same
  environment through the direnv extension.
- The README says these are Nix dotfiles, with mise for machines that
  can't or won't install Nix, and that either one is enough. Its Nix
  section installs Nix, sets up direnv, and shows how to drop mise when
  moving from it to Nix.

To adopt: optional; the mise setup keeps working. To move to Nix, follow
the README's Nix section: install Nix, check the dev shell, set up direnv,
then `mise implode` so `jj` and `just` come from one place.

## 0.1.3 (micro) - 2026-10-03

- Two devcontainers, both on Debian bookworm. The default has jj and just
  from the Nix feature. `.devcontainer/mise/` has only mise: it installs the
  tools before VS Code attaches, then applies `[dotfiles]`. VS Code
  recommends the Dev Containers extension.
- Outside the devcontainers, VS Code keeps git source control again, next
  to VisualJJ. To turn git off where VisualJJ or JJK is installed, the two
  lines to copy are commented in `.vscode/settings.json`.

## 0.1.2 (meso) - 2026-10-03

- gh, Claude Code and tmux from mise. Claude Code is exempt from mise's
  minimum release age.
- Setup recipes for a new machine: `just identity` creates an SSH key, logs
  `gh` in, and sets git and jj identity from the GitHub account.
- Every just recipe calls a script, in `tasks/scripts/` or `tools/`.
- Plain-file configs for helix, zsh, jujutsu, git and just live in `tools/`,
  and `mise dotfiles apply` links them into `$HOME`. The helix config moves
  there from `.helix/`.
- The HUID task recipes are global: `just -g task "Title"` works in any
  directory, writing to `tasks/` where there is one and to the globally
  ignored `.tasks/` elsewhere. In this repo, `just task` is unchanged.
- sem, weave and inspect from mise, with the entity-level-git skill. The
  jujutsu skill resolves conflicts with weave.
- just is pinned to 1.58.
- Ignores Claude Code's local files and worktrees, and Nix and direnv
  output.
- VS Code recommends the Claude Code extension.

To adopt: `mise install`, for the new tools and the just pin. Then
`mise dotfiles apply`: until it links the helix config, helix in this repo
no longer shows hidden files in its file picker. It leaves existing files
alone: `mise dotfiles apply --dry-run` names them; move them aside, or merge
them into `tools/`, before applying.

## 0.1.1 (meso) - 2026-10-02

- Jujutsu 0.45.1 from mise, with a jujutsu skill for Claude Code (and
  `.agents/`) and jj cheatsheets in `.cheat/` (cheat, also from mise)
- compound-engineering plugin for Claude Code (its ce-commit skill), and its
  `CONCEPTS.md`
- `tools/effver/check-effver` checks `VERSION` and `CHANGELOG.md` in every
  commit of a range: `just check-effver [REVSET]`
- VS Code: recommends the jj extensions, turns off git source control and
  Copilot chat

To adopt: `mise install`. In VS Code, install the recommended jj extensions
(jjk, VisualJJ): git source control is off, so without them there is none.
Claude Code asks once to trust the compound-engineering marketplace.

## 0.1.0 (macro) - 2026-10-01

- Versioned with EffVer: `VERSION`, this changelog, and `just bump <effort>`
  to start the next version. MIT license.
- helix, just and taskbook from mise, with helix as `$EDITOR`.
- Tasks tracked in `tasks/`, one directory per HUID: `just task "Title"`
  creates one, and `just task-edit "Title"` also opens it.
- EditorConfig, and VS Code settings with recommended extensions for the
  file types here. helix shows hidden files in its file picker.
- Ignores OS clutter, jj's store and VS Code workspace files.

To adopt: install mise (see README.md), then `mise install`.
