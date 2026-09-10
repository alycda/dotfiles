---
title: "The dev image pins the flake at build time, so `dev.sh run` can serve a stale claude-code indefinitely"
date: 2026-09-10
category: runtime-errors
module: docker-dev-image
problem_type: runtime_error
component: tooling
severity: medium
symptoms:
  - "`claude --version` reports an old version (2.1.260) days after the upstream bump (2.1.266) merged"
  - "The open flake-update PR visibly contains the newer pin, yet the container built 'from that PR' does not"
  - "Nothing errors: no warning at container start, no drift message, no cache miss - the environment simply is what it was"
  - "Restarting the container changes nothing, because restarting is not rebuilding"
  - "`dev.sh build-local` from a stale feature branch moves the version backwards rather than forwards"
root_cause: by_design
resolution_type: process_change
related_components:
  - development_workflow
  - documentation
tags:
  - docker
  - dev-container
  - flake-lock
  - claude-code
  - version-drift
  - reproducibility
  - force-push
  - automation
---

# The dev image pins the flake at build time, so `dev.sh run` can serve a stale claude-code indefinitely

## Problem

`claude --version` inside the container reported **2.1.260** on 2026-09-09,
five days after `sadjow/claude-code-nix` merged **2.1.266** (PR #413, merged
2026-09-09T00:03:58Z). The expectation was that starting the container picked
up the newer pin, since the open lockfile-update PR
([alycda/dotfiles#139](https://github.com/alycda/dotfiles/pull/139)) plainly
contained it.

Nothing was broken. Everything was behaving exactly as designed, which is the
entire difficulty: there is no error to search for, and the mental model that
produces the surprise is never contradicted by anything the system prints.

## Why it happens

Three separate facts stack up. Each is individually documented; the
combination is not.

**1. The image is a snapshot, and `run` never refreshes it.**
`Dockerfile` bakes the home-manager closure into the image at *build* time -
that is the point of the design (see its header: network and CPU happen once,
at build, so activation at container start can be fast and offline). The
consequence rarely stated alongside it: every input the flake pins, including
`claude-code-nix`, is frozen at that instant. `docker/dev.sh run` starts a
fresh container from an existing image. It reads no lockfile, contacts no
registry, and cannot possibly produce a newer `claude`. Only `build`,
`build-local` and `up` can.

Verified on the affected container:

```
$ readlink -f "$(command -v claude)"
/nix/store/f91y9db…-claude-code-2.1.260/bin/claude

$ jq -r '.nodes["claude-code-nix"].locked | "\(.rev[0:12])  \(.lastModified|todate)"' \
    /opt/dotfiles/flake.lock
cf835bf360e6  2026-09-04T00:03:38Z          # = "update claude-code to version 2.1.260 (#406)"
```

The binary matched the lock exactly. There was no drift to fix - the image was
a faithful build of a five-day-old commit.

**2. "Restart" and "resume" are not "rebuild", and the volumes make that hard
to feel.** Every container is `--rm`, but `devhome` and `claude-home` persist
the nix profile, jj/ssh state and Claude auth. A new container therefore feels
like a resumed machine: same shell, same history, still logged in. Nothing in
that experience suggests the toolchain is a five-day-old artifact, so the
question "should I rebuild?" never arises.

**3. A branch-pinned build is not reproducible, because
`automation/flake-update` is force-pushed.** `dev.sh build <ref>` hands the ref
to BuildKit's remote build context, which resolves it *at build time*. The
flake-update workflow force-pushes its branch on every run, superseding the
open PR in place (documented in `CLAUDE.md` under "Flake input updates" - it
is deliberate, and it is what keeps update PRs from piling up as review debt).

So "I built the image from PR #139" does not identify a lockfile. It names a
moving target. Concretely:

| | pinned `claude-code-nix` | version |
|---|---|---|
| PR #139 head at build time (~2026-09-04 01:35) | `cf835bf3` | 2.1.260 |
| PR #139 head when the surprise surfaced (pushed 2026-09-09T11:57:12Z) | `99c17539` | 2.1.266 |

Same PR, same branch name, same URL, different lockfile. Reading the PR on
GitHub after the fact shows the *newer* pin and makes the image look wrong.
The image was not wrong; the branch had moved under it.

**A fourth, lying in wait.** The local checkout at `/work/alycda/dotfiles` was
on an unrelated feature branch (`pr82-rebase`) whose lockfile pinned
`610372fe` = **2.1.251**. Reaching for `dev.sh build-local` as the "surely this
rebuilds properly" escape hatch would have gone *backwards* by nine releases,
while looking like the more thorough option.

## Diagnosis

The image carries its own source at `/opt/dotfiles`, so it can always be asked
what it pinned. Two commands, from inside the container, settle it:

```sh
# what is actually running
readlink -f "$(command -v claude)"

# what this image's baked lockfile pinned, and when
jq -r '.nodes["claude-code-nix"].locked | "\(.rev[0:12])  \(.lastModified|todate)"' \
  /opt/dotfiles/flake.lock
```

If those two agree, the image is healthy and simply old — the answer is a
rebuild, not a repair. If they *disagree*, that is a different bug entirely
(image drift from a dirty build: see
`dev-container-image-drift-silent-restart-regressions.md`).

Note `/opt/dotfiles` is the image's baked copy, not the bind-mounted checkout
at `/work` — that distinction is the whole reason this diagnostic works, and
the reason it must not be run against `/work/**/flake.lock`.

## Fix

Rebuild against a ref that actually carries the newer pin:

```sh
./docker/dev.sh up automation/flake-update    # or `just docker-up automation/flake-update`
```

Verified afterwards, on 2026-09-10:

```
$ claude --version
2.1.266 (Claude Code)
$ jq -r '.nodes["claude-code-nix"].locked.rev' /opt/dotfiles/flake.lock
99c17539032f5db9c4429aa683d3b16b1874dbce
```

Once the update PR merges, plain `dev.sh build` (default branch) is enough.
Keep the `devhome` volume either way — the entrypoint re-activates when the
baked generation differs from the volume's, which is exactly this case.

## Prevention

- **`dev.sh help` is the cheatsheet, and it leads with "does this rebuild?"**
  It is reachable with nothing checked out:
  `curl -fsSL .../docker/dev.sh | sh -s -- help`. The justfile's `docker-*`
  recipes mirror its subcommands 1:1 and repeat the REBUILDS/no-rebuild
  annotation in `just --list`, so the answer is in front of you at the moment
  of choosing rather than in a doc you would have to know to open.
- **Ask the image what it pinned before theorising.** The two-command
  diagnostic above distinguishes "old but faithful" from "drifted", which are
  opposite problems with opposite fixes. Doing it first would have replaced
  five days of assuming with about ten seconds.
- **A ref is not a version.** Any build pinned to `automation/flake-update`
  identifies a branch, not a lockfile, and that branch is force-pushed weekly.
  If it matters which lockfile an image carries, record the commit
  (`git rev-parse` it, or read the baked `flake.lock` back out afterwards) —
  the PR URL will not tell you later.
- **Before `build-local`, check what the checkout pins.** It builds the branch
  you happen to be standing on, which is frequently not `main` and can be
  arbitrarily far behind it. `build`/`up` go to GitHub and are the safer
  default; `build-local` is for when the point is your uncommitted edits.
- **Prefer the fast-updating pin's own PR over waiting for the weekly cron.**
  `claude-code-nix` ships hourly and the flake-update cron is weekly, so the
  steady state is a CLI several days stale. `up <ref>` against the open update
  PR is the documented way to jump the queue — that is why the recipes take an
  optional `[ref]`.

## Lesson

The generalisation of "a running image is a snapshot from build time" (already
the lesson of the image-drift write-up) is that **every dependency the image
pins inherits the image's age, including the ones that update hourly.** A
persistent-feeling environment built from an immutable artifact will silently
serve yesterday's toolchain forever, and it will never say so — because from
its own point of view nothing is wrong.

Where that is undesirable, the countermeasure is not a smarter start-up script
reconciling versions at runtime (the failure mode catalogued next door); it is
making "does this command rebuild?" impossible to get wrong at the point of
invocation.

## Related

- `curl-piped-dev-sh-cannot-attach-stdin-to-tty.md` — the other `dev.sh`
  gotcha, and why the curl bootstrap is the shape it is.
- `dev-container-image-drift-silent-restart-regressions.md` — the *opposite*
  failure: an image that does not faithfully reflect committed source. The
  diagnostic above tells the two apart.
- `CLAUDE.md`, "Flake input updates: `update-flake-lock.yml`" — why the
  automation branch is force-pushed and supersedes its own PR.
- `CLAUDE.md`, "Tools Nix Can't Fully Manage" — why `claude-code` is pinned to
  `sadjow/claude-code-nix` rather than nixpkgs in the first place, and the
  earlier version-skew failure (PR #26) that motivated it.
- [alycda/dotfiles#139](https://github.com/alycda/dotfiles/pull/139) — the
  lockfile-update PR whose moving head prompted this write-up.
