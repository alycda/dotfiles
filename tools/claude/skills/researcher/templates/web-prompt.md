# Deep-Research Prompt — <PROJECT_NAME>

> **How to use this file**
>
> Step 1.5's inline workers (Claude Agent, Codex CLI, Gemini CLI) have already executed `RESEARCH-BRIEF.md` and dropped their findings in `_docs/research/{claude,codex,gemini}.md` (or `{theory,tooling,industry}.md` for Mode C). This prompt is for a fourth, hosted deep-research pass in a browser — **Claude.ai Deep Research**, **ChatGPT Deep Research**, or **Gemini Deep Research** — to catch what the inline workers skimmed over. Hosted Deep Research runs longer, follows deeper citation chains, and tends to surface primary sources (specific arXiv papers, low-SEO repos, conference talks with video) that first-pass agents miss.
>
> **Copy everything between the `---PROMPT START---` and `---PROMPT END---` lines. Paste into the deep-research tool of your choice. Save the returned report to `_docs/research/{claude,chatgpt,gemini}-deep-research.md` (whichever tool ran it) — Step 2 will pick it up alongside the inline workers' outputs.**

---PROMPT START---

You are a deep-research agent. Execute the research brief below and return the deliverables in the format specified. Cite primary sources (arXiv DOI, repo URL + commit/tag, official docs URL). Skip blog rehashes unless they point to a primary source we would otherwise miss.

**Important context for this run:** three sibling research passes (Claude Agent via Claude Code, OpenAI Codex CLI, Google Gemini CLI) have already executed the same brief using their built-in web search. Your value as the fourth pass is to:

1. **Go deeper.** You have more time and a longer citation chain. Find the primary sources the inline agents skimmed over — the actual arxiv PDFs, GitHub commits, the specific docs pages, the original conference talks (with video links).
2. **Hunt for gaps.** The four areas where inline agents tend to underperform: (a) papers from the last 18 months on niche topics, (b) engineering blog posts from teams that built the thing (vs. summarizers), (c) GitHub repos with low SEO but high signal, (d) conference talks with video that haven't been transcribed.
3. **Adversarially audit the obvious answers.** Where the field has converged on a "received wisdom" answer, find the dissenting primary source if one exists.

Mark anything you find that you suspect would not surface in an inline agent's first pass.

---

<RESEARCH_BRIEF_BODY>

---

## Required Deliverables (this run)

Return a single Markdown document with these sections:

1. **Top 10 must-read sources** — ranked, with one-paragraph annotations. These are the things every engineer joining this project should read first.
2. **Per-topic findings** — one section per Research Task in the brief. Include sources (URL + author + date), a 2–3 sentence "what it gives us", and an explicit "gap" line (what it does *not* solve for our case).
3. **Tool shortlist** — concrete decisions, repo URL, last-release date, license, maintenance health (commits in last 90 days, open-issue trend), platform support matrix, and a one-sentence "use it / don't / maybe + why."
4. **Reference architectures** — 2–5 projects whose layout, pipeline, or demo shape we should mimic or steal from. Link to specific files/dirs.
5. **Open research questions** — things you searched for and *couldn't* find good prior art on. These are real gaps and tell us where we will have to invent.
6. **Source ledger** — flat deduplicated list of every URL you cite, one per line, no commentary. This is consumed by a downstream automation step.

**Bonus section for this run (the human-driven Deep Research pass):**

7. **"What the inline agents would have missed"** — at the end, a short numbered list of sources or findings you suspect would not appear in a first-pass agent search (low-SEO repos, recent papers, conference talks without transcripts, dissenting primary sources, deep-citation-chain finds). One sentence each on *why* it's underexposed.

## URL conventions

- arXiv: canonicalize to `https://arxiv.org/abs/<id>` with no version suffix (no `/v2`, `/v3`).
- GitHub: canonical `https://github.com/owner/repo` (no `/tree/<branch>` unless the branch is load-bearing).
- Official docs: prefer the most stable canonical URL.

These conventions are mandatory — the downstream automation step deduplicates URLs across all `_docs/research/*.md` outputs, so an `arxiv.org/abs/2406.12345v2` cite from your run will appear as a separate row from an `arxiv.org/abs/2406.12345` cite in a sibling output.

---PROMPT END---

## After you receive the report

1. Save it as `_docs/research/{claude,chatgpt,gemini}-deep-research.md` — name it after the tool you used. Step 2 (download manifest) will pick it up alongside the inline workers' outputs.
2. If the deep-research tool returned the output split across multiple files or chats, concatenate before saving — Step 2 expects one file per researcher.
3. The output is additive. Duplicates with the inline workers are fine — Step 2's yaml upsert deduplicates URLs and tracks `cited_in` membership across all six files.
4. Reply `continue` to the skill when at least one `*-deep-research.md` file has landed, or `skip` to proceed without it (warned — output quality will be lower, especially on Gemini-style breadth tasks).
