---
title: "A rustup toolchain in the devhome volume stops executing after an image rebuild"
date: 2026-09-21
category: runtime-errors
module: home-manager/modules/dev/rust.nix
problem_type: runtime_error
component: tooling
severity: medium
symptoms:
  - "error: command failed: 'cargo': No such file or directory (os error 2) - and the same for rustc, from any directory"
  - "`which cargo` resolves fine (/root/.nix-profile/bin/cargo) and the file it points at exists and is executable"
  - "`rustup show` lists the toolchain as installed, active and default; `rustup --version` adds 'the currently active `rustc` version is (error reading rustc version)'"
  - "starship's rust module renders the language icon with no version after it"
  - "A second toolchain installed more recently in the same container runs perfectly"
root_cause: incomplete_setup
resolution_type: config_change
related_components:
  - development_workflow
  - documentation
tags:
  - rust
  - rustup
  - nix
  - docker
  - devcontainer
  - patchelf
  - glibc
  - home-manager
  - activation
---

# A rustup toolchain in the devhome volume stops executing after an image rebuild

## Problem

The `dev` image keeps `/root` in a named volume (`devhome`) so Claude/gh auth, jj
state and downloaded toolchains survive `docker run --rm`. `~/.rustup` is part of
that deal, and `home-manager/modules/dev/rust.nix` says so in as many words: the
toolchain "downloads once and persists across `--rm`, not once per start".

What that comment missed is that a rustup toolchain is **not portable across
image builds**. nixpkgs' `rustup` carries a patch that runs `patchelf` on every
binary it downloads, rewriting the ELF interpreter to the glibc *of the image
doing the install*. Nix store paths are content-addressed, so the next image
build - a `nix flake update`, a new `nixos/nix:latest`, anything that moves
glibc - produces a different path for the same glibc version. The toolchain in
the volume keeps pointing at the old one.

The loader is then missing, and `execve` answers `ENOENT` for a binary that is
sitting right there. That is the error you get, and it names the wrong file.

## Symptoms

Inside a devcontainer whose `devhome` volume predates the current image:

```
❯ cargo build
error: command failed: 'cargo': No such file or directory (os error 2)

❯ which cargo
/root/.nix-profile/bin/cargo
```

Every diagnostic says the toolchain is fine:

```
❯ rustup show
installed toolchains
--------------------
stable-aarch64-unknown-linux-gnu (active, default)
1.98-aarch64-unknown-linux-gnu

❯ ls -l ~/.rustup/toolchains/stable-aarch64-unknown-linux-gnu/bin/cargo
-rwxr-xr-x 1 root root 41491752 Aug  5 04:00 cargo
```

The tell is the *other* toolchain in the same container working. Reading the
baked-in interpreter out of each binary explains the split immediately:

| toolchain | installed | ELF interpreter | present in image? | runs? |
|---|---|---|---|---|
| `stable` | Aug 5, under the previous image | `/nix/store/cjcj20n…-glibc-2.42-67/lib/ld-linux-aarch64.so.1` | **no** | ✗ |
| `1.98` | Sep 8, under the current image | `/nix/store/6wjykzq…-glibc-2.42-84/lib/ld-linux-aarch64.so.1` | yes | ✓ `cargo 1.98.1` |

```sh
# what to run when you suspect this
tr -d '\0' < ~/.rustup/toolchains/<toolchain>/bin/cargo \
  | grep -ao '/nix/store/[a-z0-9]*-glibc[^ ]*ld-linux[^ ]*' | head -1
ls -l "$(that path)"     # gone => this is the bug
```

Note the image's store still held *a* `glibc-2.42-67`, at a different hash
(`jp8avbm…`), alongside the `2.42-84` the current build uses. Comparing version
numbers is not enough; the hash is the identity.

## What Didn't Work

- **Reading it as a PATH problem.** `which cargo` answers, so the shim is
  installed and on PATH; nothing about the message points at `~/.rustup`.
- **Reading it as "no toolchain".** The module's own history primed this one:
  the previous bug in this file really was a missing toolchain (`rustup update`
  installs nothing when none exists), and it prints a *different* message -
  `no default toolchain`. Here rustup is certain the toolchain is installed.
- **Re-running activation.** This is the important one, and the reason the fix
  is a code change rather than a note. Activation ran `rustup default stable`,
  which is documented as a no-op once the toolchain is there - it checks for an
  installed toolchain, not a working one. Restarting the container, or
  rebuilding the image again, therefore repairs nothing, forever.
- **`rustup toolchain install stable --force`.** The obvious one-liner, and it
  is a trap. rustup decides what to fetch from the channel manifest, not from
  whether the installed binaries run: a toolchain already at the current stable
  is "unchanged", and `--force` re-downloads nothing, leaving every broken
  binary in place. It *looked* correct when first tried by hand here only
  because that toolchain was from Aug 5 and a release behind, so the repair
  came from the update, not from the flag. Caught by breaking a healthy
  toolchain deliberately (`patchelf --set-interpreter /nix/store/deadbeef…`)
  and re-running the fix — which is the only way that distinction shows up.

