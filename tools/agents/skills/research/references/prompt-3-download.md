# Step 3 — Download Materials

Populates `inspiration/` with all materials in `docs/research/downloads.yaml`.

## The Original Prompt (subject to user modifications)

> Use sub-agents to download all materials identified in download.yaml into the inspiration/ directory. Update the status in the yaml file as each sub-agent completes a download. Balance throughput and rate-limiting. Start with 5 sub-agents. Verify that inspiration/ is in gitignore; if it's not, add it (we can always reconstitute this directory from download.yaml later)

## Procedure

### 3.1 — Verify Gitignore

Check that `.gitignore` (at project root) contains `inspiration/`. If not, append it. If `.gitignore` doesn't exist, create it with `inspiration/` as the first line. Never replace existing `.gitignore` content — append only.

### 3.2 — Spawn Download Sub-Agents

Spawn 5 sub-agents (default; configurable). Each pulls the next `pending` entry from `downloads.yaml`, downloads it, and updates the entry's `status` and `path`.

Per-`kind` download strategy:

| kind | Strategy |
|---|---|
| `paper` | If `arxiv.org`: download PDF. Otherwise: try DOI resolver, fall back to direct URL. Save under `inspiration/papers/<arxiv-id-or-slug>.pdf`. |
| `repo` | `git clone --depth=1` to `inspiration/<owner>/<repo>/`. Skip if `max_size_mb` would be exceeded. |
| `article` | Save raw HTML and a markdown rendering (via readability extraction). Save under `inspiration/articles/<slug>/`. |
| `docs` | Mirror with depth limit (default depth=2). Don't try to clone an entire docs site. Save under `inspiration/docs/<domain-slug>/`. |
| `other` | Save raw URL response under `inspiration/other/<slug>`. |

### 3.3 — Throttle (Per-Domain Rate Limiting)

| Domain | Rate limit |
|---|---|
| `arxiv.org` | Max 1 request per 3 seconds (per their robots.txt) |
| `github.com` | Respect the user's `GITHUB_TOKEN` rate limit (5000/hr authenticated, 60/hr unauthenticated) |
| Generic | Max 1 request per 1 second per domain |

If a sub-agent hits a rate limit: sleep with exponential backoff and update yaml `status: downloading`. Don't mark `failed` until 3 retries.

### 3.4 — Update Yaml Atomically

Each sub-agent must lock the yaml before writing. Use file locking (`flock` or equivalent) to prevent concurrent-write corruption.

### 3.5 — Surface Failures

After all sub-agents complete, list `status: failed` entries to the user. Don't auto-retry — failed entries usually need human triage (paywalled, deleted, requires auth).

## Inputs

- `docs/research/downloads.yaml`
- Project root `.gitignore` (read/write)

## Output

- Files under `inspiration/<kind>/<...>/`
- Updated `docs/research/downloads.yaml` with `status: done` + `path` for each successful entry
- Updated `.gitignore` if needed

## Verification

- `.gitignore` contains `inspiration/`
- All `status: pending` entries are now `status: done` or `status: failed` or `status: skipped`
- `path` field set on each `status: done` entry, and the file actually exists at that path
- yaml re-parses cleanly (no corruption)

## Pitfalls

- **Yaml write races.** Five sub-agents writing concurrently is the most likely failure mode. File locking is mandatory.
- **Aggressive crawlers.** "Mirror this docs site" can easily download gigabytes. Cap depth (default 2), cap total bytes per entry (default 50 MB).
- **Auth-gated content.** Some papers (IEEE, ACM, paywalled journals) require institutional login. Mark `status: skipped` with a `notes` field rather than `status: failed`.
- **Repository sizes.** Some "prior art" repos are huge. `--depth=1` is the default; also consider a `max_size_mb` flag to skip oversized clones. Mark `status: skipped` with reason.
- **`.gitignore` clobber.** Don't replace existing `.gitignore` content — append `inspiration/` only if missing.
- **Robots.txt and ToS.** Respect robots.txt. If a site forbids crawling, mark `status: skipped` with the reason — don't bypass.
