# nix-darwin: the base configuration

- STATUS: OPEN
- TAGS: nix, darwin, home-manager, homebrew

## Description

Add nix-darwin to the flake: the system layer for the Macs, which home-manager
(per user) does not cover. This change is the base the hosts build on; the
hosts themselves are their own changes ("nix(darwin): shesfast",
"nix(darwin): ditto"), each with its own task.

### Planned

- A `nix-darwin` input, following nixpkgs, and a `mkDarwin` that takes the
  host, its primary user, and a profile. home-manager runs as the darwin
  module (`useGlobalPkgs`), with `home-manager/common.nix` and
  `home-manager/agenix.nix` as today, so a Mac gets the same configs and
  tools as the devcontainer.
- `darwin/configuration.nix`: `nix.settings` (flakes), `allowUnfree` scoped
  as in `pkgsFor` (claude-code only), the taskbook overlay, and the
  `system.defaults` that apply to every Mac.
- `darwin/modules/homebrew.nix`: nix-darwin manages Homebrew for what Nix
  can't (GUI apps as casks). Carry over the old repo's lessons: `cleanup =
  "zap"` removes anything unlisted; greedy casks for apps that can't update
  themselves; a tap formula that can't install aborts `darwin-rebuild` (the
  old inspect tap did).
- agenix: on darwin, the ragenix darwin module or home-manager's launchd
  agent installs secrets. `home-manager/agenix.nix` keeps its activation
  installer Linux-only, so nothing races.

### Assumptions to confirm before building

- **Admin rights.** `darwin-rebuild switch` needs an admin. The account this
  was planned from (`ditto` on Shesfast) can't even reach the Nix daemon
  socket. Which account runs it, on which Mac?
- **Homebrew already present**, and owned by which account. On a Mac where
  Homebrew belongs to another user, the casks and greedy upgrades behave
  differently (the old repo hit this).
- **What nix-darwin owns.** Dock, Finder, keyboard defaults, `/etc/zshrc`;
  anything it sets is authoritative, so leave unset what should stay manual
  (the old repo left `dock.persistent-apps` unset on one host for that
  reason).
- **mise stays** for the account without Nix; nix-darwin does not manage it.

### Effort

Macro for the release that switches a Mac: home-manager takes over
`~/.zshrc`, and nix-darwin takes over system settings and Homebrew's list
(`zap` removes unlisted casks). "To adopt" must name the backup and the
first `darwin-rebuild switch` steps.

### Built

Decided on 2026-10-04: start minimal and port `main`'s `darwin/` one setting
at a time (through task 20261004-222929); build and switch against a Tart VM
first; no Homebrew module yet.

- `flake.nix`: a `nix-darwin` input (master, following nixpkgs), and
  `mkDarwin { user; system ? "aarch64-darwin"; modules ? [ ]; }`. The
  darwin module's nixpkgs gets the same settings as `pkgsFor` (the
  claude-code allowlist and the taskbook overlay), and home-manager runs as
  its module with the same modules as `mkHome` (`homeModules`), with
  `backupFileExtension = "backup"` as `switch -b backup` does on Linux. No
  profile argument yet: profiles are step 1 of the flake parity task.
- `packages.<darwin>.darwin-rebuild`, pinned by the flake, for the first
  switch: `sudo nix run .#darwin-rebuild -- switch --flake .#<name>`.
- `darwin/configuration.nix`: flakes in `nix.settings`, `programs.zsh`, and
  `system.stateVersion = 6`. Nothing else yet.
- `darwinConfigurations.tart`: user `admin`, for a clone of Cirrus Labs'
  macOS base image.

### What a first switch takes

