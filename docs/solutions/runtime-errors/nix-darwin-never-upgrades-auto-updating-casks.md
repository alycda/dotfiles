---
title: "GUI apps nag about updates forever: nix-darwin skips every `auto_updates true` cask"
date: 2026-09-03
category: runtime-errors
module: darwin/modules/homebrew.nix
problem_type: config_error
component: tooling
severity: medium
symptoms:
  - "Brew-installed GUI apps (Notion, Obsidian, Arc, Brave, VS Code, Claude, ...) repeatedly notify that an update is available, and the in-app updater either does nothing or fails"
  - "`homebrew.onActivation.upgrade = true` is set, and `darwin-rebuild switch` reports no cask upgrades for those apps"
  - "`brew outdated --cask` lists nothing; `brew outdated --cask --greedy` lists most of the installed apps"
  - "A handful of casks (clocker, chromedriver, codex, font-*, rustdesk) do upgrade normally on switch, which makes it look like cask upgrades work in general"
  - "Nothing changes between switches either: no timer, no launchd job, no brew activity unless darwin-rebuild runs"
root_cause: config_error
resolution_type: config_change
related_components:
  - darwin_configuration
  - development_workflow
tags:
  - homebrew
  - nix-darwin
  - casks
  - auto-updates
  - greedy
  - brew-bundle
  - macos
---

# GUI apps nag about updates forever: nix-darwin skips every `auto_updates true` cask

## Problem

Every GUI app installed through `homebrew.casks` keeps asking to update
itself and never succeeds, while `homebrew.onActivation.upgrade = true`
suggests activation should be handling it. `brew outdated --cask` agrees
with nix-darwin — nothing is outdated — but `brew outdated --cask --greedy`
lists nearly the whole app set.

The confusing part is that upgrades are not *entirely* broken. On ditto,
clocker, chromedriver, codex, the JetBrains nerd font and rustdesk upgrade
on switch exactly as expected. Those five happen to be the casks that do
not declare `auto_updates true`.

## Why it happens

Two independent facts compose into "never".

**nix-darwin runs brew only during activation.** The whole integration is
one activation script (`modules/homebrew.nix`, `system.activationScripts.homebrew`),
which shells out to a single command:

```
PATH=/opt/homebrew/bin:…/mas/bin:$PATH sudo --preserve-env=PATH \
  --user=<homebrew.user> --set-home env \
  brew bundle --file='/nix/store/…-Brewfile' --zap --force-cleanup
```

`onActivation.autoUpdate` controls whether `HOMEBREW_NO_AUTO_UPDATE=1` is
prepended; `onActivation.upgrade` controls whether `--no-upgrade` is
appended. There is no timer and no launchd agent — between `darwin-rebuild
switch` runs, nothing brew-managed moves. (Homebrew's own auto-update fires
on manual `brew` commands after 5 minutes, but that refreshes tap metadata;
it does not upgrade anything.)

**`brew bundle` skips self-updating casks.** Bundle applies the same rules
as `brew upgrade --cask`, whose `--greedy` flag is documented as: "Also
include casks with `version :latest` and `auto_updates true` casks that
would otherwise be skipped." Homebrew's position is that an app declaring
`auto_updates true` manages its own version, so the package manager should
keep its hands off.

Checked against `formulae.brew.sh/api/cask/<token>.json`, that covers 17 of
ditto's 22 casks and 18 of shesfast's 22 — including arc, brave-browser,
claude, chatgpt, notion, obsidian, orbstack, visual-studio-code,
android-studio, parallels, tailscale-app, dropbox, google-drive, the proton
apps, warp and zoom.

So the actual contract was: brew installs the app once, then hands version
management to the app. The nag loop is that handoff failing on the app's
side, with nothing behind it to catch the failure.

Why the app can't self-update is a separate, ordinary macOS permissions
question, and worth checking on the machine:

```bash
ls -lde /Applications/Notion.app   # owner + ACLs
ls -ld /Applications               # root:admin drwxrwxr-x — the swap needs admin
xattr -p com.apple.quarantine /Applications/Notion.app
```

nix-darwin installs casks as `homebrew.user`, which defaults to
`system.primaryUser`. A second account on the machine therefore owns none of
the bundles, and a non-admin account cannot perform the atomic
`/Applications` replacement Sparkle and Squirrel rely on — the same
multi-account asymmetry as
`zsh-compinit-prompts-every-non-admin-login.md`.

## Fix

Make brew the updater for those casks rather than trusting the app, in both
homebrew modules:

```nix
# darwin/modules/homebrew.nix and homebrew-personal.nix
homebrew = {
  greedyCasks = true;    # `greedy: true` on every cask line
  global.brewfile = true; # export HOMEBREW_BUNDLE_FILE
};
```

`greedyCasks` sets the per-cask `greedy` default, so every Brewfile line
becomes `cask "notion", greedy: true` and activation upgrades them.

`global.brewfile` points `HOMEBREW_BUNDLE_FILE` at the generated Brewfile so
`brew bundle install` can be run on demand, which is what `just brew-upgrade`
does — greedyCasks fixes *what* activation upgrades, not *when*, and the
recipe covers the gap between switches without a launchd agent upgrading GUI
apps unattended. It omits `--zap --force-cleanup` on purpose: it upgrades,
it does not reconcile, so it cannot uninstall anything.

## Costs, both real

**Reinstalls on the first greedy switch.** Homebrew compares the version it
*recorded at install time* against the cask's version, not the version in
the app bundle. An app that self-updated past what homebrew-cask has indexed
is therefore "outdated" from brew's point of view and gets reinstalled at the
cask's version — a transient downgrade. It settles after one pass and stays
settled until upstream moves again.

**`version :latest` casks would churn.** Greedy covers those too, and they
have no version to compare, so they reinstall on *every* run. Neither module
lists one today (verified across all 31 distinct tokens), which is the only
reason this is free — worth re-checking when adding a cask. Per-cask
`greedy = true` is the escape hatch if one shows up.

## Verifying

```bash
# before: nothing outdated, but greedy disagrees
brew outdated --cask
brew outdated --cask --greedy

# the generated Brewfile should now carry greedy on cask lines
grep -m3 '^cask' "$HOMEBREW_BUNDLE_FILE"

# does an app self-update flag exist for a given cask?
curl -s https://formulae.brew.sh/api/cask/notion.json | jq '.auto_updates, .version'
```

## Lesson

A package manager option named `upgrade` can be true and still be
upgrading almost nothing, because the *package* opted out. When a declared
setting appears to have no effect, check whether the packages themselves
carry an opt-out flag before assuming the setting is misconfigured — and
check what fraction, since a small group of unflagged packages upgrading
normally is exactly what disguises the problem.
