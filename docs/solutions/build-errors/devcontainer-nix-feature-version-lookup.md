---
title: "The devcontainer nix feature fetches GitHub on every build, so an unchanged .devcontainer.json can stop working"
date: 2026-08-05
category: build-errors
module: .devcontainer.json
problem_type: build_error
component: tooling
severity: high
symptoms:
  - "\"Reopen in Container\" fails during the image build with: ERROR: Feature \"Nix Package Manager\" (ghcr.io/devcontainers/features/nix) failed to install!"
  - "Immediately above it: 'Invalid VERSION value: latest' followed by 'Valid values:' and an EMPTY list — the list is empty because the lookup that fills it failed, not because 'latest' is wrong"
  - "Often preceded by: fatal: unable to access 'https://github.com/NixOS/nix/': server certificate verification failed. CAfile: none CRLfile: none"
  - "The same .devcontainer.json worked for months and is unchanged in git; a stripped-down copy with no customizations key fails identically"
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
  - tls
  - proxy
  - upstream-bug
---

# The devcontainer nix feature fetches GitHub on every build

> **Not the cause of the #82 regression** — that one was the feature's
> post-install garbage collection dying with EPERM under Docker Desktop for
> Mac; see `devcontainer-nix-feature-gc-eperm.md`. This page documents a
> *different*, independently reproduced failure mode of the same feature.
>
> Telling them apart takes one line of the build log. **This** failure happens
> early and Nix never installs — the log stops at `Invalid VERSION value:
> latest`. **That** failure happens at the very end, after the installer has
> printed `Alright! We're done!`, with `error: read of 65536 bytes: Operation
> not permitted`.
>
> Neither can bite this repo any more, and not because the feature was fixed:
> since #135 (`23d4489`, merged 2026-09-03) `.devcontainer.json` is
> `"image": "dev"` — the prebuilt image from this repo's own `Dockerfile`,
> built ahead of time by `just docker-build`. There is no image build at
> Reopen-in-Container time, so there is no feature, no `git ls-remote`, and no
> post-install GC. Kept because the diagnosis applies to any repo that still
> uses the feature — including anyone following the debian+nix-feature
> template in `.cheat/devcontainer`.

## Problem

`.devcontainer.json` stops building even though the file has not changed —
and reducing it to a minimal copy (drop `customizations`, drop the extension
list) changes nothing. The build fails inside the nix feature with:

```
fatal: unable to access 'https://github.com/NixOS/nix/': server certificate verification failed. CAfile: none CRLfile: none
Invalid VERSION value: latest
Valid values:

ERROR: Feature "Nix Package Manager" (ghcr.io/devcontainers/features/nix) failed to install!
```

The `Invalid VERSION value` line sends you hunting for a bad `version` option.
That is a red herring — nothing is wrong with the config.

## Root cause

`ghcr.io/devcontainers/features/nix` resolves its `version` option into a
concrete Nix release by running, **inside the build container, on every
build**:

```sh
git ls-remote --tags https://github.com/NixOS/nix
```

When that command fails, `version_list` comes back empty, so the resolved
version is empty, and upstream's error branch prints the requested value
(`latest`) next to an empty set of valid values. The message describes a
config problem; the actual failure is network.

**Pinning `version` does not avoid the fetch.** Upstream's `utils.sh` intends
to skip the lookup when you pass a concrete version, but the guard is broken:

```sh
# src/nix/utils.sh
local version_regex="[0-9]+${escaped_separator}[0-9]+${break_fix_digit_regex}..."   # builds version_regex
if ! echo "${requested_version}" | grep -E "^${versionMatchRegex}$" ...; then       # tests versionMatchRegex
```

It builds `version_regex` but tests `$versionMatchRegex`, which is never
defined. The expansion is empty, so the test is `grep -E "^$"` — it matches
only an empty string, the negation is always true, and the `git ls-remote`
runs unconditionally. Setting `"version": "2.35.1"` still hits GitHub.

So the devcontainer has a hard build-time dependency on reaching
`github.com` over TLS that no amount of config can pin away.

## Why it "used to work"

Nothing in the repo changed; the environment around it did. Anything that
breaks that one `git ls-remote` breaks the build:

- A TLS-inspecting corporate proxy, VPN, or endpoint-security agent that
  re-signs HTTPS with a CA the *build container* does not trust (the host
  trusting it is irrelevant — the failure is inside the container)
- Egress policy that blocks or filters github.com
- GitHub being unreachable or rate-limiting

The first is by far the most common, and it is invisible from the host: the
browser and the host `git` keep working because they trust the intercepting
CA. The container does not.

## Diagnosis

The VS Code UI truncates the useful part. Get the real error from the CLI:

```sh
npm install -g @devcontainers/cli
devcontainer up --workspace-folder .
```

Then confirm whether it is TLS interception:

```sh
docker run --rm debian:bookworm-slim sh -c \
  'apt-get update -qq && apt-get install -y -qq git ca-certificates >/dev/null \
   && git ls-remote --tags https://github.com/NixOS/nix | head -3'
```

Clean output means the network is fine and the cause is elsewhere. A
`server certificate verification failed` means the container needs your
organization's CA.

## Fix (TLS interception)

Bake the intercepting CA into a base image and point the devcontainer at it,
so the feature's `git ls-remote` can verify the re-signed certificate:

```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
RUN update-ca-certificates
```

Verified end-to-end on 2026-08-05 against `@devcontainers/cli` 0.88.0 and nix
feature 1.3.1: with the CA present the unmodified config builds and starts
(`outcome: success`) and yields Nix 2.35.1 with `nix-command flakes` enabled.

**The stronger fix is not to build an image at container-open time at all.**
This repo's own `Dockerfile` (`FROM nixos/nix`) ships Nix in the base image and
never consults GitHub for a version, so a devcontainer pointed at it —
`"image": "dev"`, built ahead of time with `just docker-build` — has no
build-time network dependency to break. That is what `.devcontainer.json` does
here, and it is the first thing to reach for elsewhere; the CA fix above is
what you need when you must keep the feature.

If the blockage is transient (GitHub down, flaky egress) and you are staying on
the feature, there is no config workaround — retry.

## Notes / dead ends

- **`"packages": []` was invalid but harmless.** Feature options are typed
  `string` or `boolean` — the spec has no array type. The CLI silently
  coerced `[]` to `PACKAGES=""`, which is what was wanted anyway. It was never
  the cause. This repo's config no longer uses the feature at all, so the
  correction lives in the `.cheat/devcontainer` template — the one place that
  still hands a reader a `features` block.
- **A stale `nix-store-<devcontainerId>` volume is not the cause.** The
  feature mounts one at `/nix`. Rebuilding with `--remove-existing-container`
  against a pre-existing volume was tested and succeeds. (This is a real
  failure mode for the repo's own `Dockerfile`, which bakes the store into
  the image — see the header comment there — but not for the feature path,
  which populates the volume itself.)
- **Raw `nixos/nix:latest` is not a drop-in devcontainer image.** Its `/etc`
  entries are nix-store symlinks, so the CLI's user-setup step fails with
  `openat etc/group: path escapes from parent`. Still true of the upstream
  image, and no longer true of this repo's: the `Dockerfile` materializes
  `/etc/{passwd,group,shadow}` as regular files for exactly this reason (see
  the `RUN for f in passwd group shadow` step and the header entry above it),
  which is what makes `"image": "dev"` viable. A bare
  `"image": "nixos/nix:latest"` still is not.
- The root-level `.devcontainer.json` location is still fully supported —
  the CLI discovers it correctly. File placement was not the issue.
