# Changelog

All notable changes to the `researcher` skill.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Versioning scheme:
- Pre-`0.5.0` versions are the upstream Hermes line, maintained at `~/.hermes/skills/research/researcher/`.
- `0.5.0-claude` and later are the Claude Code fork; the `-claude` suffix marks the lineage.
- History before `0.4.0` is not tracked here — earlier iterations existed on the Hermes line but the entries pre-date this fork.

## [0.8.0-claude] — 2026-05-22

### Changed
- **Output directories renamed** to align with the `alycda/project` template's `_*` "local-only" convention.
  - `docs/research/` → `_docs/research/` (the entire Step 1.5 / 1.6 / 2 / 4 output tree)
  - `inspiration/` → `_inspiration/` (Step 3 download target)
- **Gitignore strategy switched from "append to root `.gitignore`" to "nested gitignore stub."** Step 3's `scripts/download.py` now creates `_inspiration/.gitignore` with `*` + `!.gitignore` if absent, instead of mutating the project root `.gitignore`. The nested stub keeps `_inspiration/` trackable as a directory while ignoring all its contents — and the project root `.gitignore` is left alone.
- All references in `SKILL.md`, `references/prompt-1.5-execute-research.md`, `prompt-1.6-deep-research.md`, `prompt-2-download-manifest.md`, `prompt-3-download.md`, `prompt-4-semantic-index.md`, `exemplar-research-brief.md`, `strongdm-techniques.md`, `strongdm-products.md`, `templates/web-prompt.md`, `templates/downloads.yaml.example`, and `scripts/download.py` updated to the new paths.

### Migration
- Existing projects with the old `docs/research/` and `inspiration/` paths continue to work — the new skill doesn't delete the old layout. To migrate an existing project: `mv docs/research _docs/research && mv inspiration _inspiration && rm -rf _inspiration/.gitignore || true && printf '*\n!.gitignore\n' > _inspiration/.gitignore`, then prune the now-redundant `inspiration/` line from the project's root `.gitignore` if it's there.
- No data is at risk: the rename is purely a path move; downloads, reports, and the index all retain their structure.

### Rationale
- The `alycda/project` template treats `_<name>/` as the canonical signal for "local-only, not for remote tracking." Researcher outputs (deep-research reports, downloads, the index) are project dev-trail artifacts that the user typically wants on disk but rarely worth pushing to a public repo — they belong under `_docs/`. Inspiration downloads (cloned repos, papers, articles) are the same plus much larger — `_inspiration/` with a nested stub keeps them entirely off the remote without touching the project's root `.gitignore`.
- Nested gitignore stubs compose better than root-level entries: they survive squash merges of disparate work, don't conflict with downstream `.gitignore` edits, and self-document the directory's intent.

## [0.7.0-claude] — 2026-05-21

### Changed
- **Step 3 (Download Materials) rewritten from Agent sub-agents to a Python script.** Downloads are mechanical (`curl` / `git clone` / `wget`) and require no LLM judgment — `kind` is already decided by Step 2. The skill now invokes `scripts/download.py` via a single Bash call instead of spawning 5 LLM sub-agents. Speeds up Step 3 dramatically, makes it deterministic, eliminates per-download token spend, and makes re-runs cheap and idempotent.
- `references/prompt-3-download.md` rewritten to document the script-based dispatch.

### Added
- `scripts/download.py` — parallel download orchestrator with per-domain rate limiting (arxiv 3s, generic 1s), atomic yaml updates via `fcntl.flock` (with a Windows in-process-lock fallback), exponential backoff retries (3 attempts max), and idempotent re-runs (skips entries with existing files).

### Notes
- LLM dispatch in the pipeline is now: Step 0 (interactive Q&A), Step 1 (research brief drafting), Step 1.5 (CLI / Agent workers), Step 1.6 (hosted DR — human-driven), Step 2 (Haiku extraction), Step 4 (Agent MapReduce). Step 3 is script-only.
- Step 4 (Semantic Index) stays Agent-based — per-source summarization, tagging, and density scoring are real LLM judgment.

## [0.6.0-claude] — 2026-05-21

