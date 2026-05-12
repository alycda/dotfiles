# Step 1.5 — Execute Research (Multi-Researcher)

The step Hermes uniquely enables. Historically a manual web-browser step (run the brief through Claude/ChatGPT/Gemini Deep Research, paste outputs into `docs/research/`); Hermes runs it from the CLI.

## Architecture: Two Modes

**Mode B (cross-provider diversity)** — Three independent Hermes profiles, each with a different provider. Orchestrated via `terminal` (`hermes -p <profile> chat -q ...` in parallel). True vendor diversity. Requires user opt-in via `--external` flag because the brief is sent to non-Anthropic providers.

**Mode C (Anthropic-only multi-perspective)** — Single profile (default). Orchestrated via `delegate_task`. Three sub-agents inherit the parent's Anthropic provider but get different system prompts (theory / tooling / industry). Diversity from prompt perspective, not model. Safe by default — nothing leaves Anthropic.

Hermes's `delegate_task` does NOT support per-call provider override (sub-agents inherit the parent's provider). Cross-provider diversity therefore requires profile-level orchestration, not in-process sub-agents.

## Procedure

### 1.5.0 — Preflight: Verify Web Backend

**Critical:** Hermes's `web_search` / `web_extract` tools require a backend API key (Firecrawl, Tavily, Exa, Parallel, or self-hosted SearXNG). Without one, the entire `web` toolset silently fails to load — delegated workers spawn with empty web tooling and fall back to training-corpus knowledge.

Codex and Gemini worker profiles use their provider's **native** browsing/grounding (Codex's API + Gemini's Code Assist), so they work even without a Hermes web backend. The **Anthropic / Claude worker is the one that fails silently** — it routes through Hermes's `web_search`, which needs the backend.

**Before dispatching workers, check:**

```bash
# Are any of these env vars set in ~/.hermes/.env?
grep -E '^(FIRECRAWL_API_KEY|TAVILY_API_KEY|EXA_API_KEY|PARALLEL_API_KEY|SEARXNG_URL)' ~/.hermes/.env
# Or check via hermes:
hermes tools | grep -A1 web_search
```

If none is set, surface to the user:

> *"Hermes web_search requires a backend API key. Without one, the Claude worker will fall back to training-corpus knowledge instead of doing live fetches — codex and gemini will still work because their providers have native browsing. Options: (1) configure a backend now, (2) proceed knowing the claude.md output will be lower-quality, or (3) abort."*

If user picks (1), point them at the setup instructions in `references/hermes-profile-setup.md` (Web Backend section). If (2), proceed and add a clear note at the top of `docs/research/claude.md` that the claude worker ran without live web access. If (3), stop.

### 1.5.1 — Determine Mode

```
If invoked with --external:
  Confirm brief has no sensitive company info (interactive prompt — see 1.5.2)
  Check for required profiles via `hermes profile list`
  If researcher-codex AND researcher-gemini exist: Mode B
  Else: error — instruct user to run setup from references/hermes-profile-setup.md
Else (no --external flag):
  Mode C (default — safe, no external dispatch)
```

### 1.5.2 — `--external` Consent Prompt

Before Mode B begins, the skill MUST prompt the user explicitly:

> *"Mode B sends the research brief to Codex (OpenAI) and Gemini (Google) profiles. The brief at `RESEARCH-BRIEF.md` will be transmitted as-is to both providers. Confirm it contains NO sensitive company information: ticket IDs, customer names, internal incident IDs, unreleased product details, or proprietary architecture specifics. Type 'yes, sanitized' to continue, or 'no' to fall back to Mode C."*

If the user types anything other than the exact phrase `yes, sanitized`, fall back to Mode C.

### 1.5.3 — Worker Tool Loadout

Applies to both modes. Workers should reach beyond generic `web_search` when the brief makes a specialist tool obviously better, and should have explicit fallbacks when `web_search` itself can't reach a source.

**Specialist skills (use when the brief mentions the relevant domain):**

| Brief mentions | Use skill | Why |
|---|---|---|
| arXiv IDs, "paper", "preprint", academic conferences | `arxiv` | Date / category / ID-aware ranking that no general search backend matches |
| Prediction markets, calibrated forecasts, Polymarket | `polymarket` | Direct API; generic crawlers can't see live odds |
| RSS feeds, blog watchers, ongoing posts from a team | `blogwatcher` | Feed-aware fetching with diff-since-last-run semantics |
| LLM model specs, capabilities, training details | `llm-wiki` | Curated model index; faster than scraping vendor pages |

