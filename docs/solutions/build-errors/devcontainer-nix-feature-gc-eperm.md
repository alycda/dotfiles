---
title: "The devcontainer nix feature garbage-collects on every install, and that GC dies with EPERM on Docker Desktop for Mac"
date: 2026-08-05
category: build-errors
module: .devcontainer.json
problem_type: build_error
component: tooling
severity: high
symptoms:
  - "\"Reopen in Container\" fails at the very END of the nix feature install, AFTER the installer has printed 'Alright! We're done!' — so Nix itself installed fine"
  - "error: read of 65536 bytes: Operation not permitted, immediately after 'finding garbage collector roots...' and 'removing stale link from ...'"
  - "'0 store paths deleted, 0.0 KiB freed' on the line before the failure — the GC that kills the build had nothing to collect"
  - "ERROR: Feature \"Nix Package Manager\" (ghcr.io/devcontainers/features/nix) failed to install!"
  - "An unchanged .devcontainer.json that worked for months; a minimal copy with no customizations key fails identically; the same config fails in other repos too"
root_cause: external_dependency
resolution_type: config_change
related_components:
  - development_workflow
  - documentation
tags:
  - devcontainer
  - nix
  - vscode
  - docker
  - docker-desktop
  - macos
  - garbage-collection
  - upstream-bug
---

# The nix feature's post-install GC dies with EPERM on Docker Desktop for Mac

## Problem

The devcontainer build fails inside `ghcr.io/devcontainers/features/nix`, but
*after* Nix has installed successfully:

```
Alright! We're done!
...
(*) Executing post-installation steps...
removing old generations of profile /nix/var/nix/profiles/per-user/root/profile
finding garbage collector roots...
removing stale link from "/nix/var/nix/gcroots/auto/lzjb..." to "...profile-1-link"
error: read of 65536 bytes: Operation not permitted
0 store paths deleted, 0.0 KiB freed
ERROR: Feature "Nix Package Manager" (ghcr.io/devcontainers/features/nix) failed to install!
```

The config is unchanged and worked for months. Stripping it to a minimal copy
changes nothing, and it reproduces across unrelated repos that share the
config.

## Root cause

The feature's `post-install-steps.sh` ends with two lines, under `set -e`:

```sh
nix-collect-garbage --delete-old
nix-store --optimise
```

On a fresh install this is pure ceremony — note `0 store paths deleted`,
because nothing is garbage yet. But Nix's collector calls `findRuntimeRoots()`,
which scans `/proc/<pid>/maps` and `/proc/<pid>/environ` for store paths held
by live processes. Nix skips a process when those reads fail with `ENOENT`,
`EACCES` or `ESRCH` — but **not** `EPERM`, which propagates and aborts the run.

Under Docker Desktop for Mac's Linux VM, those `/proc` reads return `EPERM`
inside a BuildKit build container. So a no-op cleanup step fails, `set -e`
turns that into a non-zero exit, the feature reports failure, and the whole
image build dies — at the last instruction, after everything that mattered
already succeeded. That ordering is what makes it so confusing to read.

