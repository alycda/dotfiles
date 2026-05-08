# Step 2 — Download Manifest

Produces `docs/research/downloads.yaml`.

## The Original Prompt (subject to user modifications)

> Look through docs/research. I want to produce a list of unique URLs and repos which will be downloaded to act as prior art for our upcoming project.
>
> Because research results will continue to stream in from other researchers, create a docs/research/downloads.yaml to track which papers, repos, articles etc have already been downloaded. The format should be suitable for idempotent upsert as new URLs are discovered.

## Procedure

1. Scan `docs/research/*.md` for cited URLs (prefer the explicit "Source ledger" section if present; fall back to scraping URLs from prose).
2. Deduplicate, normalize (canonical arxiv form, strip query strings, expand short URLs), and classify (`paper` / `repo` / `article` / `docs` / `other`).
3. Read existing `docs/research/downloads.yaml` if it exists.
4. Upsert: add new URLs as `status: pending`; preserve existing entries' `status`, `path`, and `notes` fields.
5. Write `docs/research/downloads.yaml`.

## Output

See `templates/downloads.yaml.example` for format. Each entry has:

- `url` — canonical URL (the upsert key)
- `kind` — paper | repo | article | docs | other
- `title` — short human-readable title
- `cited_in` — list of researcher-ids that cited this (e.g., `[claude-opus, gpt-5]`)
- `status` — pending | downloading | done | failed | skipped
- `path` — local path under `inspiration/` once downloaded; null otherwise
- `notes` — optional, for manual annotations

## Verification

- All `docs/research/*.md` URLs appear in the yaml
- No duplicate `url` values
- Existing entries' `status`, `path`, `notes` preserved across re-runs
- yaml validates against the schema in `templates/downloads.yaml.example`

## Pitfalls

- **URL normalization.** `arxiv.org/abs/2406.12345` and `arxiv.org/pdf/2406.12345v2.pdf` and `arxiv.org/abs/2406.12345v2` are the same paper. Pick a canonical form (recommended: `arxiv.org/abs/<id>`, no version) and normalize before deduping.
- **Repo URLs vs. file URLs.** `github.com/owner/repo` (clone the repo) vs. `github.com/owner/repo/blob/main/file.py` (just save the file). Classify correctly so Step 3 uses the right downloader.
- **Source ledger trust.** Some researchers cite secondary sources (Medium reposts, paper summaries) instead of primaries. Flag suspicious URLs in `notes` but don't drop them — let the user decide.
- **Re-runs after Step 1.5 streams in more researchers.** This is the core reason for upsert. Don't lose existing `status: done` / `path:` annotations on re-run.
- **Short URLs and redirects.** `bit.ly/...`, `tinyurl/...`, `t.co/...` should be expanded before storing. Some shorteners 404 over time.
