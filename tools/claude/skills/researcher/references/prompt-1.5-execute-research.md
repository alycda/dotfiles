# Step 1.5 — Execute Research (Multi-Researcher)

Originally a manual web-browser step (run the brief through Claude/ChatGPT/Gemini Deep Research, paste outputs into `_docs/research/`); this skill runs it inside Claude Code via the Agent tool and sibling CLIs.

## Architecture: Two Modes

**Mode B (cross-provider diversity)** — Three independent workers across three vendors: a Claude Agent sub-agent, a `codex` CLI invocation, and a `gemini` CLI invocation, orchestrated as parallel Bash + Agent calls in the same turn. True vendor diversity. Requires user opt-in via `--external` flag because the brief is sent to non-Anthropic providers.

**Mode C (Claude-only multi-perspective)** — Three Agent sub-agents on the parent's Claude model with different perspective prompts (theory / tooling / industry). Diversity from prompt perspective, not model. Safe by default — nothing leaves Claude.

Agent sub-agents inherit the parent's model unless overridden via the `model:` parameter. There is no built-in cross-vendor option through the Agent tool; cross-provider diversity therefore requires invoking sibling CLIs directly (Mode B).

## Procedure

### 1.5.0 — Preflight

Quick sanity checks before dispatching workers:

- **Mode C:** none beyond confirming the Agent tool is available (it always is in Claude Code).
- **Mode B:** confirm both `codex` and `gemini` are on PATH and authenticated.

```bash
command -v codex >/dev/null 2>&1 || echo "codex CLI not installed; see references/cli-setup.md"
command -v gemini >/dev/null 2>&1 || echo "gemini CLI not installed; see references/cli-setup.md"
```

If either is missing in Mode B, fall back to Mode C and tell the user. Don't silently run with two workers — three is the design.

### 1.5.1 — Determine Mode

```
If invoked with --external:
  If brief frontmatter contains internal_only: true:
    Refuse — surface to user, suggest writing a sanitized brief or running Mode C
  Confirm brief has no sensitive company info (interactive prompt — see 1.5.2)
  Check that codex and gemini CLIs are on PATH
  If both present: Mode B
  Else: fall back to Mode C and point at references/cli-setup.md
Else (no --external flag):
  Mode C (default — safe, no external dispatch)
```

### 1.5.2 — `--external` Consent Prompt

Before Mode B begins, the skill MUST prompt the user explicitly:

> *"Mode B sends the research brief to Codex (OpenAI) and Gemini (Google) CLIs. The brief at `RESEARCH-BRIEF.md` will be transmitted as-is to both providers. Confirm it contains NO sensitive company information: ticket IDs, customer names, internal incident IDs, unreleased product details, or proprietary architecture specifics. Type 'yes, sanitized' to continue, or 'no' to fall back to Mode C."*

If the user types anything other than the exact phrase `yes, sanitized`, fall back to Mode C.

### 1.5.3 — Worker Tool Loadout

Applies to both modes. Workers reach for `WebSearch` first and fall back to `WebFetch` for specific URLs that need direct retrieval.

**Domain hints for the worker prompts:**

| Brief mentions | Worker should | Why |
|---|---|---|
| arXiv IDs, "paper", "preprint" | Canonicalize to `arxiv.org/abs/<id>` (no version); WebFetch the abs page | Stable canonical URL for Step 2 dedupe |
| Specific repos by URL | WebFetch `github.com/owner/repo` for README; capture canonical URL and default branch | Step 3 will clone; Step 2 needs the canonical URL |
| Blog posts and team postmortems | WebSearch first, then WebFetch the target | WebSearch alone often returns summaries; WebFetch retrieves full text |
| LLM model specs | WebSearch vendor docs directly (anthropic.com/news, openai.com/blog, deepmind.google) | Avoid second-hand summaries |

There's no equivalent of Hermes's specialist `arxiv`, `polymarket`, `blogwatcher`, `llm-wiki` skills in Claude Code — workers rely on WebSearch + WebFetch as the universal toolset. For prediction-market or RSS-feed research, the worker should call out in its output that a more direct API would be preferable for a future re-run.

### 1.5.4 — Mode B Execution (Cross-Provider)

Run three workers in parallel — in the **same orchestrator turn** so they actually run concurrently:

| Worker | Mechanism | Output file |
|---|---|---|
| Claude | Agent tool, `subagent_type=general-purpose` | `_docs/research/claude.md` |
| Codex | Bash: `codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"` | `_docs/research/codex.md` |
| Gemini | Bash: `gemini -y -p "<prompt>"` | `_docs/research/gemini.md` |

The codex and gemini CLI invocations write their output via their own file tools — the Bash call's stdout is just status. The Claude worker writes via its Write tool.

Each worker is told to:

- Read `RESEARCH-BRIEF.md` from the current working directory
- Execute the research using its own web-search capabilities (built-in WebSearch for Claude; provider-native browsing for codex/gemini)
- Write structured findings to `_docs/research/<NAME>.md`
- Confirm completion in its output (so the orchestrator can verify)

**Worker prompt template** (substitute `<NAME>` per worker — `claude`, `codex`, or `gemini`):