There is **no feature option to skip the GC**, and **pinning does not help**:
every published version of the feature back to 1.1.3 carries the same two
lines (verified by pulling each version's tarball from ghcr.io). Nothing about
the feature changed — the Docker Desktop environment underneath it did.

## Fix

**In this repo: don't build an image when the container opens.** Since #135
(`23d4489`, merged 2026-09-03) `.devcontainer.json` is `"image": "dev"` — the
prebuilt image from this repo's own `Dockerfile` (`FROM nixos/nix`), built
ahead of time with `just docker-build` and sharing the `devhome` /
`claude-home` volumes with `docker/dev.sh`. No feature runs, so no post-install
GC runs, and the failure is unreachable rather than worked around. It also
removes the build-time `git ls-remote` documented in
`devcontainer-nix-feature-version-lookup.md`, and every other reason a
Reopen-in-Container needs the network.

**Elsewhere, if you need Debian plus Nix:** install Nix from your own
Dockerfile, where no GC step exists to fail. This is what the
`.cheat/devcontainer` template's feature block turns into once the feature
stops working for you:

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo xz-utils \
 && rm -rf /var/lib/apt/lists/*

# BEFORE the installer runs, on purpose - see below.
RUN mkdir -p /etc/nix \
 && printf 'build-users-group =\nsandbox = false\nexperimental-features = nix-command flakes\n' > /etc/nix/nix.conf

RUN curl -fsSL https://nixos.org/nix/install -o /tmp/install-nix \
 && sh /tmp/install-nix --no-daemon --no-channel-add \
 && rm /tmp/install-nix

ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"
```

...referenced from `.devcontainer.json` with a `build` key instead of `image`:

```jsonc
"build": { "dockerfile": "devcontainer.Dockerfile", "context": "." }
```

Two details that bite when you write that Dockerfile:

- **Seed `/etc/nix/nix.conf` before running the installer.** A single-user
  install still stamps `build-users-group = nixbld` into nix.conf without
  creating that group, and the installer's own first `nix` call then fails
  with `error: the group 'nixbld' specified in 'build-users-group' does not
  exist`. Writing `build-users-group =` first empties the setting; single-user
  builds as the calling user and needs no build-user pool.
- **Install single-user (`--no-daemon`).** A build layer has no init system,
  so the multi-user daemon can't be started anyway — the feature hits the same
  wall and says so ("I don't support your init system yet").

Verified end-to-end on 2026-08-05 with `@devcontainers/cli` 0.88.0: the
resulting container gives Nix 2.35.1 with `nix-command flakes` enabled, and
`nix-collect-garbage` runs fine *inside* the container — it is only fatal when
it runs during the image build.

Dropping the feature also drops the `nix-store-${devcontainerId}` volume it
mounted over `/nix`. That is a gain, not a loss: this repo's `Dockerfile`
header explains at length why a volume over `/nix` is undesirable when the
store is baked into the image.

## Notes / dead ends

Ruled out by testing, so nobody retreads them:

- **Not the config.** The original `.devcontainer.json` builds and starts
  successfully (`outcome: success`) on a Linux Docker daemon with the feature
  intact. The file is also unchanged in git since it was added.
- **Not the file location.** A root-level `.devcontainer.json` is still fully
  supported; the CLI discovers it correctly.
- **Not `"packages": []`.** Feature options are typed `string`/`boolean` — the
  spec has no array type — so this was invalid, but the CLI silently coerced
  it to `PACKAGES=""`, which is what was wanted. Worth correcting where the
  repo still hands a reader a `features` block — the `.cheat/devcontainer`
  template — but never the cause.
- **Not a stale `nix-store-<devcontainerId>` volume.** Rebuilding with
  `--remove-existing-container` over a pre-existing volume succeeds.
- **Not the feature version.** Every version back to 1.1.3 has the GC step.
- **Not TLS interception**, in this case — though that is a real and separate
  failure mode of the same feature, documented in
  `devcontainer-nix-feature-version-lookup.md`. It presents completely
  differently: it fails *early*, with `Invalid VERSION value: latest`, and Nix
  never installs at all. If Nix printed "Alright! We're done!", you are
  looking at this problem, not that one.
- **Bare `nixos/nix:latest` is not a drop-in image.** Its `/etc` entries are
  nix-store symlinks, so the CLI's user setup fails with
  `openat etc/group: path escapes from parent`. True of the upstream image;
  *not* true of this repo's, which materializes `/etc/{passwd,group,shadow}`
  as regular files for exactly this reason (the `RUN for f in passwd group
  shadow` step in the `Dockerfile`). That fix is what makes the
  `"image": "dev"` route above possible — without it, dropping the feature
  would have had nowhere to land.
