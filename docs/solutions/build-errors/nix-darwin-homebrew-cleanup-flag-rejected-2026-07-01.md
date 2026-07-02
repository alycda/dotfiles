---
title: "nix-darwin homebrew module cleanup flag rejected by current Homebrew CLI"
date: 2026-07-01
category: build-errors
module: darwin
problem_type: build_error
component: tooling
symptoms:
  - "darwin-rebuild switch fails during homebrew activation: Invalid usage: `brew bundle install --cleanup` requires `--force`, `--force-cleanup` or `$HOMEBREW_ASK`"
  - "flake.lock pins nix-darwin f73cbf1 (2026-06-11), whose homebrew module invokes brew bundle --cleanup --zap without a force flag"
  - "host machine (generation 69, built April) has homebrew.onActivation.autoUpdate = true and would hit the same failure on its next rebuild"
  - "README bootstrap steps were stale: wrong flake ref (.ditto), nix run nix-darwin rate-limited by the GitHub API, missing /etc rename step, nonexistent darwinConfiguration in just _rebuild"
  - "third-party taps (cirruslabs/cli, getditto/build-infra) untrusted under Homebrew's new tap-trust feature; getditto/build-infra also fails over https because the repo is private"
root_cause: config_error
resolution_type: dependency_update
severity: high
tags:
  - nix-darwin
  - homebrew
  - flake-lock
  - bootstrap
  - macos
  - tart-vm
related_components:
  - readme-bootstrap-docs
  - homebrew-tap-trust
  - flake-nix
---

# nix-darwin homebrew module cleanup flag rejected by current Homebrew CLI

## Problem

Bootstrapping the nix-darwin dotfiles on a fresh machine (verified in a clean tart VM, `ghcr.io/cirruslabs/macos-tahoe-base`, macOS 26.5) failed across multiple layers — flake resolution, first-run `/etc` conflicts, Homebrew CLI-flag drift from an aging nix-darwin pin, brew-prefix ownership, private-tap auth, tap trust, and disk sizing — each requiring a distinct fix before `darwin-rebuild switch` completed cleanly.

## Symptoms

In encounter order:

1. `nix run nix-darwin -- switch --flake .#ditto` → HTTP 403 GitHub API rate limit (unauthenticated HEAD resolution of the registry ref).
2. First activation abort: `Unexpected files in /etc` for `/etc/nix/nix.conf`, `/etc/bashrc`, `/etc/zshrc`.
3. Homebrew phase failure: ``Error: Invalid usage: `brew bundle install --cleanup` requires `--force`, `--force-cleanup` or `$HOMEBREW_ASK` `` — **the primary bug**.
4. Brew download failure: `Permission denied @ rb_sysopen - /opt/homebrew/var/homebrew/locks/...`.
5. Private tap failure: `Tapping getditto/build-infra has failed! fatal: could not read Username for 'https://github.com'`.
6. Tap trust failure: `Error: Refusing to load formula cirruslabs/cli/softnet from untrusted tap` (softnet is a dependency of tart).
7. `No space left on device` — default 50GB tart disk too small for the nix store + ~19 casks.
8. Residual, VM-only: `tailscale-app` pkg postinstall fails (system-extension approval unavailable under virtualization); expected to work on hardware.

## What Didn't Work

- `nix flake lock --override-input nix-darwin github:nix-darwin/nix-darwin/<rev>` — **silently no-op'd**. The flake's input is named `darwin` (`inputs.darwin.url = "github:nix-darwin/nix-darwin"`), not `nix-darwin`. `nix flake lock` does not error on an unknown `--override-input` name; it just ignores it, so the rebuild reproduced the original failure with no indication the override was rejected. Diagnose by listing the node names in `flake.lock`, not by inferring the input name from the repo name.
- Passing `--override-input` to `darwin-rebuild switch` on the CLI — the switch re-evaluated from `flake.lock` and used the old pin. Write the override into the lockfile, then build.

## Solution

