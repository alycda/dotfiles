# Vendor OpenSSL in Ataraxy's release builds (sem, weave, inspect)

- STATUS: OPEN
- TAGS: upstream, ataraxy, sem, weave, inspect, openssl, macos, nix

## Description

Fork Ataraxy-Labs/sem, weave and inspect, make their release binaries carry
OpenSSL statically, push the fix, and open a PR on each.

### The problem

The aarch64 macOS release binaries load OpenSSL from Homebrew's path:

```text
$ otool -L "$(mise which sem)"
    /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib
    /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib
```

The same holds for `weave`, `weave-driver` and `inspect` (all checked on
2026-10-03, sem 0.25.0, weave 0.5.4, inspect 0.1.1). They run only on a Mac
that happens to have Homebrew's openssl@3. On a Mac without it, such as the
no-admin account mise is meant for, they fail to start, so the mise path in
this repo is broken there today. The x86_64 Linux binaries link the system's
`libssl.so.3` the same way: fine on Debian, missing on a Nix-only system.

### The cause

Each crate already has a `vendored-openssl` feature
(`openssl-sys/vendored`, which builds OpenSSL from `openssl-src`), and each
`release.yml` turns it on only for cross-compiled targets:

| Repo | Flag in the release matrix | Vendored today | Not vendored |
| --- | --- | --- | --- |
| sem | `vendor_openssl: true` | aarch64-linux, x86_64-darwin | aarch64-darwin, x86_64-linux |
| weave | `cross` | cross targets | aarch64-darwin, x86_64-linux (check) |
| inspect | `cross` | aarch64-linux | aarch64-darwin, x86_64-darwin, x86_64-linux (check) |

The native builds link whatever OpenSSL the runner has: Homebrew's on
`macos-14`/`macos-latest`, the system's on `ubuntu-latest`.

### The fix

In each `release.yml`, build every Unix target with
`--features vendored-openssl`, not only the cross ones. For sem that is
`vendor_openssl: true` on the `aarch64-apple-darwin` and
`x86_64-unknown-linux-gnu` entries; for weave and inspect, decouple the feature
from `cross` (a separate `vendor_openssl` key, or always on for non-Windows).

Alternative, larger: drop OpenSSL for rustls (git2 and libssh2 still pull in
`openssl-sys` for HTTPS and SSH, so this is not a flag flip). Mention it in
the PRs; don't do it.

### Afterwards, in this repo

Once fixed releases ship:

- Bump the versions and hashes in `lib/packages/{sem,weave,inspect}.nix`,
  and drop the macOS `install_name_tool` repointing and re-signing from
  `lib/release-binary.nix`. Keep `autoPatchelfHook` on Linux for glibc.
- Nothing to change in `mise.toml`: `latest` picks up the new releases.

## Open questions

- Linux too, or macOS only? Vendoring on x86_64-linux makes the binary need
  only glibc, which matters for Nix but not for Debian. Including it is one
  more matrix entry per repo.
- Three PRs from three forks, or start with sem and follow with the others
  once the first is accepted?
- weave's and inspect's matrices were read with grep only; confirm which of
  their targets set `cross` before editing.

## Verification

Done so far, on 2026-10-03:

- `otool -L` on the mise-installed `sem`, `weave`, `weave-driver` and
  `inspect` shows `/opt/homebrew/opt/openssl@3` for all four.
- Each `Cargo.lock` contains `openssl-src`, and each `release.yml` passes
  `--features vendored-openssl` only under `vendor_openssl` (sem) or `cross`
  (weave, inspect).

To verify the fix:

- The fork's release workflow (or a local `cargo build --release --features
  vendored-openssl` on an Apple silicon Mac) produces a binary whose
  `otool -L` lists only `/usr/lib` and `/System` libraries.
- That binary runs on a Mac account without Homebrew.
- On Linux, `ldd` on the vendored binary shows no `libssl`/`libcrypto`.
