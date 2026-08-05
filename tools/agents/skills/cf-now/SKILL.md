---
name: cf-now
description: >
  Share files (HTML decks, slides, reports, PDFs) from Alyssa's Cloudflare R2
  storage via a fully private bucket and time-limited pre-signed URLs — access
  is gated by an R2 API token, nothing is publicly hosted (no r2.dev URL, no
  custom domain). Use when asked to "publish this", "share this", "get me a URL
  for this", "push this to R2/Cloudflare", "presign this", or to share an HTML
  deck, demo script, report, or document. Safe for Ditto-internal content: only
  holders of a live pre-signed URL can view, and URLs expire. Supports stable
  slugs for re-upload, URL refresh without re-upload (--presign), unpublish, and
  listing. Ephemeral by default (storage auto-deletes after ~7 days); pass
  --permanent to keep. URLs are intentionally obtuse — opaque random keys plus
  the pre-signed signature; unguessable, crawler-safe, not meant to be typed or
  remembered.
---

# cf-now

Private file sharing from Alyssa's Cloudflare R2, modeled on the s3-now
workflow but backed by R2 instead of AWS S3. Same trust model: the R2 bucket
is never public. Generating a link requires the R2 API token credentials; the
pre-signed URL itself is the time-limited grant handed to viewers (viewers need
no Cloudflare access).

R2 speaks the S3 API, so the tooling is the AWS CLI pointed at the R2 endpoint
(`https://{account-id}.r2.cloudflarestorage.com`). `wrangler` is *not* used —
it can create buckets and put objects but cannot mint pre-signed URLs, which is
the whole point here.

## Requirements

- `aws` CLI v2 and `jq` (both installed on this machine)
- A Cloudflare **R2 API token** (Object Read & Write) exposed to an AWS named
  profile (default: `alyssa-r2`) — its Access Key ID / Secret Access Key are
  the token's S3 credentials
- The Cloudflare **account ID** (32-hex), via `CF_ACCOUNT_ID` or `--account-id`
- Global config at `~/.cfnow/config.json` (written by `setup.sh`)

## Authentication

Unlike s3-now (which needs an interactive `aws sso login` every session),
cf-now uses a **long-lived R2 API token** configured once as static
credentials — there is no per-session login to run. Configure the profile once
(in Claude Code, `!` runs it inline):

```
! aws configure set aws_access_key_id     <R2_ACCESS_KEY_ID>     --profile alyssa-r2
! aws configure set aws_secret_access_key <R2_SECRET_ACCESS_KEY> --profile alyssa-r2
```

Mint the token at Cloudflare dashboard → R2 → **Manage R2 API Tokens** →
*Create API token* (Object Read & Write). If a script fails with
"not authenticated", the token is missing, revoked, or expired — the user must
create/rotate it in the Cloudflare dashboard and re-run the two lines above.
You cannot do this for them.

## One-time setup

```bash
CF_ACCOUNT_ID=<account-id> ./scripts/setup.sh   # defaults: profile alyssa-r2, bucket cf-now
./scripts/setup.sh --account-id ID --profile OTHER --bucket OTHER
```

Idempotent. Creates a private R2 bucket `cf-now` and a lifecycle rule expiring
the `tmp/` prefix after 7 days. R2 buckets are **private by default** — there
is no public r2.dev URL and no custom domain unless one is explicitly attached,
so (unlike S3) there is no public-access-block to set. Writes
`~/.cfnow/config.json`.

## Publish (upload + pre-sign)

```bash
./scripts/publish.sh {file} [--expires 12h]
```

Uploads to `{bucket}/tmp/{slug}/{filename}` where the slug is an opaque 32-char
random hex string (128 bits of entropy — unguessable by design; these URLs are
meant to be pasted, not typed), and prints the pre-signed URL as the last
stdout line. `publish_result.*` lines on stderr carry metadata. HTML gets
`Content-Type: text/html` + inline disposition so browsers render it.

Ephemeral by default: storage auto-deletes after ~7 days (bucket lifecycle on
`tmp/`). Pass `--permanent` to keep content until unpublished.

**Single self-contained HTML files are the sweet spot** (html-deck output
qualifies). Pre-signed URLs are per-object: a multi-file site's relative asset
links will NOT resolve for viewers. Directories upload fine for storage, but
only the presigned `index.html` is directly viewable.

