---
title: "agenix secrets silently never install in the container: ragenix mounts them from a systemd user service"
date: 2026-08-05
category: config-errors
module: home-manager/modules/agenix-activation.nix
problem_type: config_error
component: tooling
severity: high
symptoms:
  - "`home-manager switch` reports success, the generation links, and no error mentions agenix at all - but a declared `age.secrets` file is simply not on disk"
  - "~/.agents/instructions.private.md missing despite `age.secrets.agent-instructions` declaring exactly that path, leaving ~/.claude/includes/agents-instructions.private.md a dangling symlink"
  - "`@includes/agents-instructions.private.md` in ~/.claude/CLAUDE.md is a dead import, so agents read the file every session and silently never receive the private overlay"
  - "switch output contains 'User systemd daemon not running. Skipping reload.' - the only visible hint, and it looks unrelated"
  - "`config.home.activation` contains no agenix entry; `config.systemd.user.services` contains exactly one, named agenix"
  - "`nix-store -r <agenix-home-manager-mount-secrets>` fails with 'no substituter that can build it' - the mount script is not even in the container's closure"
root_cause: environment_mismatch
resolution_type: config_change
related_components:
  - secrets_management
  - development_workflow
tags:
  - nix
  - home-manager
  - agenix
  - ragenix
  - docker
  - devcontainer
  - systemd
  - silent-failure
---

# agenix secrets silently never install in the container

## Symptom

A secret declared in `age.secrets` is not on disk. Nothing fails: `home-manager
switch` exits 0, the generation links, dotfiles appear, and no error anywhere
mentions agenix.

The only evidence is absence. `~/.agents/instructions.private.md` was declared
with a `path` override and never existed, which made
`~/.claude/includes/agents-instructions.private.md` a dangling symlink and the
`@includes/agents-instructions.private.md` line in `~/.claude/CLAUDE.md` a dead
import. Every agent session read that CLAUDE.md and quietly got no private
overlay. This went unnoticed for months because a missing include renders
identically to an empty one.

## Root cause

ragenix's home-manager module does not install secrets from the activation
script. It installs them from a **systemd user service**:

```
config.home.activation       -> [ ... ensureAgenixSecretsDirParent ... ]   # no agenix
config.systemd.user.services -> [ "agenix" ]                               # ExecStart:
                                                                           # agenix-home-manager-mount-secrets
```

The dev container has no user systemd daemon. `home-manager switch` says so, in
a line that reads like boilerplate:

```
Activating reloadSystemd
User systemd daemon not running. Skipping reload.
```

So the unit is written to `~/.config/systemd/user/agenix.service`, never runs,
and every `age.secrets` entry silently never arrives. The mount script is not
even realised into the store - nothing in the activation closure references it,
so `nix-store -r` on it fails with *"no substituter that can build it"*. That
last check is the fastest confirmation.

Secrets that *are* present on such a container are leftovers - placed by hand,
by `docker cp`, or by an earlier context - not products of activation. Check
their mtimes against the last switch before concluding anything works.

## Fix

`home-manager/modules/agenix-activation.nix` re-implements the install as an
activation step: decrypt each declared secret with `age -d -i <identity>` into
`<secretsDir>/<name>`, chmod it, and symlink any `path` override at it.

Two decisions inside it are load-bearing:

- **The canonical location stays `<secretsDir>/<name>` even when `path` is
  overridden.** Consumers hardcode that default - the cloudflare `headersHelper`
  reads `~/.local/share/agenix/cloudflare-api-token` by name - so a `path`
  override becomes a symlink to the canonical file rather than a second copy of
  the plaintext.
- **It never aborts activation.** A failed decrypt warns and returns 0.
  home-manager runs activation steps in order, so dying here would skip
  `installPackages` - the exact failure shape that left a container with working
  dotfiles and no `claude`, `jj`, or `rg` (see
  `build-errors/home-manager-bash-collides-with-base-image-profile.md`). A loud
  warning is the fix for silence; a hard failure trades one broken container for
  another.

The decrypt also bails out early under `DRY_RUN`. It cannot go through the `run`
wrapper, because it needs its own exit status to decide whether to warn and
`run` returns 0 unconditionally in a dry run - without the guard, `switch -n`
would really decrypt and leave `.tmp` files behind.

## Scope

Imported by `home-manager/profiles/dev.nix` only, which backs `alyssa@dev` and
`alyssa@dev-x86`. Darwin installs secrets through `ragenix.darwinModules` and
must not get a second installer racing it.

The rejected alternative was one shared module that probes whether systemd is
usable. That puts the machine you cannot test from here in charge of choosing a
code path, and a wrong probe reproduces exactly the silent failure this fixes.

**`alyssa@work-dev` is not covered.** It is a Linux container too, but
`profiles/work.nix` is shared with darwin, so it needs the same decision made
for it deliberately rather than inherited by accident.

## Verifying

```bash
# Does anything install secrets at activation time?
nix eval .#homeConfigurations.'"alyssa@dev"'.config.home.activation --apply builtins.attrNames

# Dry run: lists every secret and its destination, with no side effects
home-manager switch -n --flake '.#alyssa@dev' 2>&1 | grep 'would install agenix'

# After a real switch, the file exists rather than the symlink dangling
readlink -f ~/.claude/includes/agents-instructions.private.md && \
  test -r ~/.agents/instructions.private.md && echo present
```
