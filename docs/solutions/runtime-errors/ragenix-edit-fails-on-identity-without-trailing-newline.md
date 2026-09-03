---
title: "ragenix fails on every secret when the age identity file has no trailing newline"
date: 2026-08-05
category: runtime-errors
module: home-manager/modules/git.nix
problem_type: runtime_error
component: tooling
severity: medium
symptoms:
  - "`agenix -e secrets/work/hackmd-api-token.age` aborts with 'Tried to reset after the underlying buffer was exceeded' at 'Location: src/age.rs:123'"
  - "Every secret fails identically — including a file `rage` armored seconds earlier — so it reads as key or repo corruption"
  - "`rage -d -i ~/.age/personal-key.txt <same file>` exits 0 with the same identity, so ciphertext and key are provably fine"
  - "home-manager activation keeps working throughout: ~/.local/share/agenix already holds 7 decrypted secrets while `agenix -e` is dead"
root_cause: config_error
resolution_type: config_change
related_components:
  - development_workflow
  - authentication
  - documentation
tags:
  - agenix
  - ragenix
  - age
  - rage
  - secrets
  - identity-file
  - trailing-newline
  - nix
---

# ragenix fails on every secret when the age identity file has no trailing newline

> Not this? If secrets **silently never appear** rather than erroring, see
> `config-errors/agenix-secrets-never-install-without-systemd.md` (on the
> unmerged `feat/cloudflare-docs-mcp` branch at time of writing) — same tool,
> same identity file, opposite failure signature.

## Problem

Every `agenix -e` and `agenix --rekey` died with a buffer error pointing at the
ciphertext code path. The actual cause was one missing byte at the end of the
*identity* file, `~/.age/personal-key.txt`. Interactive secret editing was
completely dead while `rage` and home-manager activation kept working — so the
breakage stayed invisible until someone tried to edit a secret.

## Symptoms

Run from `/work/alycda/dotfiles/secrets`:

```console
$ EDITOR=hx agenix -i ~/.age/personal-key.txt -e work/hackmd-api-token.age
Error:
   0: Tried to reset after the underlying buffer was exceeded.
   1: Tried to reset after the underlying buffer was exceeded.
Location:
   src/age.rs:123
```

The editor never opens and no temp plaintext is produced. It fails on *every*
secret, not just the one being edited. `ragenix --rekey` fails the same way — it
uses the same identity reader — which would have surfaced at the worst possible
moment, the first time a second machine key was added.

Meanwhile `rage -d` on the same ciphertext with the same identity succeeds. The
tool contradicts itself, which is the tell.

## What Didn't Work

**Hypothesis 1 — the ciphertext is corrupt.** The error's `Location: src/age.rs`
names the `.age` file's code path, and the secret in question was a freshly
committed placeholder, so "the file I'm editing is malformed" is the obvious
read. Wrong:

```console
$ rage -d -i ~/.age/personal-key.txt secrets/work/hackmd-api-token.age > /dev/null
$ echo $?
0
```

Three fixtures killed the file-specific theory outright. ragenix failed
identically on (a) the new placeholder, (b) a long-working secret,
`secrets/personal/git-config.age`, and (c) a file `rage` itself had armored
seconds earlier. A tool that cannot read what its own sibling just wrote is not
hitting a bad file.

The reframe came from searching GitHub for the literal error string: it lives
upstream in the `str4d/rage` repository, at `age/src/cli_common/identities.rs`
— **identity-file parsing, not ciphertext decryption**. `age.rs:123` was
ragenix's own frame, not the failing parser.

**Hypothesis 2 — pin ragenix to a known-good version.** This is the dead end
worth recording, because the reasoning is sound and the fix still does not
exist:

- `agenix` here is a symlink to the `ragenix-2025.03.09` derivation (the binary
  itself reports `ragenix 0.1.0`), declared as flake input
  `github:yaxitech/ragenix` (`flake.nix:22-25`) and pinned in `flake.lock` to
  **yaxitech/ragenix** commit `83bccfdea758241999f32869fb6b36f7ac72f1ac` — an
  upstream rev, not a commit in this repository.
- `Cargo.lock` **at that pinned rev** vendors `age` 0.10.1.
- `Cargo.lock` **at upstream HEAD** also vendors `age` 0.10.1.
- That pinned rev *is* the latest commit on ragenix's `main` as of 2026-08-05
  (2025-10-30, "Update flake inputs to fix build on newer nixpkgs (#163)").

The fix landed upstream in **age 0.11.0** (2024-11-03) — its changelog reads
*"`age::cli_common::read_identities` once again correctly parses identity files
that are a single line without a trailing newline. This broke in 0.10.0 due to
an unrelated refactor."* ragenix is still one minor version short of it. So no
rev of ragenix helps: this needs a **dependency** bump, not an input bump.

## Solution

Append a trailing newline to the identity file, and tighten its mode:

```console
$ tail -c1 ~/.age/personal-key.txt | od -c     # last byte is 'W', not \n
$ printf '\n' >> ~/.age/personal-key.txt
$ chmod 600 ~/.age/personal-key.txt            # had been 0644
```

Verify the identity is unchanged — the public key must match before and after:

```console
$ rage-keygen -y ~/.age/personal-key.txt
age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09
```

A/B proof that the newline is the whole story: the same key was copied into two
files, one verbatim and one with `\n` appended. ragenix failed on the 74-byte
copy and succeeded on the 75-byte copy — same key, same ciphertext, same binary.

## Why This Works

age's identity parser has to decide, with no format marker, whether a file holds
an *encrypted* identity, an *SSH* identity, or a *native age* identity. To do
that it reads an entire line and peeks. For a header-less single-line file that
one line **is** the whole file, which violates the parser's assumption that the
underlying buffer is larger than the read — and the reset fails.

