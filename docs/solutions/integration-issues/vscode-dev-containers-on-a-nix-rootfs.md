---
title: VS Code Dev Containers fails against the Nix-based dev image
date: 2026-08-05
category: integration-issues
module: docker
problem_type: integration_issue
component: tooling
symptoms:
  - "Shell server terminated (code: 126, signal: null), then `openat etc/passwd: path escapes from parent`"
  - "check-requirements.sh: line 48: getconf: command not found, exit 127"
  - "node: cannot execute: required file not found"
  - "patchelf: open: Text file busy, from bin/code-server on first open"
  - "The container starts cleanly under `docker run`; only the first `docker exec` fails"
root_cause: incomplete_setup
resolution_type: environment_setup
severity: high
related_components: [development_workflow]
tags: [devcontainer, vscode, docker-exec, nix, fhs, orbstack, nix-ld]
---

# VS Code Dev Containers fails against the Nix-based dev image

> **Status: image-side fixes are on `main`.** They landed in #135 (`23d4489`,
> merged 2026-09-03), rebased off the branch this doc was first written on;
> that branch's remaining Rust work is #80, where this rewrite ships. Statements
> about `main` below are as of 2026-09-04. Written 2026-08-05 against a
> patchelf-based solution that was *verified end to end locally and still
> failed on the first real devcontainer open* — rewritten 2026-09-04 to
> describe the nix-ld mechanism that replaced it, with patchelf demoted to
> "What Didn't Work", where it is the most instructive entry in the file.

## Problem

The `dev` image exists to be a devcontainer — `home-manager/profiles/dev.nix` is
headed `# devcontainers / codespaces` — but VS Code Dev Containers could not
open a folder in it. Two independent defects, both caused by the image being a
Nix rootfs while the tooling assumes FHS, and each producing an error that
names something other than itself.

## Symptoms

Two failures in sequence. The first blocks the container entirely:

```
Shell server terminated (code: 126, signal: null)
openat etc/passwd: path escapes from parent
```

Fix that, and the flow gets as far as installing the server before dying on:

```
check-requirements.sh: line 48: getconf: command not found
Exit code 127
```

...or, past that check, on the same missing loader one layer down:

```
node: cannot execute: required file not found
```

All of them are misleading. The container starts fine in each case — `docker
run` works, the start event fires, `docker inspect` succeeds — so the failure
looks like a volume or permissions bug in the devcontainer config.

## What Didn't Work

- **Blaming `runArgs: ["--init"]` for the first failure.** The reasoning was
  plausible: `--init` bind-mounts a host-built `docker-init` at
  `/sbin/docker-init` and makes it PID 1, and this image has no `/sbin`, no
  `/lib` and no `/lib64` for it to land in or link against. It was wrong.
  Removing `--init` reproduced the failure byte for byte. The tell that should
  have redirected the diagnosis sooner: the container *starts* and only the
  first `docker exec` dies, which points at exec-time resolution, not PID 1.

- **Reaching for `/etc/os-release` with `ID=nixos` on the second failure.**
  `check-requirements.sh` does carry a NixOS bypass (line 34) that exits 0
  before the `getconf` call. But it parses the file with `sed`, which is not on
  PATH in a `docker exec` environment here, and the script runs under `set -e` —
  so the tidier-looking fix trades a missing-`getconf` failure for a missing-`sed`
  one. The env-var bypass at line 20 runs first and shells out to nothing.

- **Assuming `getconf` was the problem.** It is the first FHS assumption the
  script trips over, not the reason the server cannot run.

