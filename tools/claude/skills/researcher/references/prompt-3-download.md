# Step 3 — Download Materials

Populates `_inspiration/` with all materials in `_docs/research/downloads.yaml`.

Step 3 is **mechanical**, not LLM-driven. The `kind` field on each yaml entry (decided by Step 2's Haiku pass) is enough to dispatch each download to the right tool — `curl` for papers/articles, `git clone` for repos, `wget` for docs. No agent judgment needed. The skill invokes `scripts/download.py` via a single Bash call instead of spawning Agent sub-agents.

This was a refactor in 0.7.0-claude — previous versions spawned 5 LLM sub-agents for what is fundamentally `curl + git clone`. The script is faster, deterministic, costs nothing in tokens, and idempotent on re-runs.

## Dispatch

```bash
python3 ~/.claude/skills/researcher/scripts/download.py \
  --project-root "$PROJECT_ROOT" \
  --workers 5
```

The script:

1. Ensures `_inspiration/` exists with a nested `.gitignore` stub (`*` + `!.gitignore`) so its contents are auto-ignored (idempotent — no-op if already present).
2. Reads `_docs/research/downloads.yaml`, filters `status: pending`.
3. Fans out N parallel workers (default 5) via Python's `ThreadPoolExecutor`.
4. Each worker matches on `kind` and runs the appropriate tool.
5. Updates the yaml atomically under `fcntl.flock` (Unix) or an in-process lock (Windows) as each download completes.
6. Surfaces failures at the end; exits non-zero if any failed.

If a download fails and the user wants LLM-driven triage ("this paper returned 403 — can you find the canonical URL?"), do it manually after the script completes. Step 3 itself does not auto-retry via Agents.

## Per-`kind` Strategy (handled by the script)

| kind | Tool | Output path |
|---|---|---|
| `paper` | `curl` (canonicalize arxiv `/abs/<id>` → `/pdf/<id>.pdf`) | `_inspiration/papers/<arxiv-id-or-slug>.pdf` |
| `repo` | `git clone --depth=1` | `_inspiration/<owner>/<repo>/` |
| `article` | `curl` (raw HTML) + `pandoc` (markdown, if installed) | `_inspiration/articles/<slug>/{raw.html,article.md}` |
| `docs` | `wget --recursive --level=2 --convert-links --no-parent --domains=<host>` | `_inspiration/docs/<domain-slug>/` |
| `other` | `curl` (raw) | `_inspiration/other/<slug>` |

## Per-Domain Rate Limits (handled by the script)

| Domain | Rate limit |
|---|---|
| `arxiv.org` | 1 request per 3 seconds (per their robots.txt) |
| `github.com` | None — gated by token rate limit, not interval |
| Generic | 1 request per 1 second per domain |

On failure: the script does exponential backoff (1s, 2s, 4s) up to 3 retries. Sources that exceed retries get `status: failed` with the error message captured in `notes`.

## Yaml Atomicity (handled by the script)

Parallel workers use `fcntl.flock(LOCK_EX)` (Unix) or a Python `threading.Lock` fallback (Windows) on the yaml file. Each worker reads → modifies one entry → writes back the full document, under the lock. Concurrent writes cannot corrupt the file.

## Inputs

- `_docs/research/downloads.yaml` (produced by Step 2)
- `_inspiration/.gitignore` (write-only; nested stub created idempotently)

## Output

- Files under `_inspiration/<kind>/<...>/`
- `_docs/research/downloads.yaml` updated:
  - `status: done` + `path` for each successful entry
  - `status: failed` + `notes` for failures
- `_inspiration/.gitignore` exists and contains `*` + `!.gitignore`

## Verification

- `_inspiration/.gitignore` exists and ignores everything except itself
- All `status: pending` entries are now `status: done` / `status: failed` / `status: skipped`
- `path` field is set on each `status: done` entry, and the file actually exists at that path
- yaml re-parses cleanly (no corruption)
- Script exits non-zero if any download failed

## Tool Prerequisites

The script depends on these being on PATH:

- `curl` — universal (pre-installed on macOS; `apt install curl` on Linux)
- `git` — universal
- `wget` — needed for `kind: docs` only; on macOS install via `brew install wget`
- `pandoc` — optional, used only for HTML → markdown conversion of articles. If missing, articles still save as raw HTML.
- Python 3.10+ with `pyyaml` (`pip install pyyaml`)

The script does not check for these at startup — first failure on an actual download will surface the missing dependency clearly.

## Pitfalls

- **Auth-gated content.** IEEE, ACM, paywalled journals require institutional login. The script will fail with 401/403 and mark `status: failed`; manually retry or mark `status: skipped` with `notes` explaining why. Don't change Step 3 to auto-handle auth — that's the user's call.
- **Repository sizes.** `git clone --depth=1` defaults to one branch with no history; some repos are still huge. The script does NOT enforce a `max_size_mb` — if you hit a giant repo, manually `rm -rf _inspiration/<owner>/<repo>/` and mark its yaml entry `status: skipped`.
- **Nested gitignore stub.** The 0.8 convention is `_inspiration/.gitignore` containing `*` + `!.gitignore` — directory contents auto-ignored, directory itself trackable. The script creates the stub only if missing; never touches the project's root `.gitignore`.
- **Robots.txt and ToS.** The script does NOT consult robots.txt. If a domain forbids crawling, the user is responsible for marking those entries `status: skipped` before re-running. *Hosted Deep Research outputs from Step 1.6 are the most likely source of such URLs — flag them when they appear.*
- **Wget for docs sites.** `wget --recursive --level=2` with `--no-parent` and `--domains=<host>` can still pull hundreds of files. If a docs site explodes the inspiration directory, set its yaml entry to `status: skipped` and document the alternative (often: just the homepage or table-of-contents page as `kind: article`).
- **Re-runs are idempotent.** Running the script twice on the same yaml is safe — already-`done` entries are skipped (the per-kind handlers check for existing files first). To force a re-download, manually set the entry back to `status: pending` and delete the existing file at `path`.
- **Misclassified entries.** Step 2's Haiku occasionally classifies `github.com/owner/repo/blob/main/file.py` as `kind: repo`; the script will then try `git clone` on a file URL and fail. Re-classify as `other` in the yaml and re-run — don't escalate the whole step.
- **Network flakiness.** Three retries with exponential backoff covers most transient failures. Persistent failures usually mean the URL is wrong, the source is paywalled, or the source is gone. Don't tune retries up — surface and triage.

## Why the Refactor (0.7.0-claude)

Previous versions of this skill spawned 5 LLM sub-agents to perform downloads. That was a holdover from Hermes's everything-is-an-LLM design. In Claude Code:

- Step 2 already classifies each URL by `kind` using Haiku — the LLM decision is done.
- The actual download work is `curl` / `git clone` / `wget` — no judgment, just dispatch.
- An LLM sub-agent per download is slow (per-item round-trip), expensive (tokens), and non-deterministic.

The script is the right shape: deterministic, parallel, cheap. The LLM dispatch pattern is preserved for steps that actually need judgment (Step 0 interactive, Step 1 brief drafting, Step 1.5 research, Step 1.6 hosted DR, Step 2 extraction, Step 4 summarization/indexing).
