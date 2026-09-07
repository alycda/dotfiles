---
title: "agenix never prunes, so a secret with no ciphertext behind it looks perfectly managed"
date: 2026-09-03
category: runtime-errors
module: home-manager/modules/agenix-activation.nix
problem_type: config_error
component: tooling
severity: high
symptoms:
  - "`~/.aws/config` and `~/.aws/credentials` are symlinks into `~/.local/share/agenix/`, exactly like every real managed secret, but no `.age` file backs them and no `age.secrets` entry declares them"
  - "`grep -r r2-credentials` over the whole repo — every branch — returns nothing, while the decrypted plaintext sits in the volume working fine"
  - "The active generation's closure contains no reference to the secret name, yet the secret is present on disk"
  - "Everything works, indefinitely, so nothing ever prompts you to look"
root_cause: config_error
resolution_type: config_change
related_components:
  - authentication
  - development_workflow
  - documentation
tags:
  - agenix
  - ragenix
  - secrets
  - home-manager
  - activation
  - docker-volume
  - orphaned-state
  - credential-loss
  - cloudflare-r2
---

# agenix never prunes, so a secret with no ciphertext behind it looks perfectly managed

## Problem

The R2 API token that `cf-now` depends on existed in exactly one place on
earth: a plaintext file in the `devhome` Docker volume. There was no
ciphertext in `secrets/`, no entry in `secrets/secrets.nix`, and no
`age.secrets` declaration in any module on any branch.

It had been that way for a month, and nothing was wrong. `~/.aws/credentials`
was a symlink into `~/.local/share/agenix/`, the AWS CLI authenticated, the
skill published files. From the outside it was indistinguishable from a
correctly managed secret.

The hazard is what that implies. `docker/CLAUDE-arm64.md` names
`docker volume rm devhome` as the recovery path for a failed home-manager
activation — so the documented fix for a broken container was also an
unrecoverable loss of a credential, requiring a re-mint in the Cloudflare
dashboard. **The only copy of a secret was in the thing the troubleshooting
guide tells you to delete.**

## Root cause

`home-manager/modules/agenix-activation.nix` installs secrets and never
removes them. `installOne` decrypts to a canonical path and symlinks any
`path` override at it:

```nix
run mv -f "$_canon.tmp" "$_canon"
run chmod "$_mode" "$_canon"

if [ "$_dest" != "$_canon" ]; then
  run mkdir -p "$(dirname "$_dest")"
  run ln -sfn "$_canon" "$_dest"
fi
```

then the module folds that over `config.age.secrets`:

```nix
${lib.concatMapStrings installOne (lib.attrValues config.age.secrets)}
```

It is a pure write loop over the *declared* set. Nothing enumerates what is
already in `~/.local/share/agenix` and nothing deletes. So the directory is
append-only across every generation the volume has ever seen, and it accretes
two kinds of junk:

1. **Removed secrets.** Drop an `age.secrets` entry and its decrypted
   plaintext stays on disk forever. You did not un-deploy the credential; you
   only stopped refreshing it.
2. **Hand-placed files.** Anything written into that directory by hand is
   adopted by every subsequent activation, because activation never looks.

Both are invisible, because the *consumer* keeps working. A `path` override
is what makes this dangerous rather than merely untidy: it puts the symlink at
a real, load-bearing location like `~/.aws/credentials`, so the orphan is
wired into the tool it serves.

## How it surfaced

Not from a failure — from timestamps. Managed secrets are re-decrypted on
every activation and all carry the current generation's mtime. Orphans keep
the mtime of whenever they were written:

```
-r-------- Sep  3 20:19  agent-instructions git-config hackmd-api-token linear-api-key-{work,personal}
-r-------- Aug  5 07:06  cloudflare-api-token r2-config r2-credentials
```

Three files a month stale in a directory whose whole purpose is to be
rewritten at every container start. That skew is the tell, and it is the only
one — there is no error, no warning, and no missing file.

Confirm by asking the active generation what it actually installs. The
activation script renders one `_agenix_install` line per declared secret, so
that list *is* the declared set:

```bash
GEN=$(readlink -f ~/.local/state/home-manager/gcroots/current-home)
grep -oE '_agenix_install [^ ]+' "$GEN"/activate | sort -u
```

Anything in `~/.local/share/agenix` that this does not name is an orphan. On
the container that prompted this note it printed five names — exactly the five
carrying the current mtime.