### Added
- **Step 1.6 (Hosted Deep Research Augmentation)** — new *required* step in the Claude harness. Emits `WEB-PROMPT.md` at the project root, waits for the user to run it through Claude.ai Deep Research, ChatGPT Deep Research, and Gemini Deep Research browser apps, and ingests the returned `{claude,chatgpt,gemini}-deep-research.md` outputs into `docs/research/`.
- `references/prompt-1.6-deep-research.md` — Step 1.6 procedure, with the empirical comparison table that justifies the requirement.
- `templates/web-prompt.md` — templated prompt for hosted DR, with meta-instruction telling the DR agent that three CLI/inline passes already ran (so its value is "go deeper").
- `--skip-deep-research` flag (escape hatch for quick iterative runs) and `/researcher web-prompt` standalone command.
- Hosted DR access row in the Inputs table.

### Changed
- `prompt-2-download-manifest.md` now ingests up to six input files (3 CLI/inline + 3 hosted DR), with `cited_in` tracking membership across all of them.

### Added (Pitfalls)
- Silent skip of Step 1.6 — must always warn.
- Hosted DR arxiv ID hallucination — Step 3's 404 is the natural check.
- `internal_only: true` and hosted DR — refuse to emit `WEB-PROMPT.md`.

### Rationale
Empirical comparison on a recent project (P2P RAG on Cactus + Ditto) showed Claude Code's built-in `WebSearch` undershoots hosted Deep Research significantly — most dramatically for the Gemini perspective (8k bytes / 31 URLs vs 63k / 86 URLs; ~13% of depth). Step 1.6 closes that gap as a fourth pass on top of Step 1.5's three inline workers.

## [0.5.0-claude] — 2026-05-21

### Changed
- **Forked from upstream Hermes line.** Skill rewritten for Claude Code as the harness instead of Hermes.
- **Step 1.5 Mode B (cross-provider)** now uses sibling `codex` and `gemini` CLIs invoked via Bash, matching the pattern used by `sprint-planner` / `sprint-retrospective` / `sprint-execute`. Replaces `hermes -p <profile> chat`.
- **Step 1.5 Mode C (Claude-only multi-perspective)** now uses the Agent tool with `subagent_type=general-purpose`. Replaces Hermes `delegate_task`.
- **Step 2 (Download Manifest)** now uses the Agent tool with `model: "haiku"` for cost-optimized structured extraction. Replaces `hermes -p writer chat`.
- Web search/fetch uses Claude Code's built-in `WebSearch` and `WebFetch`. No backend configuration required.
- `references/hermes-profile-setup.md` replaced with `references/cli-setup.md` (codex / gemini CLI install + auth).

### Removed
- Hermes-specific `metadata.hermes` frontmatter.
- Specialist research skills auto-discovery (`arxiv`, `polymarket`, `blogwatcher`, `llm-wiki`) — these don't exist in Claude Code; workers rely on WebSearch + WebFetch as the universal toolset.
- `web_search` backend preflight (Tavily / Firecrawl / Exa / Parallel / SearXNG) — irrelevant; WebSearch is built-in.

### Notes
- All `references/prompt-*.md` files updated to remove Hermes-specific tool references.
- `references/exemplar-*.md`, `references/strongdm-*.md`, `templates/downloads.yaml.example`, `templates/seed-skeleton.md` unchanged from 0.4.

## [0.4.0] — 2026-05-11 (upstream Hermes; last pre-fork version)

> Maintained at `~/.hermes/skills/research/researcher/`. This was the last version before the Claude Code fork.

### Added
- `writer` profile (Haiku 4.5) for Step 2 dispatch — ~5× cheaper than Sonnet for structured extraction with no measurable quality regression.
- Step 1.5.0 preflight: verify `web_search` backend is configured (Tavily / Firecrawl / Exa / Parallel / SearXNG); without one the Anthropic worker silently falls back to training-corpus knowledge.
- Mode C `delegate_task` calls now pass explicit toolsets (`["web", "browser", "file"]`) so browser fallbacks work for resistant sources.
- Specialist research skills recommended when relevant: `arxiv`, `polymarket`, `blogwatcher`, `llm-wiki` from `~/.hermes/skills/research/`.

### Added (Pitfalls)
- Web backend silently missing — Anthropic worker only; Codex / Gemini are unaffected because they use provider-native browsing.
- Mode C toolset and skill visibility — renaming `~/.hermes/skills/research/*` silently disables the augmentation.

### Notes
- Codex and Gemini workers unaffected by the `web_search` backend issue (they use provider-native browsing).
- This version was migrated to `~/.claude/skills/researcher/` and then rewritten as `0.5.0-claude` — see that entry for the diff.

---

*Pre-`0.4` history not tracked. The skill was iterated on the StrongDM Software Factory pattern; earlier versions existed on the Hermes line but their changelogs are lost.*