On the VM (Nix from the README's installer, nothing else changed):

1. The first switch stops with "Unexpected files in /etc": `/etc/bashrc`
   and `/etc/zshrc`. `/etc/nix/nix.conf` from the installer is recognised.
   Fix: `sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin`, and the same
   for `/etc/zshrc`.
2. Without a backup extension, home-manager then stops on `~/.zprofile`.
   With it, the file moves to `~/.zprofile.backup`.
3. That `.zprofile` held `eval "$(/opt/homebrew/bin/brew shellenv)"` (and
   rbenv, node, pnpm). After the switch `brew` is no longer on PATH. A
   typical Mac's `~/.zprofile` holds the same line, from Homebrew's
   installer; this Mac's holds OrbStack's init.

## Open questions

- **`~/.zprofile` and Homebrew's PATH.** home-manager's zsh takes over
  `~/.zprofile`, so whatever it held stops running: on most Macs that is
  `brew shellenv`. Options: carry `brew shellenv` in the Nix config (in
  `common.nix` for darwin, or with the Homebrew module), source a
  `~/.zprofile.local` from `profileExtra` and rename the old file to it on
  adoption, or tell adopters to move what they need by hand. Open; the base
  works without Homebrew, but a real Mac will notice.
- **agenix on macOS is all or nothing.** (Settled as harmless here: Alyssa
  is the one recipient on every machine, Answered by Alyssa on 2026-10-05, so one key decrypts
  every secret.) ragenix's launchd agent stops the
  whole generation at the first secret this key can't decrypt, so none
  install (on Linux, `agenix.nix` warns and goes on), and the agent is kept
  alive on failure, so it retries in a loop. With every secret encrypted to
  every recipient, as `secrets.nix` does, that only happens with the wrong
  key; worth knowing when a key is added per machine.
- Admin rights and Homebrew, answered for the real Macs (Answered by Alyssa on 2026-10-05):
  shesfast's admin is `alyssa`, who owns its Homebrew; the work Mac
  (`ditto`) allows nix-darwin, with `alyssaevans` as its user.
- Answers to the other assumptions, for the real Macs: they move to the
  shesfast and ditto tasks.
- `stateVersion` 6 for nix-darwin; nix-darwin on master, not a release
  branch, matching nixpkgs-unstable.
- **Effort**, for the release with this: micro while only a VM host
  exists (nothing changes on a machine that doesn't switch to it). Macro
  for the release that switches a real Mac, whose "To adopt" names the
  `/etc` renames and the `.zprofile` move above.

## Verification

Done, on 2026-10-04:

- In `nixos/nix` (aarch64-linux): `nix flake lock` added only `nix-darwin`
  (`4cff07de`, 2026-08-16); `nix flake check --all-systems --no-build`
  passes, including `darwinConfigurations` and `packages.aarch64-darwin.darwin-rebuild`;
  `darwinConfigurations.tart.system` evaluates; home-manager in it is
  `admin` at `/Users/admin`, with ragenix's launchd agent on and the Linux
  installer off. `homeConfigurations."root@aarch64-linux"` evaluates to the
  same derivation as before the change.
- In a Tart clone of `tahoe-base` (macOS 26.6.2, arm64; Nix 2.35.2 from the
  README's installer), as `admin`: `nix build .#darwinConfigurations.tart.system`
  (62s), then `sudo nix run .#darwin-rebuild -- switch --flake .#tart`,
  through the two stops above, then a clean switch (8s).
- After the switch, from a login zsh: cheat 5.1.0, tb, sem 0.25.0 (its
  OpenSSL patched by `lib/release-binary.nix`), weave, inspect, jj 0.45.1,
  just 1.58.0, hx, gh, claude from `/etc/profiles/per-user/admin/bin`;
  `darwin-rebuild` from `/run/current-system/sw/bin`; `/etc/zshrc` and
  `/etc/bashrc` link to `/etc/static`.
- Secrets, with a throwaway key added to the VM copy's recipients: with
  `example.age` (my key only) present, the agent exits 1 and installs
  nothing; with it moved out, the agent exits 0 and
  `~/.local/share/agenix/check-darwin` is decrypted, mode 0400.

Not done: a real Mac (needs an admin there, and the shesfast or ditto
answers); `brew bundle check` (no Homebrew module yet).