**Repo changes** (merged as [PR #35](https://github.com/alycda/dotfiles/pull/35)):

- Bump the pinned `darwin` input to a rev whose homebrew module emits the force flag:

  ```bash
  nix flake lock --override-input darwin github:nix-darwin/nix-darwin/a1fa429e945becaf60468600daf649be4ba0350c
  # commit the flake.lock change
  ```

  nix-darwin `f73cbf1` (2026-06-11) emits `brew bundle --cleanup --zap`; `a1fa429` (2026-06-18) emits `--zap --force-cleanup` (module source: `optional (config.cleanup == "zap") "--zap --force-cleanup"`).

- README macOS-setup rewrite: `.ditto` → `.#ditto`; enable flakes after the official installer (`experimental-features = nix-command flakes` + daemon kickstart); replace `nix run nix-darwin -- switch` with the pinned-input bootstrap below; document the `/etc` renames; fix `just _rebuild alyssa@work` → `just _rebuild ditto` (only `ditto` is a darwinConfiguration; `alyssa@*` are Linux homeConfigurations).

**Bootstrap command sequence** (avoids registry HEAD resolution entirely):

```bash
nix build .#darwinConfigurations.ditto.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .#ditto
```

**Per-machine runbook** (machine properties, not repo state — required on each new machine, and partly on the existing host):

1. The flake hardcodes username `alyssaevans` — the user must exist before switching.
2. Rename pre-existing `/etc` files once: `for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do sudo mv "$f" "$f.before-nix-darwin"; done`.
3. Brew prefix must be owned by the configured user (`sudo chown -R alyssaevans /opt/homebrew`) — nix-darwin now runs brew via `sudo --user=<owner>`.
4. Authenticate for the private tap (`getditto/build-infra`): `gh auth login` + credential helper, tap via SSH remote, or pre-tap from a local clone (`brew tap getditto/build-infra /path/to/clone`).
5. Trust third-party taps once: `brew trust cirruslabs/cli getditto/build-infra` — **needed on the existing host too** before its next rebuild.
6. tart VMs: size the disk ≥100GB up front (`tart set <vm> --disk-size 100`; APFS container auto-grows on boot); expect `tailscale-app` to fail in VMs.

## Why This Works

The nix-darwin homebrew module's generated `brew bundle` invocation is a function of the **pinned nix-darwin source**, while the Homebrew CLI accepting that invocation evolves independently — and `homebrew.onActivation.autoUpdate = true` guarantees brew keeps moving even when the pin doesn't. The pin is effectively a contract with Homebrew's current CLI surface: leave it stale long enough and the mismatch will surface as an activation failure. The host machine (stuck at generation 69 since April) carried exactly this latent failure.

Building from the pinned input (`nix build .#darwinConfigurations.ditto.system`) resolves entirely from `flake.lock` via codeload — no unauthenticated GitHub API registry call, no version skew between the bootstrap tool and the config it builds.

Verification included a reproducibility check: after pushing the fix branch and re-switching in the VM, **no new generation was created** — the branch's pinned build produced a store path byte-identical to the pre-tested override build, proving the committed lockfile change is the complete fix rather than a VM-specific workaround.

## Prevention

- Treat the `darwin` input pin as having a shelf life tied to Homebrew's release cadence — run `nix flake update darwin` periodically rather than letting it sit for months. `onActivation.autoUpdate = true` widens the drift window.
- Use a clean tart VM bootstrap as a cheap smoke test before rebuilding real hardware — this run surfaced 8 distinct failures invisible to diff review. (Candidate for CI; see also the pre-existing `feature/tartvm-validate-agents` branch.)
- When overriding a flake input, verify the input's node name in `flake.lock` first — `--override-input <wrong-name>` fails silently and looks identical to "already up to date."
- Keep the per-machine runbook items (tap trust, tap auth, prefix ownership, `/etc` renames) in the README, since they're machine properties no config diff will catch.
- Use the no-new-generation reproducibility check to confirm a committed fix matches the hand-tested build.

## Related Issues

- [PR #35](https://github.com/alycda/dotfiles/pull/35) — the fix (merged 2026-07-02).
- [Issue #29](https://github.com/alycda/dotfiles/issues/29) — one-line install script for self-reprovisioning; its installer should adopt this doc's bootstrap sequence and runbook steps so the two don't drift.
- `docker/CLAUDE.md` (Homebrew bottles dropped for old macOS, PR #34) — different root cause, same pattern family: Homebrew evolving out from under pinned automation.
