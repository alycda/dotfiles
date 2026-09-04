---
title: "Dev-container image drift: uncommitted local state baked into the image regressed silently on restart"
date: 2026-08-03
category: runtime-errors
module: docker-dev-image
problem_type: runtime_error
component: tooling
symptoms:
  - "~/.claude/CLAUDE.md lost its managed agent-import block after a same-image container restart"
  - "fatal: could not read Username for 'https://github.com': No such device or address"
  - "An agent behavioral rule silently stopped loading, with no error or warning at container start"
  - "Runtime state inside the container could not be traced to any committed dotfiles source"
root_cause: config_error
resolution_type: config_change
severity: high
related_components: [development_workflow, documentation]
tags: [docker, nix-home-manager, dev-container, entrypoint, image-drift, claude-md, git-credentials, container-restart]
---

# Dev-container image drift: uncommitted local state baked into the image regressed silently on restart

> **Status: resolved.** Written 2026-08-03 while the bugs were live; the fixes
> landed within days. Kept because the *shape* recurs — and because the fix that
> landed for instance 1 is materially better than the one proposed here, which
> is the more useful lesson. Line references below are against `main` as of
> 2026-09-04. See "How it was actually fixed".

## Problem

The `dev` image bakes two artifacts at build time: the dotfiles flake source at
`/opt/dotfiles`, and a prebuilt home-manager generation at `/opt/hm-activation`.
`docker/entrypoint.sh` treated them with two different update policies, and the
mismatch was the bug:

- It refreshed `~/.claude/CLAUDE.md` from the baked flake source
  **unconditionally** on every start, with a `cp -f` near the top of the script.
- It ran home-manager activation **only** when the baked generation differed
  from the one the `devhome` volume was last activated with — the gate now at
  `docker/entrypoint.sh:24`.

Home-manager activation is what wrote Claude's import lines into
`~/.claude/CLAUDE.md`. So on any restart against the **same** image: the
unconditional `cp -f` clobbered the imports, the activation gate saw
`$CURRENT == $BAKED` and skipped, and nothing restored them. The agent
instruction layers silently stopped loading until the next image upgrade or
volume reset.

The bug shape is worth naming on its own: **an unconditional overwrite paired
with conditional restoration.** Any content that exists only via the conditional
path is destroyed on every same-image restart.

The deeper problem, of which this was one of three instances found in a single
session: **the image had been built from a dirty working copy, so it was not a
faithful build artifact of committed source.** It carried state that existed in
no commit (a git credential helper), and lacked state that existed only
hand-applied in the volume (the import lines).

## Symptoms

- **Instance 1 — imports wiped.** After a restart with an unchanged image,
  `~/.claude/CLAUDE.md` no longer carried its agent-overlay import lines. No
  error anywhere; Claude Code simply stopped loading those layers. The
  regression was invisible until behavior that depended on a layer failed to
  appear.
- **Instance 2 — push auth broken.** After restart, `git push` failed with
  `fatal: could not read Username for 'https://github.com': No such device or
  address`. The gh credential helper was visible in the store-managed
  `~/.config/git/config` inside the image, but a grep of committed source found
  it nowhere. It had ridden into the image from uncommitted local working-copy
  config at build time.
- **Instance 3 — dangling symlinks after ad-hoc activation.** Home-manager
  generations activated by hand *inside* a running container land in the
  ephemeral overlay portion of `/nix` and vanish on restart, leaving
  `~/.config` symlinks dangling until the entrypoint re-activates the baked
  generation. Observed while validating PR #21 in-container. This is the
  designed rollback behavior, but it reads as breakage if you don't know it.

## What Didn't Work

**Syncing in the wrong direction.** The first fix attempt for instance 1 also
rewrote the repo's `docker/CLAUDE-arm64.md` prose to match the copy baked into
the image, on the assumption that the image carried newer local edits. Checking
timestamps disproved it: `git show -s --format=%ci` on the repo commit showed
03:18 that morning, while the image had been built around 02:48 — the **image**
was the stale side. The "sync" would have silently reverted a deliberate
rewording. Lesson: a running image is a snapshot from build time; before
adopting its content into the repo, prove which side is newer.

**Re-running `gh auth setup-git` by hand** after each restart worked for
instance 2, but it is exactly the kind of hand-applied volume state this bug
family is made of.

## What was proposed, and why it was the weaker fix

The fix first proposed here — and shipped in PR #61 — was to bake the import
lines into the source documents the entrypoint copied from, so that the
unconditional `cp -f` itself carried them. The activation appends were
idempotent (`grep -qxF` before append), so the two mechanisms composed without
duplication.

That works, but it leaves the unconditional overwrite in place and makes every
future consumer of those files responsible for keeping the two copies in sync.
It treats the symptom.

