---
name: s3-now
description: >
  Share files (HTML decks, slides, reports, PDFs) from Alyssa's personal AWS
  scratchpad account via a fully private S3 bucket and time-limited
  pre-signed URLs — access is gated by AWS SSO, nothing is publicly hosted.
  Use when asked to "publish this", "share this", "get me a URL for this",
  "push this to my scratchpad", "presign this", or to share an HTML deck,
  demo script, report, or document. Safe for Ditto-internal content: only
  holders of a live pre-signed URL can view, and URLs expire. Supports
  stable slugs for re-upload, URL refresh without re-upload (--presign),
  unpublish, and listing. Ephemeral by default (storage auto-deletes after
  ~7 days); pass --permanent to keep. URLs are intentionally obtuse — opaque
  random keys plus the pre-signed signature; unguessable, crawler-safe, not
  meant to be typed or remembered.
---

# s3-now

Private file sharing from Alyssa's AWS scratchpad, modeled on here.now's
workflow but with the opposite trust model: the S3 bucket is never public.
Generating a link requires a live AWS SSO session; the pre-signed URL itself
is the time-limited grant handed to viewers (viewers need no AWS access).

## Requirements

- `aws` CLI v2 and `jq` (both installed on this machine)
- AWS SSO session for the scratchpad profile (default: `alyssa-scratch`)
- Global config at `~/.s3now/config.json` (written by `setup.sh`)

## Authentication

Every command needs a live SSO session. If a script fails with
"not authenticated", the user must log in interactively — you cannot do this
for them. Ask them to run (in Claude Code, `!` runs it inline):

```
! aws sso login --profile alyssa-scratch
```

Then retry the script.

## One-time setup

```bash
./scripts/setup.sh            # defaults: profile alyssa-scratch, us-east-1
./scripts/setup.sh --profile OTHER --region REGION
```

Idempotent. Creates a private bucket `s3now-{account-id}` with public access
fully blocked and a lifecycle rule expiring the `tmp/` prefix after 7 days.
No CloudFront, no public endpoint. Writes `~/.s3now/config.json`.

## Publish (upload + pre-sign)

```bash
./scripts/publish.sh {file} [--expires 12h]
```

Uploads to `s3://{bucket}/tmp/{slug}/{filename}` where the slug is an opaque
24-char random string (~124 bits of entropy — unguessable by design; these
URLs are meant to be pasted, not typed), and prints the pre-signed URL as the
last stdout line. `publish_result.*` lines on stderr carry metadata. HTML
gets `Content-Type: text/html` + inline disposition so browsers render it.

Ephemeral by default: storage auto-deletes after ~7 days (bucket lifecycle
on `tmp/`). Pass `--permanent` to keep content until unpublished.

**Single self-contained HTML files are the sweet spot** (html-deck output
qualifies). Pre-signed URLs are per-object: a multi-file site's relative
asset links will NOT resolve for viewers. Directories upload fine for
storage, but only the presigned `index.html` is directly viewable.

## URL expiry — the part that surprises people

- `--expires` accepts seconds or `Nm`/`Nh`/`Nd`. S3 hard cap: 7 days.
- **A URL signed with SSO temp credentials dies when those credentials
  expire, if sooner than `--expires`.** A "3d" link from a session with 2h
  left lasts 2h. For the longest-lived links, presign immediately after a
  fresh `aws sso login`.
- Default: 12h — right for "share a deck for today's demo".

Tell the user both numbers when sharing: the requested expiry and the
SSO-session caveat.

## Refresh a URL without re-uploading

```bash
./scripts/publish.sh --presign --slug {slug} [--expires 12h]
```

Looks up the object key from `.s3now/state.json`, falling back to a bucket
prefix search. Use this when a link expired but the content hasn't changed.

## Update content at a stable slug

```bash
./scripts/publish.sh {file} --slug {slug}
```

Re-uploads and prints a fresh URL. Directory sync is destructive for that
slug (`--delete`). Prior slugs for the current project are in
`.s3now/state.json` — check it before minting a new slug for content that
was published before.

## Permanent storage (opt-in)

```bash
./scripts/publish.sh {file} --permanent
```

Stores outside `tmp/` so the lifecycle rule never deletes it — for content
that should outlive a week (re-presign for fresh URLs anytime). Everything
else defaults to ephemeral.

## Manage

```bash
./scripts/publish.sh --list                     # everything in the bucket
./scripts/publish.sh --unpublish --slug {slug}  # delete an upload
```

## State file

Each publish writes `.s3now/state.json` in the working directory:

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
commit it (add `.s3now/` to `.gitignore`; in jj repos, follow the jujutsu
skill's gitignore guidance BEFORE publishing so it never gets
auto-snapshotted). Pre-signed URLs are never stored — they contain
credentials-derived signatures; regenerate rather than persist them.

## What to tell the user

- Share the URL from the current script run, plus its effective expiry
  (requested value + SSO-session caveat).
- Storage persists until unpublished (or ~7 days for `--ephemeral`); only
  the URL expires. `--presign` mints a new link anytime.
- Content behind an expired URL is NOT gone — just re-presign.

## Content posture

Internal content is acceptable here — the bucket is private to Alyssa's
scratchpad account and links expire. Still prefer `--ephemeral` and short
`--expires` for anything sensitive, and remember: anyone holding a live
pre-signed URL can view (and forward) it during its window.

## Markdown and other formats

Browsers won't render raw `.md` nicely (uploaded as `text/plain`). For
anything meant to be *read* — demo scripts, reports — render to a single
self-contained HTML file first, then publish that. For slides, the
html-deck skill's single-file output publishes as-is.
