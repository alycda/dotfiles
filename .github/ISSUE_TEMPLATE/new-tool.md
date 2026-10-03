---
name: New tool
about: Add a tool to the environment (CLI, GUI app, agent skill, language tooling)
title: "Add <tool>"
labels: ["new-tool"]
---

## what

<!--
Name, one-line description, upstream URL, and the version/rev you'd pin.
The binary name(s) it puts on PATH, if they differ from the project name
(`verify` needs the real one, and upstream docs sometimes use another).
Say what kind of thing it is: CLI, GUI app, agent skill, plugin, language
toolchain.
-->

## why

<!--
The problem it solves that nothing already installed covers. Name the
closest existing tool and why it doesn't do the job. Link the PR/issue/
incident that surfaced the need, if any.
-->

## how

<!--
Placement, in order of preference (CLAUDE.md "Adding a New Development Tool"):
  lib/core-packages.nix  universal, lightweight CLI (also feeds devShells + the headless container)
  profile `packages`     one-off; desktop profiles for anything heavy or GUI
  modules/<area>/        only when there is real config to own
  darwin homebrew cask   macOS apps; required for dock-pinned apps

Source, checked rather than assumed:
  nixpkgs attr + version at three points: the locked rev, nixos-unstable head, master
    (or "not in nixpkgs"). The comparison picks the fix:
      locked behind, unstable/master current -> stale lock; `nix flake update`, no pin-forward
      unstable and master behind too         -> nixpkgs is the laggard; vendor input or pin-forward
  fallback: vendor flake input / homebrew / npm importNpmLock / installer script

Constraints to confirm:
  [ ] headless-safe: no GUI closure, no `mkOutOfStoreSymlink` to ~/dotfiles, no credential prompt reachable without a TTY (common.nix and core-packages reach the devcontainer)
  [ ] runtime-mutable state stays unmanaged
  [ ] collision risk with the nixos/nix base image profile
  [ ] network calls at startup or exit (update checks, telemetry): default state, and how to turn them off
-->

## verify

<!--
Runnable commands that prove the end state, one per line. "switch exited 0"
is not evidence: it doesn't show a binary landed or is on the login PATH.

Baseline for an installed binary:
  zsh -lc 'command -v <binary> && <binary> --version'
  just ci

Add tool-specific checks where they exist, e.g. a behavioral smoke test of
the thing you packaged (a headless guard exits non-zero with no TTY and no
token; a wrapper sets the env var it claims to). Upstream's own test suite
rarely applies here; test what this repo wires up.

Not a binary? Substitute the equivalent: for an agent skill, SKILL.md `name`
matches its deploy directory and the description is <= 1024 bytes.

Can't run it where you are (no nix, no macOS)? Say so and list what is
unverified, rather than leaving it blank.
-->
