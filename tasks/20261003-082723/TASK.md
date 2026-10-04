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

## Open questions

- Answers to the assumptions above.
- Use the old repo's `darwin/` as the starting point, or start minimal and
  add settings one by one?
- `stateVersion` for nix-darwin, and whether to pin nix-darwin to a release
  branch.

## Verification

To do:

- `nix eval` of each `darwinConfigurations.<host>.system` from the devshell.
- `darwin-rebuild build` (no switch) on the target Mac, as its admin.
- After switch: the same tool check as the devcontainer (cheat 5.1.0, tb,
  sem, weave, inspect, jj, just); `brew bundle check`; secrets in
  `~/.local/share/agenix`.

Not possible from the planning account: anything needing the Nix daemon.