- **Microsoft's own `VSCODE_SERVER_CUSTOM_GLIBC_*` escape hatch — the route
  this doc originally prescribed.** Documented under
  [Can I run VS Code Server on older Linux distributions?](https://code.visualstudio.com/docs/remote/faq),
  it is the sanctioned answer and it does not work here. Given all three
  variables, `bin/code-server` patchelfs its own `node` **in place** on first
  launch (`--set-rpath`, then `--set-interpreter`). Dev Containers installs the
  server into a `vscode` Docker volume shared by *every* devcontainer on the
  machine, so that rewrite is global, not per-image. Two failure modes, both
  hit on the first real open:

  - with a Debian-based devcontainer running the same server build, patchelf
    dies with `Text file busy` — the binary is executing out of the shared
    volume;
  - had it succeeded, that Debian container would have inherited a `node` whose
    ELF interpreter is `/opt/vscode-glibc/linker`, a path that exists only in
    this image.

  The patch is also incomplete even in the happy case: it only covers
  `bin/code-server`, and the extension's own container helper execs
  `$HOME/.vscode-server/bin/<commit>/node` directly on a first start, which the
  rewrite never reaches.

  The subtlety worth keeping: `VSCODE_SERVER_CUSTOM_GLIBC_LINKER` is still set
  in the Dockerfile, **alone, on purpose**. It is the first thing
  `check-requirements.sh` tests (exit 0 before any of the FHS probing that hits
  `getconf`), and `bin/code-server` only patches when all three variables are
  present. One variable keeps the bypass and loses the rewrite.
  `VSCODE_SERVER_CUSTOM_GLIBC_PATH` must stay unset; the Dockerfile header says
  so, and `patchelf: open: Text file busy` is what setting it looks like.

  This entry is the most valuable one in the file, because the route was
  verified end to end — `node -e` printed `v24.18.0` after patchelfing — and
  still failed on first real open, for a reason no amount of local verification
  would have surfaced. The shared `vscode` volume is not visible from inside
  one container.

## Solution

Three changes. Two in the image (`Dockerfile`), one in any consuming
`.devcontainer.json`.

**1. Materialize `/etc/{passwd,group,shadow}` as regular files.** The
`nixos/nix` base image ships them as absolute symlinks into the store.

```dockerfile
RUN for f in passwd group shadow; do \
      if [ -L "/etc/$f" ]; then cp -L "/etc/$f" "/tmp/$f" && mv -f "/tmp/$f" "/etc/$f"; fi; \
    done \
 && chmod 0644 /etc/passwd /etc/group \
 && chmod 0600 /etc/shadow
```

**2. Put a loader at the path VS Code Server's prebuilt `node` asks for —
with nix-ld, not patchelf.** nix-ld is what NixOS uses for exactly this case: a
static ELF interpreter installed at the FHS path, which reads the *real*
dynamic linker from `$NIX_LD` and a library search path from
`$NIX_LD_LIBRARY_PATH` and then hands off, for the one process being started.
The binary is never modified, so nothing leaks into the shared `vscode` volume,
and no other program in the image sees an `LD_LIBRARY_PATH`. Both variables are
load-bearing — nix-ld 2.x with `NIX_LD` unset panics rather than guessing — so
they are `ENV`, where every `docker exec` inherits them.

```dockerfile
RUN mkdir -p /opt/vscode-glibc \
 && nix build --inputs-from path:/opt/dotfiles -o /opt/vscode-glibc/nix-ld-pkg nixpkgs#nix-ld \
 && nix build --inputs-from path:/opt/dotfiles -o /opt/vscode-glibc/glibc-pkg  nixpkgs#glibc.out \
 && nix build --inputs-from path:/opt/dotfiles -o /opt/vscode-glibc/gcc-pkg    nixpkgs#stdenv.cc.cc.lib \
 && case "$(uname -m)" in \
      aarch64) ld=ld-linux-aarch64.so.1; interp=/lib/ld-linux-aarch64.so.1   ;; \
      *)       ld=ld-linux-x86-64.so.2;  interp=/lib64/ld-linux-x86-64.so.2  ;; \
    esac \
 && ln -sfn "glibc-pkg/lib/$ld"  /opt/vscode-glibc/linker \
 && ln -sfn glibc-pkg/lib        /opt/vscode-glibc/libc \
 && ln -sfn gcc-pkg-lib/lib      /opt/vscode-glibc/libcxx \
 && mkdir -p "$(dirname "$interp")" \
 && ln -sfn /opt/vscode-glibc/nix-ld-pkg/libexec/nix-ld "$interp" \
 && test -x /opt/vscode-glibc/linker \
 && test -e /opt/vscode-glibc/libc/libc.so.6 \
 && test -e /opt/vscode-glibc/libcxx/libstdc++.so.6 \
 && test -x "$interp"

ENV NIX_LD=/opt/vscode-glibc/linker \
    NIX_LD_LIBRARY_PATH=/opt/vscode-glibc/libc:/opt/vscode-glibc/libcxx \
    VSCODE_SERVER_CUSTOM_GLIBC_LINKER=/opt/vscode-glibc/linker
```

Note what is *absent*: no `VSCODE_SERVER_PATCHELF_PATH`, no
`VSCODE_SERVER_CUSTOM_GLIBC_PATH`. Setting either re-arms the in-place rewrite
described under "What Didn't Work".

`--inputs-from` resolves `nixpkgs` through the flake's own lock rather than the
ambient registry, so this reuses the glibc the image already links against; the
marginal cost is nix-ld and gcc-lib, not a second libc. `-o` roots the paths for
the GC, matching how `/opt/hm-activation` is handled. The `*-pkg` links are the
GC roots; the unsuffixed ones are what the `ENV` refers to, so the variables
never encode a store path, an architecture, or nix's output-naming rules.

**3. Invoke the entrypoint from `postStartCommand`.** The Dev Containers CLI
starts the container with `--entrypoint /bin/sh`, so `docker/entrypoint.sh` —
and the home-manager activation inside it — never runs on its own:

```jsonc
"postStartCommand": "/opt/dotfiles/docker/entrypoint.sh true && git config --file /root/.gitconfig --replace-all safe.directory ${containerWorkspaceFolder}"
```

This is idempotent: the entrypoint compares the activated generation against
`/opt/hm-activation` and no-ops when they match. The `safe.directory` half is
the VS Code FAQ fix for a bind mount owned by another uid, and is written to a
plain `~/.gitconfig` rather than with `--global` — `--global` resolves through
the home-manager symlink into the store and is reverted by the next activation.

## Why This Works

**The exec failure.** `docker exec` resolves the user's entry host-side, rooted
at the container rootfs, using `openat2` with `RESOLVE_BENEATH` semantics —
which rejects absolute symlinks outright as escaping their parent, rather than
re-rooting them the way `RESOLVE_IN_ROOT` would. `docker run` takes a different
code path, which is why the container starts and only exec dies. Copying the
content into place is inert: same bytes, same lookups, store paths untouched,
and nothing in this image adds users afterwards.

**The server failure.** `getconf` is the symptom. The server ships a 121 MB
glibc-linked `node` built for FHS — it wants `/lib/ld-linux-aarch64.so.1`
(x86_64: `/lib64/ld-linux-x86-64.so.2`) as its ELF interpreter, and this rootfs
has no `/lib` at all, so it dies with a bare `cannot execute: required file not
found` that names the binary rather than the missing loader. Verified
2026-09-03 against the exact server build VS Code 1.135.0 pulls: with nix-ld at
that path and the `NIX_LD*` variables set, the **unmodified** binary prints
`v24.18.1` and `bin/code-server --version` launches.

(The earlier patchelf route was verified the same way — `v24.18.0` against the
1.131.0 server — which is precisely why "it printed a version" is not evidence
that a devcontainer will open. See "What Didn't Work".)

A symlink works as an ELF interpreter — the kernel resolves it — which is what
lets the `ENV` values stay stable across rebuilds.

## Prevention

- **Keep `runArgs` a subset of `docker/dev.sh`'s `docker run`.** That command is
  the invocation this image is actually tested against; anything added beyond it
  is untested surface. This would not have prevented the bug, but it is the
  reason `--init` was a suspect at all, and dropping it cost nothing.

- **Reach for the real artifact before theorising.** Both early wrong turns came
  from reasoning about scripts rather than reading them. Downloading the exact
  server build and reading the two shell scripts shipped inside that tarball —
  `check-requirements.sh` and `code-server`, neither of them files in this repo —
  turned a guess into a five-minute answer, and surfaced the sanctioned bypass
  that no amount of inference would have produced.

- **Ask what state a fix writes, and who else shares it.** Reading those same
  scripts is *also* what should have flagged the patchelf route: it mutates the
  server install, and Dev Containers puts that install in a machine-wide volume.
  A fix verified inside one container cannot see the other containers that share
  its state. Prefer the mechanism that leaves the artifact untouched.

- **Bisect image-level failures outside the devcontainer.** Two commands
  separate "the image is broken" from "the config is wrong", in seconds rather
  than a multi-minute rebuild:

  ```sh
  docker run -d --name exectest --entrypoint /bin/sh dev -c 'while sleep 1; do :; done'
  docker exec exectest echo hi; echo "exit=$?"
  ```

  For the loader half, the equivalent one-liner is what the Dockerfile header
  tells you to run when the symptom returns:

  ```sh
  docker run --rm --entrypoint /bin/sh dev -c 'ls -l /lib*/ld-linux-*; env | grep NIX_LD'
  ```

  If that comes back empty, the Dockerfile is not the problem — the image was
  built from a ref that predates the fix. `docker/dev.sh build`/`up` fetch this
  repo from GitHub and default to `main`; only `just docker-build` builds the
  checkout you are sitting in.

- **Guard derived paths with `test` in the same `RUN`.** `nix build -o foo` on a
  non-default output lands at `foo-lib`, not `foo` — pointing `ENV` straight at
  the `-o` path silently misses libstdc++. The `test`s turn that class of
  mistake into a build failure instead of a runtime one.

- **When a container starts but the first `docker exec` fails,** suspect
  host-side path resolution against the rootfs, not volumes or permissions.

## Related Issues

- `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md`
  — the other class of failure this image produces, where activation dies after
  linking dotfiles and leaves a working prompt with no tools. Same
  diagnostic shape: the visible error names the wrong thing.
- `docs/solutions/runtime-errors/dev-container-image-drift-silent-restart-regressions.md`
  — why this file was rewritten rather than rebased. A solutions doc that still
  prescribes a mechanism the Dockerfile above it deliberately forbids is the
  same drift shape: a derived artifact and its record disagreeing, with nothing
  failing loudly.
- The `Dockerfile` header carries a troubleshooting index; all three failures
  above are listed there for on-sight recognition.