Two traps in getting that command right, both of which produced a wrong answer
first:

- **`/nix/var/nix/profiles/per-user/$USER/home-manager` and
  `~/.local/state/home-manager/gcroots/current-home` are the generation; a
  `result` symlink in a checkout is not.** A stale `./result` from some earlier
  `nix build` points at a generation that may never have been activated, and
  grepping *that* answers a question about a build nobody switched to.
  `home-manager generations` prints the real one.
- **Do not `grep -r` the closure for the secret name.** The activation script
  embeds the module's comments, and `agenix-activation.nix` happens to use
  `~/.local/share/agenix/cloudflare-api-token` as a worked example in its
  header — so a recursive grep reports that secret as present when the only
  match is prose. Match on `_agenix_install` instead.

## Solution

Capture the plaintext as a real secret before anything can destroy it, then
declare it. For the R2 credentials that meant encrypting both halves to the
repo's age recipient, armored (a binary `.age` blob does not reliably survive
every path into a commit):

```bash
PUB=age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09
rage -a -r "$PUB" -o secrets/personal/r2-credentials.age ~/.local/share/agenix/r2-credentials
```

then round-tripping it against the live file *before* trusting it — comparing
hashes rather than printing either:

```bash
a=$(rage -d -i ~/.age/personal-key.txt secrets/personal/r2-credentials.age | sha256sum)
b=$(sha256sum ~/.local/share/agenix/r2-credentials)
[ "${a%% *}" = "${b%% *}" ] && echo "round-trip OK"
```

then registering it in `secrets/secrets.nix` and declaring it in a module
(`home-manager/modules/tools/cf-now.nix`), with the `path` overrides that
reproduce the symlinks that were already there.

The alternative resolution is equally valid and should be the default for
anything unclaimed: **delete the orphan.** If nothing in the repo consumes it,
a stale plaintext credential in a volume is a liability, not an asset.

## Why this works

The point is not that the file moved — it is already on disk either way. The
point is that the credential is now *derivable*. Before, the volume was the
source of truth and the repo knew nothing; after, the repo is the source of
truth and the volume is a cache that any activation can rebuild. A
`docker volume rm devhome` becomes what the troubleshooting guide assumes it
is: an inconvenience.

This also fixes rotation, which was quietly broken in the same way.
`SKILL.md` told the user to rotate with `aws configure set`, but
`~/.aws/credentials` is a symlink into the agenix runtime dir — so that either
writes through the symlink or replaces it, and the next activation silently
reverts either way. A rotated token would appear to work until the next
switch. With the secret declared, rotation is
`just edit-secret personal/r2-credentials.age`.

## Prevention

- **Audit by mtime, not by presence.** `ls -la ~/.local/share/agenix` and
  compare against the last activation. Anything older is undeclared. This is
  a five-second check and it is the only signal available.
- **Treat a `path` override as a claim that must have ciphertext behind it.**
  If a tool reads a credential from a stable home path, grep the repo for it.
  A working tool proves nothing about where its config came from.
- **When removing an `age.secrets` entry, delete the decrypted file too.**
  Removing the declaration does not un-deploy the secret; on every machine
  that ever activated that generation, the plaintext is still sitting there.
- **`cloudflare-api-token` is a known remaining orphan** — same Aug 5 mtime,
  and absent from the `_agenix_install` list. It is the case the comment trap
  above was hiding: a recursive grep says it is declared, and it is not.
  Nothing consumes it, so it wants deleting or capturing — deliberately left
  alone rather than silently swept up with the R2 work.
- Adding a prune step to `agenix-activation.nix` would fix the class outright,
  but it is not obviously safe: the activation script cannot distinguish an
  orphan from a secret belonging to a *different* home-manager generation
  sharing the same home, and deleting credentials is not a good place for a
  heuristic. Documented rather than automated, on purpose.

## Related

- `docs/solutions/integration-issues/r2-auth-probe-fails-on-least-privilege-token.md`
  — the other cf-now failure whose error text is equally uninformative; R2
  answers `AccessDenied` for a missing identity, a revoked token and a wrong
  bucket name alike
- `docs/solutions/runtime-errors/ragenix-edit-fails-on-identity-without-trailing-newline.md`
  — the other way this secrets pipeline fails without saying so
- `home-manager/modules/agenix-activation.nix` — the module header explains why
  activation-time decryption exists at all (ragenix installs via a systemd user
  service; the container has no user systemd daemon)