Specialist skills are best-effort augmentations — if a skill call fails or no skill is applicable, fall back to `web_search`. Don't burn budget reaching for a specialist skill when generic search would do.

**Resistant-source fallbacks (use when `web_search` returns nothing useful):**

1. `browser_navigate` + `browser_snapshot` for JS-heavy SPAs that `web_search` can't render.
2. `browser_vision` for image-heavy pages (PDFs embedded as images, screenshots of dashboards).
3. `scrapling` (optional skill — install via `hermes skills install scrapling`) for anti-bot sites that block headless browsers.

The order is intentional: cheapest tools first. Don't reach for `scrapling` until plain browser tools have failed.

**Mode B parity note:** Codex and Gemini workers won't have these tools at parity — specialist skills aren't installed in worker profiles by default, and provider-native browsing differs from Hermes browser tools. Workers should attempt the specialist skill, log the failure if absent, and fall back to provider-native browsing.

### 1.5.4 — Mode B Execution (Cross-Provider)

Use the `terminal` tool to run three `hermes -p <profile> chat -q ...` invocations in parallel. Each worker profile is instructed to:

- Read `RESEARCH-BRIEF.md` from the project root
- Execute the research using its own web-search capabilities
- Write structured findings to `docs/research/<researcher-id>.md` (using its own file-write tool)
- Confirm completion in stdout

Default profile assignments:

| Worker profile | Provider | Output file |
|---|---|---|
| (default — anthropic) | claude-opus-4-6 (or current main) | `docs/research/claude.md` |
| `researcher-codex` | codex | `docs/research/codex.md` |
| `researcher-gemini` | gemini (API-key path preferred) | `docs/research/gemini.md` |

Orchestration shape:

```bash
# Run all three in parallel; wait for completion.
# Each worker writes its OWN file via its file tool — stdout is just status.

WORKER_PROMPT='Read RESEARCH-BRIEF.md from the current directory. Execute the research per the brief. Default to web_search; when the brief mentions arXiv papers, prediction markets, blog feeds, or LLM model specs, prefer the matching specialist skill (arxiv / polymarket / blogwatcher / llm-wiki) when available, falling back to web_search if the skill is absent. When web_search returns nothing useful, escalate to browser_navigate+browser_snapshot, then browser_vision for image-heavy pages, then scrapling for anti-bot sites — cheapest tools first. Write your final structured findings to docs/research/<NAME>.md following the deliverables specified in the brief (Top N must-reads with annotations, per-topic findings with "what it gives us"+"gap" lines, tool shortlist, reference architectures, open research questions, source ledger). End with a confirmation that you wrote the file.'

(hermes chat -q "${WORKER_PROMPT//<NAME>/claude}" 2>&1 | tee logs/claude-worker.log) &
(hermes -p researcher-codex chat -q "${WORKER_PROMPT//<NAME>/codex}" 2>&1 | tee logs/codex-worker.log) &
(hermes -p researcher-gemini chat -q "${WORKER_PROMPT//<NAME>/gemini}" 2>&1 | tee logs/gemini-worker.log) &
wait
```

The skill SHOULD construct this shell command dynamically, not paste a fixed snippet — profile names may vary, prompt content may need adjustment per project.

### 1.5.5 — Mode C Execution (Anthropic-Only Multi-Perspective)

Use `delegate_task` with three parallel sub-agents on the parent's Anthropic provider. Diversity comes from system-prompt perspective:

```
delegate_task(tasks=[
    {
        "goal": "Execute the research brief from RESEARCH-BRIEF.md as a THEORY researcher",
        "context": "Focus on academic papers, formal verification work, conference proceedings (USENIX, OSDI, PLDI, POPL), arxiv preprints. Skip blog posts and tooling. Prefer the `arxiv` skill for paper lookups. Fall back to browser_navigate/browser_snapshot when web_search returns nothing useful; browser_vision for image-heavy pages (scanned PDFs, slide decks). Write your findings to docs/research/theory.md following the brief's deliverable spec.",
        "toolsets": ["web", "browser", "file"]
    },
    {
        "goal": "Execute the research brief from RESEARCH-BRIEF.md as a TOOLING researcher",
        "context": "Focus on repos, libraries, CI patterns, language-specific implementations, package ecosystems. Skip pure-theory papers. Prefer the `llm-wiki` skill when the brief touches LLM model specs. Fall back to browser tools (then scrapling, if installed) for sites that block web_search. Write your findings to docs/research/tooling.md.",
        "toolsets": ["web", "browser", "file"]
    },
    {
        "goal": "Execute the research brief from RESEARCH-BRIEF.md as an INDUSTRY researcher",
        "context": "Focus on postmortems, blog posts from teams that built the thing, conference talks with video, engineering memos. Skip academic papers and library docs. Prefer `blogwatcher` for team-blog tracking and `polymarket` when the brief touches prediction markets. Fall back to browser tools for paywalled or JS-heavy industry sites. Write your findings to docs/research/industry.md.",
        "toolsets": ["web", "browser", "file"]
    }
])
```