## URL expiry — the part that surprises people

- `--expires` accepts seconds or `Nm`/`Nh`/`Nd`. R2/SigV4 hard cap: 7 days.
- **With a long-lived R2 token the URL lasts its full requested lifetime** (up
  to the 7-day cap) — there is no SSO-session shortening like s3-now has. If the
  token is scoped with a TTL or gets rotated/revoked, every URL it signed dies
  immediately, regardless of `--expires`.
- Default: 12h — right for "share a deck for today's demo".

When sharing, tell the user the effective expiry (the requested value, capped
at 7 days) and that rotating the R2 token invalidates outstanding URLs.

## Refresh a URL without re-uploading

```bash
./scripts/publish.sh --presign --slug {slug} [--expires 12h]
```

Looks up the object key from `.cfnow/state.json`, falling back to a bucket
prefix search. Use this when a link expired but the content hasn't changed.

## Update content at a stable slug

```bash
./scripts/publish.sh {file} --slug {slug}
```

Re-uploads and prints a fresh URL. Directory sync is destructive for that slug
(`--delete`). Prior slugs for the current project are in `.cfnow/state.json` —
check it before minting a new slug for content that was published before.

## Permanent storage (opt-in)

```bash
./scripts/publish.sh {file} --permanent
```

Stores outside `tmp/` so the lifecycle rule never deletes it — for content that
should outlive a week (re-presign for fresh URLs anytime). Everything else
defaults to ephemeral.

## Manage

```bash
./scripts/publish.sh --list                     # everything in the bucket
./scripts/publish.sh --unpublish --slug {slug}  # delete an upload
```

## State file

Each publish writes `.cfnow/state.json` in the working directory:

```json
{
  "publishes": {
    "topaz-harbor-x7k2": {
      "key": "topaz-harbor-x7k2/deck.html",
      "ephemeral": false,
      "publishedAt": "2026-07-01T12:00:00Z"
    }
  }
}
```

Internal cache only — never present this path to the user as a URL. Don't
commit it (add `.cfnow/` to `.gitignore`; in jj repos, follow the jujutsu
skill's gitignore guidance BEFORE publishing so it never gets
auto-snapshotted). Pre-signed URLs are never stored — they contain
credentials-derived signatures; regenerate rather than persist them.

## What to tell the user

- Share the URL from the current script run, plus its effective expiry
  (requested value, capped at 7 days).
- Storage persists until unpublished (or ~7 days for the default ephemeral
  `tmp/` prefix); only the URL expires. `--presign` mints a new link anytime.
- Content behind an expired URL is NOT gone — just re-presign.

## Content posture

Internal content is acceptable here — the bucket is private to Alyssa's
Cloudflare account and links expire. Still prefer the default ephemeral prefix
and short `--expires` for anything sensitive, and remember: anyone holding a
live pre-signed URL can view (and forward) it during its window.

## Markdown and other formats

Browsers won't render raw `.md` nicely (uploaded as `text/plain`). For anything
meant to be *read* — demo scripts, reports — render to a single self-contained
HTML file first, then publish that. For slides, the html-deck skill's
single-file output publishes as-is.

## R2 compatibility notes

- All AWS CLI calls target the R2 S3 endpoint via `--endpoint-url` and
  `--region auto`; the scripts read both from `~/.cfnow/config.json`. Per
  Cloudflare's S3 docs, `auto` is the R2 region (empty/`us-east-1` also alias
  to it), and presigning against `<account>.r2.cloudflarestorage.com` with
  `region: auto` is the documented path — so the pre-signed host resolves.
- The scripts export `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` (and the
  matching response var) so AWS CLI v2's newer default integrity checksums
  don't trip R2 — a known incompatibility that otherwise surfaces as a
  `400 Bad Request` / `XAmzContentSHA256Mismatch` on `cp`/`sync` (and R2's
  `PutBucketLifecycleConfiguration` rejects checksum headers outright).
- `setup.sh` reads the lifecycle rule back with
  `get-bucket-lifecycle-configuration` and refuses to write config if it
  didn't apply — so "ephemeral by default" can never silently become
  "permanent forever" from a payload R2 quietly ignored.
- If a presign ever produces an unreachable host, force path-style addressing:
  `aws configure set s3.addressing_style path --profile alyssa-r2`.