> Read `RESEARCH-BRIEF.md` from the current directory. Execute the research per the brief — search the web, follow up on cited sources, and synthesize findings. When the brief mentions arXiv papers, canonicalize URLs to `arxiv.org/abs/<id>` (no version suffix). When it mentions specific repos, capture the canonical `github.com/owner/repo` URL. Write your final structured findings to `_docs/research/<NAME>.md` following the deliverables specified in the brief (Top N must-reads with annotations, per-topic findings with "what it gives us"+"gap" lines, tool shortlist, reference architectures, open research questions, source ledger as a flat URL list). End with a confirmation line that you wrote the file.

The orchestrator should construct this prompt dynamically (not paste a fixed snippet) because brief-specific anchors may want to be inlined.

**Verified non-interactive invocations** (do not second-guess; these are the flags that make the CLIs usable as workers):

- `codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"`
- `gemini -y -p "<prompt>"`

### 1.5.5 — Mode C Execution (Claude-Only Multi-Perspective)

Three parallel Agent tool calls in the same orchestrator turn. Diversity comes from the perspective each is given:

| Sub-agent | Perspective | Output file |
|---|---|---|
| Theory | Academic papers, formal verification, conference proceedings (USENIX, OSDI, PLDI, POPL), arXiv preprints | `_docs/research/theory.md` |
| Tooling | Repos, libraries, CI patterns, language-specific implementations, package ecosystems | `_docs/research/tooling.md` |
| Industry | Postmortems, team blog posts, conference talks with video, engineering memos | `_docs/research/industry.md` |

Use `subagent_type=general-purpose` (it has WebSearch, WebFetch, Read, Write). Each Agent call sends a `description` and `prompt`:

> Read `RESEARCH-BRIEF.md` from the project root. You are the **{PERSPECTIVE}** researcher — focus exclusively on {scope description}. Skip anything outside your scope. Use WebSearch for discovery, WebFetch when you need full text from a specific URL. Write findings to `_docs/research/{output-file}.md` following the brief's deliverables (Top N must-reads with annotations, per-topic findings with "what it gives us"+"gap" lines, tool shortlist, reference architectures, open research questions, source ledger as a flat URL list). End with a confirmation that you wrote the file.

All three sub-agents inherit Claude as the model; nothing leaves the provider boundary.

### 1.5.6 — Wait and Verify

In both modes:

- Wait for all three workers to complete (parallel Bash + Agent calls return when their callees finish)
- Verify each output file exists at the expected path and is non-empty
- Verify each contains a "Source ledger" section (or equivalent flat URL list)
- Surface failures (rate limits, timeouts, auth errors) to the user; do NOT auto-retry

## Output

| Mode | Files produced |
|---|---|
| Mode B | `_docs/research/claude.md`, `_docs/research/codex.md`, `_docs/research/gemini.md` |
| Mode C | `_docs/research/theory.md`, `_docs/research/tooling.md`, `_docs/research/industry.md` |

Format depends on the brief; typically:

- Top N must-read sources
- Per-topic findings (with "what it gives us" + "gap" annotations)
- Tool shortlist
- Reference architectures
- Open research questions
- Source ledger (flat URL list — required)

## Verification

- Three output files exist at expected paths
- Each file has a Source ledger section
- Aggregate URL count across all files is >0
- For Mode B: each file's content reflects its provider (e.g., `codex.md` shouldn't be obviously written in Claude's voice — light sanity check that orchestration actually invoked the sibling CLI rather than falling back)

## Pitfalls

- **Skipping the consent prompt in Mode B.** Hard requirement. Do not auto-confirm even if the user passed `--external`. The phrase-confirmation gate exists because briefs naturally contain sensitive context unless deliberately sanitized.
- **`internal_only: true` and `--external`.** If the brief was authored with internal anchors preserved, refuse Mode B outright. Surface the conflict and ask whether the user wants to author a sanitized version or run Mode C.
- **CLI-not-found errors.** If `codex` or `gemini` isn't on PATH, fall back to Mode C and log the missing CLI. Don't silently use only two workers in Mode B — three is the design.
- **Endpoint-specific refusals.** Codex and Gemini may refuse certain research topics. Surface refusals; don't silently swallow.
- **Parallel rate limits within Claude.** Three Agent sub-agents in Mode C run against the same Anthropic credential pool. The Agent tool handles transient rate-limit retry internally; if you see persistent failures, stagger the calls (uncommon).
- **Output naming collisions.** Step 2 reads `_docs/research/*.md` — if a Mode B run is followed by a Mode C run on the same project, both sets of files coexist and Step 2 will dedupe URLs across all of them. That's intentional, but if a user wants a clean rerun, clear the directory first.
- **WebSearch vs. hosted Deep Research.** WebSearch is good but not equivalent to a multi-hour hosted Deep Research session. For projects where deeper browsing is needed, the user can hybrid: run the brief through hosted tools (Claude.ai Deep Research, ChatGPT Deep Research, Gemini Deep Research) and drop those outputs into `_docs/research/` manually before Step 2. The yaml upsert in Step 2 handles iteration.
- **Brief-quality bottleneck.** Mode B's diversity is wasted if the brief is vague — three providers will return three different flavors of mediocre. Tighten the brief if outputs consistently feel thin.
- **CLI worker writes to wrong path.** Codex and Gemini have their own file-write tools and respect the current working directory at invocation. The orchestrator must `cd` into the project root before spawning Bash workers (or pass an absolute path in the prompt) — otherwise the worker may write to `~/_docs/research/codex.md` or similar.

## Setup Note

If Mode B is desired but CLIs aren't installed, point the user at `references/cli-setup.md` for one-time install + auth. After that's done, Mode B is available for every future run.