## How it was actually fixed

**Instance 1 — the copy was deleted, not made correct.** The container doc is
now a home-manager file: `home-manager/profiles/dev.nix:34` writes the
per-arch `docker/CLAUDE*.md` to `~/.claude/rules/container-env.md`, and Claude
Code discovers `~/.claude/rules/` on its own with no import line. The entrypoint
touches `~/.claude/CLAUDE.md` no longer; `docker/entrypoint.sh:9-22` is now a
comment recording why. Owning the file through the generation removes the copy,
the volume-shadowing problem the copy existed to solve, *and* the clobber it
caused — three things for one deletion, where PR #61 fixed one of them.

The append mechanism went the same way. `agents.nix` no longer appends: it
rewrites a marked managed block in place (`agents.nix:32`, `:52`, `:184`),
which is what let it express layer precedence, and its prune list strips the
legacy bare imports from existing files (`agents.nix:93`). The
outbound-comment-gate append is gone entirely — user-level rules in
`~/.claude/rules/` load without an import, so the appended line was loading the
same file twice (`claude-code.nix:64`).

**Instance 2 — the helper is committed.** `home-manager/modules/git.nix:68-69`
now declares both `credential."https://github.com".helper` and the gist
equivalent, pointing at `gh auth git-credential`. Issue #64 remains open on
GitHub despite being fixed in fact.

**Instance 3 — no code change.** Behavior is by design. The fix was
understanding it: in-container `home-manager switch` results are validation
only, and the entrypoint restores the baked generation on restart.

## Why This Works

The general principle: **a derived artifact should be reproducible from
committed source, and a start-up script should not be the thing that reconciles
them.** Both live fixes moved a piece of state from "reconciled at container
start" to "owned by the generation":

- The container doc used to be copied by the Dockerfile *and* again by the
  entrypoint, to beat the `claude-home` volume shadowing the baked copy. As a
  home-manager file it arrives with the generation and updates when the
  generation does, so there is nothing to shadow and nothing to overwrite.
- The credential helper used to exist only in a build machine's working copy.
  Committed, it is reproduced deterministically by every image build, and a
  volume reset can no longer lose it.

Both dissolve the conditional-restoration half of the bug shape rather than
strengthening it.

## Prevention

- **Bake-or-append invariant:** anything an entrypoint unconditionally
  overwrites must either carry its full desired content from committed source,
  or the restore logic must also run unconditionally. Never mix an
  unconditional overwrite with conditional restoration. Better still, as here:
  delete the overwrite and let the generation own the file.
- **Prefer deleting the reconciliation to fixing it.** When a start-up script
  copies state into place, ask what it is defending against. Twice here the
  answer was a problem that vanished once the generation owned the file.
- **Build images from clean working copies.** The image is a build artifact,
  not a source of truth. A dirty build both smuggles in uncommitted state and
  freezes out later commits.
- **Grep committed source for any config observed at runtime before relying on
  it.** That is exactly how the credential helper was caught: visible in the
  running container, absent from the repo. Either commit it or file it — never
  adopt it blind.
- **Check direction before syncing repo content to a running artifact.**
  Compare `git show -s --format=%ci` on the relevant commit against the image
  build time. Whichever is older is the stale side.
- **Treat in-container `home-manager switch` as ephemeral validation.** The
  overlay `/nix` discards it on restart; only generations baked into the image
  persist.
- **A doc that cites line numbers goes stale in days.** This one asserted four
  present-tense facts about `main` that were false within 92 seconds of being
  written, because PR #61 merged. Cite the mechanism and the file; date the
  claim; re-verify before trusting it.

## Related Issues

- **PR #61** (merged 2026-08-03) — baked the import lines into
  `docker/CLAUDE.md` and `docker/CLAUDE-arm64.md`. The proposed fix for
  instance 1; superseded by moving the doc into the generation.
- **Issue #64** (open) — commit the gh credential helper. Fixed in fact by
  `home-manager/modules/git.nix:68-69`; the issue can be closed.
- **PR #135** (open) — makes `.devcontainer.json` invoke
  `/opt/dotfiles/docker/entrypoint.sh` from `postStartCommand`, so the
  entrypoint becomes the VS Code Dev Containers path as well as the terminal
  one. Harmless now that the unconditional copy is gone, and the reason the
  bake-or-append invariant is worth keeping: a reintroduced overwrite would
  fire in two front doors.
- **PR #21** (merged) — the fzf/television exploration; validating it locally
  in-container is where the ephemeral-overlay behavior (instance 3) surfaced.
- **PR #34** (merged) — historical precedent: earlier volume-vs-image state
  fixes on the x86 dev image.
- **Issue #40** (closed) / **PR #41** (merged) — the agent-instruction
  distribution design the wiped import lines belong to.
