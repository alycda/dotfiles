---
title: "R2 reports AccessDenied for a working token: the auth probe needed wider scope than the tool"
date: 2026-08-05
category: integration-issues
module: tools/agents/skills/cf-now/scripts/publish.sh
problem_type: integration_issue
component: tooling
symptoms:
  - "publish.sh dies with \"not authenticated. Configure the R2 token creds for profile 'alyssa-r2'\" while upload, presign and delete all work fine with that same token"
  - "`aws s3 ls` returns \"An error occurred (AccessDenied) when calling the ListBuckets operation\" even though object operations on the target bucket succeed"
  - "`aws s3 ls s3://<name>` returns AccessDenied rather than NoSuchBucket when the bucket name is simply wrong"
  - "GetBucketLifecycleConfiguration returns AccessDenied, so the script's \"storage expires in ~7 days\" claim cannot be confirmed from the client"
root_cause: wrong_api
resolution_type: code_fix
severity: medium
tags:
  - cloudflare-r2
  - s3-api
  - aws-cli
  - least-privilege
  - auth-probe
  - cf-now
  - presigned-urls
related_components:
  - development_workflow
  - documentation
---

# R2 reports AccessDenied for a working token: the auth probe needed wider scope than the tool

## Problem

`publish.sh` refused to run against a freshly minted, entirely functional R2 token, reporting that it was not authenticated. Every operation the script actually performs — upload, list objects, delete, pre-sign — worked when run by hand with the same profile. The auth probe, not the credentials, was wrong.

## Symptoms

- `error: not authenticated. Configure the R2 token creds for profile 'alyssa-r2'` on a token that could read, write, delete and pre-sign in the target bucket
- `aws --profile alyssa-r2 s3 ls` → `An error occurred (AccessDenied) when calling the ListBuckets operation`
- `aws --profile alyssa-r2 s3 ls s3://cfnow` → `AccessDenied` on ListObjectsV2, when the bucket was really named `cf-now` — a *name* error presenting as a *permission* error
- `s3api get-bucket-lifecycle-configuration` → `AccessDenied`

## What Didn't Work

- **Assuming the credentials were wrong.** The obvious reading of "not authenticated" is a bad key. Re-minting the token would have produced an identical failure, since the token was never the problem.
- **Reading `AccessDenied` on the bucket as a scope problem.** It was a typo — `cfnow` vs `cf-now`. R2 does not distinguish the two cases for the caller (see *Why This Works*), so no amount of staring at the token's bucket scoping would have revealed it. What actually found it was listing buckets through a *different* credential path (the Cloudflare MCP connector, which authenticates as the account) and seeing the real name.
- **Trusting a shell harness over a direct run.** A loop that captured `2>&1 >/dev/null` reported all three candidate probes as denied, including two that worked. Re-running each command directly gave the true result. When a probe matrix disagrees with a single manual run, believe the manual run.

## Solution

Probe with the narrowest operation the tool itself requires. `publish.sh` knows its bucket, so `HeadBucket` on that bucket tests exactly what the script goes on to use:

```bash
# publish.sh:98 — was: s3api list-buckets
if ! "${AWSP[@]}" s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  die "cannot reach bucket '$BUCKET' with profile '$PROFILE' — check the bucket name, and that the R2 token is scoped to it (see SKILL.md → Authentication)"
fi
```

Measured against a live Object Read & Write token scoped to one bucket:

| Probe | Result |
|---|---|
| `s3api list-buckets` | AccessDenied |
| `s3api head-bucket --bucket <bucket>` | exit 0 |
| `s3api list-objects-v2 --bucket <bucket>` | exit 0 |

`setup.sh:46` deliberately **keeps** its account-level `list-buckets` probe: that script creates the bucket and writes its lifecycle rule, so it requires Admin Read & Write regardless, and probing account-level fails early with a clear message instead of dying at `create-bucket`. Its error now names the permission level and points at the alternative (create the bucket and rule in the dashboard, use an Object-scoped token, skip `setup.sh`).

The bucket default was corrected to the real name at `setup.sh:17`.

Fix opened in PR #47; unmerged as of this writing.

## Why This Works

Two independent facts combine into one misleading error.

**R2 returns `AccessDenied` rather than `NoSuchBucket` for any bucket outside the credential's reach.** This is deliberate — `NoSuchBucket` would let a caller enumerate which buckets exist by probing names. The cost is that a wrong bucket name and an out-of-scope bucket are indistinguishable from the client. No client-side check can tell them apart, so the error text must name both possibilities.

**An auth probe that needs broader rights than the tool encodes the wrong permission model.** `ListBuckets` is account-level; the least privilege the script needs is object access to one bucket. The probe was asserting a permission the tool never uses, so it failed exactly for correctly-scoped credentials — the tighter the credential, the more likely the false alarm. Tight scoping matters here beyond principle: an account-wide Admin token could delete every unrelated bucket in the account.

## Prevention

- **Probe with the narrowest operation the tool itself performs.** If a script only ever touches one bucket, probe that bucket. A liveness check that demands more privilege than the work is a false negative waiting for the first least-privilege credential.
- **When a platform collapses two failures into one error, say both in the message.** "cannot reach bucket X — check the name, and that the token is scoped to it" costs nothing and removes the entire misdiagnosis.
- **Distinguish setup-time from steady-state privilege.** Provisioning (create bucket, write lifecycle) legitimately needs admin; daily use does not. Two scripts, two permission levels, two probes — and say so in the error when the admin one fails.
- **Don't let a script assert what it cannot verify.** `publish.sh` prints `storage_expires=~7 days (bucket lifecycle rule)` as a flat claim, but reading the lifecycle config is an admin operation that returns AccessDenied under least privilege. If the rule were missing or mis-prefixed the script would still promise expiry. Either soften the wording or let the provisioning script be the only place that claims it.
- **Verify a probe matrix against direct runs.** Redirection order in a test harness silently inverted three results here.

## Related Issues

- PR #47 — the cf-now skill and these fixes
- [`../build-errors/home-manager-bash-collides-with-base-image-profile.md`](../build-errors/home-manager-bash-collides-with-base-image-profile.md) — the other case in this repo where a green-looking signal hid the real failure