## Solution

Two parts: repair the container you are in, and stop activation from being
unable to repair it.

**Repair by hand** — remove the toolchain, then let rustup install it fresh so
the binaries are patchelf'd against the glibc this image has:

```sh
rustup toolchain uninstall stable && rustup default stable
rustup component add rust-analyzer     # uninstall takes the components with it
```

**The config change** in `home-manager/modules/dev/rust.nix` - probe whether the
toolchain *executes*, not whether it exists:

```nix
home.activation.rustupDefaultToolchain =
  lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.rustup}/bin/rustup default stable || true

    if ! run --silence ${pkgs.rustup}/bin/rustup run stable cargo --version; then
      run ${pkgs.rustup}/bin/rustup toolchain uninstall stable || true
      run ${pkgs.rustup}/bin/rustup default stable || true
    fi

    run ${pkgs.rustup}/bin/rustup component add rust-analyzer || true
  '';
```

`component add` sits outside the branch because the uninstall drops the
toolchain's components with it, so the repair path has to re-add them and the
healthy path is a no-op either way.

`|| true` stays on every call for the reason the module already
documents: activation runs at container start, and a failed `run` aborts it
*after* `linkGeneration`, leaving a perfect prompt and no packages. Starting
offline must degrade to "no toolchain yet", never to a broken profile.

## Why This Works

`run --silence` is home-manager's own helper (`home-manager.sh`, `run()`): it
swallows both streams, and under `DRY_RUN` it echoes the command and returns 0,
so a dry-run activation never triggers the reinstall branch.

`rustup run stable cargo --version` is the cheapest possible end-to-end test:
it resolves the toolchain exactly as the shims do and then actually `exec`s the
binary, so a missing loader fails the probe. An existence check cannot - the
file is present, executable, and the right size.

The probe costs one process spawn on a healthy container and nothing on the
network. Only a container that would otherwise be broken pays for the
re-download, and it pays once: the fresh binaries are patchelf'd to the glibc
of the image that is running now, which is the same image that will run next
start.

Verified 2026-09-21, twice over.

In the live aarch64 devcontainer, on the codecrafters test bed named in #80:

- before: `cargo build` → `command failed: 'cargo'`
- after repairing the toolchain: `cargo build` and a full `cargo build
  --release` both succeed, build scripts (`libc`, `anyhow`, `httparse`,
  `generic-array`, `lock_api`) compile and link via `cc` →
  `/root/.nix-profile/bin/cc`, gcc 15.3.0 — which is also the first real test
  of the `stdenv.cc` that #80 adds.

And against the activation step itself, in a throwaway container with its own
`RUSTUP_HOME`, running the fragment **as generated into `$GEN/activate`**
rather than as written in the module:

1. empty `RUSTUP_HOME` → installs stable; probe passes; no second download
2. `patchelf --set-interpreter /nix/store/deadbeef-glibc/…` on `cargo` and
   `rustc` → reproduces `command failed: 'cargo'` exactly
3. fragment re-run → probe fails, toolchain uninstalled and reinstalled
4. `cargo 1.98.1`, `rustc 1.98.1`, and `rustup which rust-analyzer` resolving
   again

Step 2 is the part worth copying into any future version of this: a fix for a
stale-state bug can only be tested by manufacturing the stale state.

## Prevention

- **Treat a persisted `~/.rustup` as image-scoped state.** The volume outlives
  the image; patchelf'd binaries in it do not. Any tool that installs its own
  prebuilt binaries into `$HOME` on a Nix rootfs inherits this - the nixpkgs
  wrapper patches them at install time, so the store path is baked in and
  "install once, keep forever" quietly stops being true at the next rebuild.
- **`ENOENT` on a file you can see means the loader, not the file.** Same
  reading that `docs/solutions/integration-issues/vscode-dev-containers-on-a-nix-rootfs.md`
  needed for `node: cannot execute: required file not found`. When an error
  names a binary that demonstrably exists, ask what the *kernel* could not
  find.
- **Idempotent is not self-healing.** An activation step guarded on "is it
  installed" can only ever fix the empty case. If the state it manages can go
  bad in place - and anything in a persisted volume can - the guard has to test
  the property you actually want.
- **Validating an old branch means re-checking its premises, not just its
  diff.** #80's Rust commits were written 2026-08-05 against the patchelf-era
  image; the volume they left behind is what broke, and a second premise from
  the same era ("VS Code's bundled rust-analyzer cannot run on a Nix rootfs")
  had also expired - nix-ld from #135 runs it unmodified. Same lesson the
  devcontainer doc rewrite exists to teach.

## Related Issues

- `docs/solutions/integration-issues/vscode-dev-containers-on-a-nix-rootfs.md` -
  the other half of "FHS binary on a Nix rootfs", and where nix-ld comes from
- `docs/solutions/runtime-errors/dev-container-image-drift-silent-restart-regressions.md` -
  the general shape: image and volume drift apart, and the container keeps
  starting
- `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md` -
  the other failure class the `dev` image's persisted profile causes
- PR #80 - gives the `dev` image its Rust toolchain; this was found validating it