This is upstream [str4d/rage#484](https://github.com/str4d/rage/issues/484),
closed 2024-08-28. Two details from the maintainer's diagnosis are worth
keeping:

- The failure needs **both** conditions: no trailing newline **and** no comment
  header. A file carrying the usual `# created:` / `# public key:` header parses
  fine even without a trailing newline. The identity here was a bare
  `AGE-SECRET-KEY-1…` with neither.
- The reporter noted it worked with rage < 0.10 — a regression introduced with
  the 0.10 parser and fixed later in the line.

Hence the split personality:

| Binary | `age` crate | Result |
|---|---|---|
| `rage` CLI | 0.12.1 (≥ 0.11.0, has the fix) | works |
| `agenix` → ragenix | vendored 0.10.1 | fails |

Same key, same file, opposite outcomes — which is the fastest way to recognise
this bug in the wild.

**Scope — what was never broken.** home-manager activation was fine throughout,
because the activation path decrypts by shelling out to the `rage` binary rather
than to ragenix's vendored crate. That is explicit in
`home-manager/modules/agenix-activation.nix:60,84` — a file that lives on the
unmerged `feat/cloudflare-docs-mcp` branch, not in this checkout — which builds
`${config.age.package}/bin/age` and invokes it directly. Observable evidence:
`~/.local/share/agenix/` held 7 successfully decrypted secrets while `agenix -e`
was failing. Only the interactive edit/rekey flow was dead.

The identity path itself is declared once, at `home-manager/modules/git.nix:8-9`:

```nix
secretsDir = "${config.home.homeDirectory}/.local/share/agenix";
identityPaths = [ "${config.home.homeDirectory}/.age/personal-key.txt" ];
```

## Prevention

**Fix the source, not this container.** The identity was never generated with
`age-keygen` — it was retrieved from a password manager and pasted into place,
which is exactly the step that yields a value with no trailing newline. (session
history) The container injection path (`cat > /root/.age/personal-key.txt`) is
byte-exact, so it faithfully propagates whatever the host file lacks.

That makes the in-container fix fragile in one specific way: `/root/.age` lives
in the `devhome` volume (`Dockerfile:41`), and `docker volume rm devhome` is a
real move in this repo's vocabulary (`Dockerfile:21`). Any devhome reset deletes
the identity, and re-staging from the same source reintroduces the bug. (session
history) `~/.claude` got its own `claude-home` volume precisely so resets stop
destroying auth; `~/.age` got no such treatment. **Append the newline to the host
copy — that is the one every future bootstrap inherits.**

(The related profile-collision class — `git-minimal`, `man-db`, `bash`; see
`build-errors/home-manager-bash-collides-with-base-image-profile.md` — is
normally resolved by a rebuild rather than a volume wipe, per
`docker/CLAUDE-arm64.md:52` — a file on `main`, not in the checkout this was
written from. The point here is only that a devhome reset, by whatever cause,
takes the identity with it.)

**Detect it in one line.** Either check identifies the condition instantly:

```sh
# non-empty output means the last byte is NOT a newline
[ -n "$(tail -c1 ~/.age/personal-key.txt)" ] && echo "identity: missing trailing newline"

wc -l < ~/.age/personal-key.txt   # 0 on a non-empty file is the same tell
```

**Generate keys with the header.** `rage-keygen -o <file>` writes the
`# created:` / `# public key:` header *and* a trailing newline — either one
alone immunizes the file — and creates it mode 0600 into the bargain.
Hand-extracting the bare `AGE-SECRET-KEY-1…` line into a new file is what strips
all three protections at once.

**Surfaces that still assume "absent" is the only identity failure.** Each of
these will misdiagnose a present-but-malformed key, sending you to re-copy a
file you already have:

- `docker/entrypoint.sh:30-31` — prints a `docker cp` hint on activation
  failure. Best hardening site in the repo: it already owns the age-identity
  story and runs on every start, right after the `docker cp` that introduces the
  bad file. An idempotent normalization there is ~3 lines.
- `Dockerfile:33-41` — "If the key is absent…", and the documented `docker cp`
  recovery is the path that omits the newline.
- `tools/cheat/cheatsheets/community/agenix/edit` — the cheatsheet for the exact
  failing command, with no mention of the identity file. Lowest-cost fix, and
  it's the surface you hit at the moment of failure.
- `tools/agents/README.md:110-116` — "ensure the age identity exists at
  `~/.age/personal-key.txt`". Existence is not sufficient.

**Don't trust the error's `Location:` line.** When an error names a path that a
sibling tool reads fine, search the literal error string upstream before
theorizing about the data.

## Related Issues

- [str4d/rage#484](https://github.com/str4d/rage/issues/484) — the upstream bug,
  closed 2024-08-28. Confirms the root cause exactly, including that the error
  message is itself the defect.
- [yaxitech/ragenix#142](https://github.com/yaxitech/ragenix/pull/142) — "Update
  (r)age to 0.10.0", merged 2024-02-12. **Upstream already knows.** The PR that
  introduced the affected version says in its own body: *"Also needed to add a
  newline to an identity in tests to work around
  https://github.com/str4d/rage/issues/484. This also affects users of
  ragenix."* They papered over it in test fixtures and shipped it knowingly.
  So the durable fix is not a bug report — it is a **dependency bump past `age`
  0.10.1**, which `Cargo.lock` at ragenix HEAD still pins.
- `config-errors/agenix-secrets-never-install-without-systemd.md` — the sibling
  ragenix failure. Silent absence → that doc; this error string → this one.
