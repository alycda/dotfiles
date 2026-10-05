# nix-darwin: the shesfast host

- STATUS: OPEN
- TAGS: nix, darwin, host

## Description

`darwinConfigurations.shesfast`, on the base from "nix: darwin" (task
20261003-082723). In the old dotfiles repo, dock left as it is (`persistent-apps`
unset, so nix-darwin doesn't replace it).

### Define before building

- **Primary user** (`system.primaryUser`, `users.users.<name>`):
- **Other accounts on this Mac**: home-manager for them too (as darwin
  `home-manager.users.<name>`), or do they stay on mise? An account without
  daemon access can't use Nix at all until it is allowed
  (`nix.settings.allowed-users` / `trusted-users`).
- **Tools and apps**: which casks (Homebrew) and which system packages, on
  top of the home-manager tools every account gets.
- **System defaults** that differ from the base (dock, hot corners, keyboard).
- **Profile name**: keep `home`, or name it after what it is.

### Parity with main

[audit/AUDIT.md](audit/AUDIT.md) lists what main gives it, by category, CLI first:
the work to do before the switch.

## Open questions

- **macOS 26.** Second Clock, from the App Store, needs 26; until then its
  `masApps` entry can't install. Upgrade before the first switch to this
  configuration, or expect that one entry to fail.
- ~~Does Homebrew on this Mac belong to the primary user?~~ Yes

## Verification

The audit, on 2026-10-04: [audit/audit.nix](audit/audit.nix) evaluated in
the Tart VM against main's `darwinConfigurations.shesfast` and effver's
`darwinConfigurations.tart`; the results are the two JSON files beside it.

To do, as the primary user : `darwin-rebuild build --flake .#shesfast`, then
`switch`; then the tool check from the base task, for each managed account.
