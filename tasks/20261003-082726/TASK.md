# nix-darwin: ditto

- STATUS: OPEN
- TAGS: nix, darwin, host

## Description

`darwinConfigurations.ditto`: the work Mac, on the base from "nix: darwin"
(task 20261003-082723), after "nix(darwin): shesfast" (task
20261003-082724). As in the old dotfiles repo: primary user `alyssaevans`
(`/Users/alyssaevans`), profile `work`, with work system packages and an
authoritative dock (`persistent-apps` set).

Settled by Alyssa on 2026-10-05. The name had two meanings; it is the host.
`/Users/ditto` on Shesfast, the account this repo is worked from, is a
different thing: a non-Nix account that stays on mise, and is in no darwin
configuration (see the shesfast task).

### Define before building

- **Managed device policy**: the work Mac allows nix-darwin (Answered by Alyssa on 2026-10-05),
  which owns `/etc/zshrc`, `/etc/bashrc` and the Nix daemon. Not yet
  confirmed: whether it allows Homebrew, and that `alyssaevans` can run
  `sudo darwin-rebuild` there.
- **Work-only tools, casks and dock**, on top of what every account gets.
  Casks so far: clocker, moved here from shesfast (Alyssa, 2026-10-05); it
  was in main's work list too.
- **Secrets**: settled. Every secret is Alyssa's own, and she is the one
  recipient on every machine (Answered by Alyssa on 2026-10-05), so the work Mac uses the same key
  and gets every secret, as `secrets/secrets.nix` already does. No
  `secrets/work/` split and no per-file recipients. With one key, every
  secret decrypts, so macOS's all-or-nothing install (task 20261003-082723)
  doesn't bite.
- **Profile**: its own, separate `work` profile (Answered by Alyssa on 2026-10-05). Profiles don't
  exist yet: step 1 of the flake parity task (20261003-084608) comes first.

## Open questions

- Is a third Mac planned (the old repo also had a non-admin `code` account
  as a standalone home-manager configuration)?

## Verification

To do, as `alyssaevans` on the work Mac: `sudo darwin-rebuild build --flake
.#ditto`, then `switch` (the first one through the `/etc` renames in the base
task); then the base task's tool check.
