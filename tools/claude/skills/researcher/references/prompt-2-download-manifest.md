# Step 2 — Download Manifest

Produces `_docs/research/downloads.yaml`.

## The Original Prompt (subject to user modifications)

> Look through _docs/research. I want to produce a list of unique URLs and repos which will be downloaded to act as prior art for our upcoming project.
>
> Because research results will continue to stream in from other researchers, create a _docs/research/downloads.yaml to track which papers, repos, articles etc have already been downloaded. The format should be suitable for idempotent upsert as new URLs are discovered.

## Dispatch

Step 2 runs on a **Haiku Agent sub-agent**, not the parent's frontier model. The work is structured extraction — URL detection, normalization, classification — which Haiku handles at a fraction of the Opus/Sonnet cost with no measurable regression on this task. Frontier models stay reserved for Steps 0, 1, and 1.5.

Invoke via the Agent tool with `model: "haiku"`:

```
Agent({
    description: "Build research downloads manifest",
    subagent_type: "general-purpose",
    model: "haiku",
    prompt: "<the Procedure section below + project root path>"
})
```

The sub-agent reads the markdown files in `_docs/research/`, extracts URLs, classifies them, and writes the manifest. If Haiku produces a misclassification you can spot during Step 3 downloads, re-run that one entry through the parent provider — don't escalate the whole step.

## Procedure

1. Scan `_docs/research/*.md` for cited URLs. This now includes up to **six** input files: the Step 1.5 inline-worker outputs (`{claude,codex,gemini}.md` for Mode B or `{theory,tooling,industry}.md` for Mode C) AND the Step 1.6 hosted Deep Research outputs (`{claude,chatgpt,gemini}-deep-research.md`). Prefer the explicit "Source ledger" section if present; fall back to scraping URLs from prose.
2. Deduplicate, normalize (canonical arxiv form, strip query strings, expand short URLs), and classify (`paper` / `repo` / `article` / `docs` / `other`).
3. Read existing `_docs/research/downloads.yaml` if it exists.
4. Upsert: add new URLs as `status: pending`; preserve existing entries' `status`, `path`, and `notes` fields. Track `cited_in` membership across ALL six files — the same URL cited by both `claude.md` (CLI) and `claude-deep-research.md` (hosted) gets both names in its `cited_in` list.
5. Write `_docs/research/downloads.yaml`.

## Output

See `templates/downloads.yaml.example` for format. Each entry has:

- `url` — canonical URL (the upsert key)
- `kind` — paper | repo | article | docs | other
- `title` — short human-readable title
- `cited_in` — list of researcher-ids that cited this (e.g., `[claude, codex]` for Mode B, `[theory, tooling]` for Mode C)
- `status` — pending | downloading | done | failed | skipped
- `path` — local path under `_inspiration/` once downloaded; null otherwise
- `notes` — optional, for manual annotations

## Verification

- All `_docs/research/*.md` URLs appear in the yaml
- No duplicate `url` values
- Existing entries' `status`, `path`, `notes` preserved across re-runs
- yaml validates against the schema in `templates/downloads.yaml.example`

## Pitfalls

- **URL normalization.** `arxiv.org/abs/2406.12345` and `arxiv.org/pdf/2406.12345v2.pdf` and `arxiv.org/abs/2406.12345v2` are the same paper. Pick a canonical form (recommended: `arxiv.org/abs/<id>`, no version) and normalize before deduping.
- **Repo URLs vs. file URLs.** `github.com/owner/repo` (clone the repo) vs. `github.com/owner/repo/blob/main/file.py` (just save the file). Classify correctly so Step 3 uses the right downloader.
- **Source ledger trust.** Some researchers cite secondary sources (Medium reposts, paper summaries) instead of primaries. Flag suspicious URLs in `notes` but don't drop them — let the user decide.
- **Re-runs after Step 1.5 streams in more researchers.** This is the core reason for upsert. Don't lose existing `status: done` / `path:` annotations on re-run.
- **Short URLs and redirects.** `bit.ly/...`, `tinyurl/...`, `t.co/...` should be expanded before storing. Some shorteners 404 over time.
- **Haiku misclassification.** Haiku is good at all four sub-tasks (detect / normalize / classify / flag) but a misclassified `github.com/owner/repo/blob/main/file.py` as `repo` causes Step 3 to `git clone` something that should be a single-file save. If you see any Step 3 download failures attributable to wrong `kind`, escalate that one entry's classification to the parent provider — don't escalate the whole step.
- **Mode B + Mode C output coexisting.** If both modes ran on the same project, you'll have up to six `*.md` files in `_docs/research/` from Step 1.5 alone. Step 2 should ingest all of them; the `cited_in` field will track which subset cited each URL.
- **Hosted DR arxiv hallucination.** Step 1.6's `*-deep-research.md` files are known to occasionally cite plausible-looking arXiv IDs that don't resolve (e.g., IDs dated after the current month, or wildly out-of-domain papers). Step 2 should accept them as `kind: paper` and let Step 3's download phase fail loudly on the 404 — that's the natural check. For arXiv IDs dated after the current month, add a `notes: "post-dated arxiv ID — verify before download"` flag so the user can spot-check.
- **`cited_in` membership across CLI + DR.** A URL cited by both the CLI Claude worker (`claude.md`) and the hosted Claude DR (`claude-deep-research.md`) should appear in `cited_in` as `[claude, claude-deep-research]` — not deduped to one. This lets downstream verification distinguish "everyone agrees this matters" from "only the hosted DR found this."
