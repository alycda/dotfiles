# nix-darwin: the shesfast host

- STATUS: OPEN
- TAGS: nix, darwin, host

## Description

`darwinConfigurations.shesfast`, on the base from "nix: darwin" (task
20261003-082723). In the old dotfiles repo, shesfast was the home Mac:
primary user `alyssa`, profile `home`, dock left as it is
(`persistent-apps` unset, so nix-darwin doesn't replace it).

This repo was planned from the Mac named Shesfast, as the user `ditto`
(uid 506, not in the Nix daemon's group). So the old assumptions may not hold;
define them here before building.

### Define before building

- **Primary user** (`system.primaryUser`, `users.users.<name>`): `alyssa`,
  as before: the admin who runs `darwin-rebuild`. Answered by Alyssa on 2026-10-05.
- **Other accounts on this Mac**: home-manager for them too (as darwin
  `home-manager.users.<name>`), or do they stay on mise? An account without
  daemon access can't use Nix at all until it is allowed
  (`nix.settings.allowed-users` / `trusted-users`). Answered for `ditto`
  (below): it stays a mise account, so it needs no daemon access.
- **Tools and apps**: which casks (Homebrew) and which system packages, on
  top of the home-manager tools every account gets.
- **System defaults** that differ from the base (dock, hot corners, keyboard).
- **Profile name**: keep `home`, or name it after what it is.

## Open questions

- **macOS 26.** Shesfast runs 15.7.4 and will be upgraded to 26 (Alyssa,
  2026-10-05). Second Clock, from the App Store, needs 26; until then its
  `masApps` entry can't install. Upgrade before the first switch to this
  configuration, or expect that one entry to fail.
- **The Mac mini on its way**, not yet named, on macOS 26 (or upgraded to it
  at once). Plan (Alyssa, 2026-10-05): test the Nix setup on it and reformat
  it once satisfied, either as a darwin configuration of its own beside
  shesfast's or by reusing shesfast's; decided later. Until it arrives, the
  Tart VM is where a switch is tried.

- ~~Is `ditto` (this account) meant to be managed here, or is it the subject of
  "nix(darwin): ditto"?~~ Neither. Answered by Alyssa on 2026-10-05: the
  `ditto` host is the work Mac (user `alyssaevans`, task 20261003-082726).
  `/Users/ditto` on Shesfast is a separate, non-Nix account: it stays on
  mise and is not part of this configuration.
- ~~Does Homebrew on this Mac belong to the primary user?~~ Yes: `alyssa`
  owns it. Answered by Alyssa on 2026-10-05.

## Verification

To do, as the primary user on Shesfast: `darwin-rebuild build --flake
.#shesfast`, then `switch`; then the tool check from the base task, for each
managed account.
