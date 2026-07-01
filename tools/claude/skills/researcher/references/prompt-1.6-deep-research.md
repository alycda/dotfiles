# Step 1.6 — Hosted Deep Research Augmentation

Required in the Claude harness; previously optional under Hermes. Hosted Deep Research (Claude.ai, ChatGPT, Gemini browser apps) runs longer, follows deeper citation chains, and surfaces primary sources that Step 1.5's inline workers (built-in `WebSearch` + `WebFetch`) skim over.

## Why this step exists

The skill's adaptation from Hermes to Claude Code traded Hermes's `web_search` (Tavily/Firecrawl/Exa/Parallel/SearXNG backends, plus browser tool fallbacks, plus specialist `arxiv`/`blogwatcher`/etc. skills) for Claude Code's built-in `WebSearch` + `WebFetch`. Empirically, on a recent project (peer-to-peer RAG on Cactus + Ditto), the per-worker side-by-side was:

| Worker | CLI/inline (Mode B/C) | Hosted Deep Research |
|---|---|---|
| Claude | 43k bytes, ~103 URLs | 48k bytes, ~96 URLs (close to parity) |
| Codex / ChatGPT | 36k bytes, ~84 URLs | 35k bytes, ~29 URLs (inline denser; hosted's annotations richer) |
| Gemini | **8k bytes, ~31 URLs** | **63k bytes, ~86 URLs** (~8× depth gap) |

Hosted Deep Research consistently surfaces more specific, more recent primary sources with paragraph-length annotations. The Gemini CLI in particular is dramatically below its hosted counterpart. Step 1.6 closes that gap and is positioned as a *fourth pass* on top of Step 1.5's three CLI/inline workers — not a replacement.

## Procedure

### 1.6.0 — Skip Conditions

Skip Step 1.6 entirely if:

- The user passed `--skip-deep-research` (escape hatch for quick iterative runs)
- The brief frontmatter contains `internal_only: true` (hosted DR transmits to non-Anthropic providers; same constraint as Mode B's `--external`)
- All three `_docs/research/{claude,chatgpt,gemini}-deep-research.md` files already exist and are non-empty (re-run case)

In any skip case, log a clear warning that output quality will be noticeably below hosted DR — especially on breadth-of-citations tasks like the Gemini perspective — and proceed to Step 2.

### 1.6.1 — Emit WEB-PROMPT.md

Read `templates/web-prompt.md` and `RESEARCH-BRIEF.md`. Splice the brief body into the template's `<RESEARCH_BRIEF_BODY>` placeholder; replace `<PROJECT_NAME>` with the project's name (derived from `SEED.md` or directory name). Write the result to `WEB-PROMPT.md` at the project root.

The template wraps the brief with three additions that make Step 1.6 valuable as a *fourth* pass after Step 1.5's CLI workers:

1. **Meta-instruction at top.** Tells the hosted DR agent: "Three sibling research passes have already run this brief. Your job is to go deeper, hunt for gaps, and audit received wisdom."
2. **Bonus deliverable.** A "What the inline agents would have missed" section asking hosted DR to flag low-SEO repos, recent papers, conference talks without transcripts, and dissenting primary sources.
3. **URL conventions block.** Canonicalization rules (arXiv `/abs/<id>` no version, GitHub `owner/repo` no `/tree/<branch>`) so Step 2's dedupe lands cleanly across CLI and hosted outputs.

### 1.6.2 — Surface to User

Pause and tell the user:

> *"`WEB-PROMPT.md` has been written at the project root. Open it, copy from `---PROMPT START---` to `---PROMPT END---`, and paste into each of: Claude.ai Deep Research, ChatGPT Deep Research, Gemini Deep Research. Save each output to `_docs/research/{claude,chatgpt,gemini}-deep-research.md` respectively. Reply `continue` when at least one has landed, or `skip` to proceed without."*

Hosted DR runs typically take 10–30 minutes each. They can run in parallel in three browser tabs while the user does other work.

### 1.6.3 — Wait and Verify

On `continue`:

- Check for existence of `_docs/research/{claude,chatgpt,gemini}-deep-research.md`
- Warn loudly if any are missing (the user opted out of one provider — that's their call, not a hard fail)
- Verify each existing file is non-empty and contains a recognizable structure (heading + at least one URL)
- Proceed to Step 2

On `skip`: log the skip and proceed.

## Inputs

- `RESEARCH-BRIEF.md` (project root)
- `templates/web-prompt.md` (skill-bundled template)
- Step 1.5's outputs in `_docs/research/` (referenced in the meta-instruction so the hosted DR agent knows what's already been searched — this is the "go deeper" framing)

## Output

- `WEB-PROMPT.md` at the project root (the artifact for the user to paste)
- Up to three additional files in `_docs/research/`: `claude-deep-research.md`, `chatgpt-deep-research.md`, `gemini-deep-research.md`

## Verification

- `WEB-PROMPT.md` exists and contains both `---PROMPT START---` and `---PROMPT END---` markers
- After user confirmation, at least one `*-deep-research.md` file exists in `_docs/research/`
- Each `*-deep-research.md` file is non-empty
- Combined URL count across all `_docs/research/*.md` files is substantially higher than Step 1.5 alone (sanity check)

## Pitfalls

- **Skipping silently.** If `--skip-deep-research` becomes the user's default, output quality will degrade across runs without anyone noticing. The skip must always log a clear warning, never silently.
- **Arxiv ID hallucination.** Hosted Deep Research is known to invent plausible-looking arXiv IDs that don't resolve. Step 3's download phase will fail loudly on a 404 — that's the natural check. Don't manually verify every cite in Step 1.6; let Step 3 catch them. Flag arxiv IDs dated after the current month as suspicious.
- **Stale brief.** If the user iterated on `RESEARCH-BRIEF.md` between Step 1.5 and Step 1.6, the WEB-PROMPT.md emitted here reflects the *current* brief, but the CLI workers in `_docs/research/{claude,codex,gemini}.md` ran on the *previous* brief. Usually fine (hosted DR runs against the latest), but worth noting if the diff is large.
- **Three browser tabs is a lot.** Some users will only run one or two of the three hosted DR providers. Accept that — one hosted pass is still better than zero. The verification should warn, not hard-fail, on missing files.
- **`internal_only: true` interaction.** Same as Mode B's `--external` constraint: if the brief was authored with internal anchors preserved, refuse to emit WEB-PROMPT.md and tell the user to either sanitize the brief or skip Step 1.6 with the `--skip-deep-research` flag.
- **Don't re-run CLI workers in this step.** Step 1.6 is purely a hosted-DR augmentation. If the user wants to re-run Step 1.5's CLI/inline workers, they should run `/researcher research` separately.
- **Citation overlap is fine.** Hosted DR will often re-cite the same canonical sources that the CLI workers found. That's expected — Step 2's yaml upsert deduplicates by URL and tracks `cited_in` membership across all six files. The value of Step 1.6 is not the overlap but the long tail of deeper, more specific sources.

## Setup Note

No setup required. Step 1.6 produces a file and waits for the user — no external tooling, no API keys, no CLIs. Hosted DR access is assumed via the user's existing Claude.ai / ChatGPT / Gemini subscriptions.