All three sub-agents inherit Anthropic from the parent; nothing leaves the provider boundary.

### 1.5.6 — Wait and Verify

In both modes:

- Wait for all three workers to complete
- Verify each output file exists at the expected path and is non-empty
- Verify each contains a "Source ledger" section (or equivalent flat URL list)
- Surface failures (rate limits, timeouts, auth errors) to the user; do NOT auto-retry

## Output

| Mode | Files produced |
|---|---|
| Mode B | `docs/research/claude.md`, `docs/research/codex.md`, `docs/research/gemini.md` |
| Mode C | `docs/research/theory.md`, `docs/research/tooling.md`, `docs/research/industry.md` |

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
- For Mode B: each file's content reflects its provider (e.g., `codex.md` shouldn't be obviously written in Claude's voice — light sanity check that orchestration worked)

## Pitfalls

- **Web toolset silently empty.** Hermes's `web` toolset only loads if a backend is configured (Firecrawl / Tavily / Exa / Parallel / SearXNG). Pre-flight check is mandatory — see Step 1.5.0. Codex/Gemini workers work without it because their providers have native browsing; the Anthropic worker does not.
- **Skipping the consent prompt in Mode B.** This is a hard requirement. Do not auto-confirm even if the user passed `--external`. The phrase-confirmation gate exists because briefs naturally contain sensitive context unless deliberately sanitized.
- **Profile-not-found errors.** If `researcher-codex` or `researcher-gemini` doesn't exist, fall back to Mode C and log the missing profile. Don't silently use only two workers in Mode B — three is the design.
- **Endpoint-specific refusals.** Codex and Gemini may refuse certain research topics. Surface refusals; don't silently swallow.
- **Parallel rate limits within a single profile.** If you re-use the default profile (anthropic) for two workers in any mode, you'll trip Anthropic rate limits. Mode B uses three DIFFERENT profiles for this reason; Mode C uses `delegate_task` which inherits a single credential pool with rotation built in.
- **Output naming collisions.** If a profile is renamed, its output filename changes. The skill should derive filenames from the profile names it actually invokes.
- **Hermes web search vs. hosted Deep Research.** Hermes's web search is good but not equivalent to a multi-hour hosted Deep Research session. For projects where deeper browsing is needed, the user can hybrid: run the brief through hosted tools (Claude.ai Deep Research, ChatGPT Deep Research, Gemini Deep Research) and drop those outputs into `docs/research/` manually before Step 2. The yaml upsert in Step 2 handles iteration.
- **Brief-quality bottleneck.** Mode B's diversity is wasted if the brief is vague — three providers will return three different flavors of mediocre. Tighten the brief if outputs consistently feel thin.
- **Specialist skill failures.** If `arxiv` / `polymarket` / `blogwatcher` / `llm-wiki` fail (rate limit, schema change, missing dependency), fall back to `web_search` for that query — don't abort the whole worker. The worker should log the specialist failure in its output's Source ledger so re-runs know which queries went generic.
- **Scrapling install and ToS.** `scrapling` is an optional skill, not installed by default — calls fail loudly if it isn't installed. Install via `hermes skills install scrapling`. Separately: many sites that need scrapling have ToS that forbid scraping; surface this to the user before any mass-fetch loop, and prefer `browser_navigate` first.
- **Mode C toolsets and skill visibility.** `delegate_task` sub-agents inherit toolsets explicitly passed to them. The Mode C calls now include `["web", "browser", "file"]` so the browser fallbacks work. Specialist skills (`arxiv`, etc.) are available because they're installed in the parent's `~/.hermes/skills/research/` — sub-agents see them automatically. If you rename or move those skill directories, Mode C will silently lose the augmentation.

## Setup Note

If Mode B is desired but profiles aren't yet configured, point the user at `references/hermes-profile-setup.md` for the one-time setup. After that's done, Mode B is available for every future run.
