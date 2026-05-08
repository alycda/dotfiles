# Step 1.5 — Execute Research (Multi-Researcher)

The step Hermes uniquely enables. Historically a manual web-browser step (run the brief through Claude/ChatGPT/Gemini Deep Research, paste outputs into `docs/research/`); Hermes runs it from the CLI.

## Architecture: Two Modes

**Mode B (cross-provider diversity)** — Three independent Hermes profiles, each with a different provider. Orchestrated via `terminal` (`hermes -p <profile> chat -q ...` in parallel). True vendor diversity. Requires user opt-in via `--external` flag because the brief is sent to non-Anthropic providers.

**Mode C (Anthropic-only multi-perspective)** — Single profile (default). Orchestrated via `delegate_task`. Three sub-agents inherit the parent's Anthropic provider but get different system prompts (theory / tooling / industry). Diversity from prompt perspective, not model. Safe by default — nothing leaves Anthropic.

Hermes's `delegate_task` does NOT support per-call provider override (sub-agents inherit the parent's provider). Cross-provider diversity therefore requires profile-level orchestration, not in-process sub-agents.

## Procedure

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

### 1.5.3 — Mode B Execution (Cross-Provider)

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

WORKER_PROMPT='Read RESEARCH-BRIEF.md from the current directory. Execute the research per the brief, using web search. Write your final structured findings to docs/research/<NAME>.md following the deliverables specified in the brief (Top N must-reads with annotations, per-topic findings with "what it gives us"+"gap" lines, tool shortlist, reference architectures, open research questions, source ledger). End with a confirmation that you wrote the file.'

(hermes chat -q "${WORKER_PROMPT//<NAME>/claude}" 2>&1 | tee logs/claude-worker.log) &
(hermes -p researcher-codex chat -q "${WORKER_PROMPT//<NAME>/codex}" 2>&1 | tee logs/codex-worker.log) &
(hermes -p researcher-gemini chat -q "${WORKER_PROMPT//<NAME>/gemini}" 2>&1 | tee logs/gemini-worker.log) &
wait
```

The skill SHOULD construct this shell command dynamically, not paste a fixed snippet — profile names may vary, prompt content may need adjustment per project.

### 1.5.4 — Mode C Execution (Anthropic-Only Multi-Perspective)

Use `delegate_task` with three parallel sub-agents on the parent's Anthropic provider. Diversity comes from system-prompt perspective:

```
delegate_task(tasks=[
    {
        "goal": "Execute the research brief from RESEARCH-BRIEF.md as a THEORY researcher",
        "context": "Focus on academic papers, formal verification work, conference proceedings (USENIX, OSDI, PLDI, POPL), arxiv preprints. Skip blog posts and tooling. Write your findings to docs/research/theory.md following the brief's deliverable spec.",
        "toolsets": ["web", "file"]
    },
    {
        "goal": "Execute the research brief from RESEARCH-BRIEF.md as a TOOLING researcher",
        "context": "Focus on repos, libraries, CI patterns, language-specific implementations, package ecosystems. Skip pure-theory papers. Write your findings to docs/research/tooling.md.",
        "toolsets": ["web", "file"]
    },
    {
        "goal": "Execute the research brief from RESEARCH-BRIEF.md as an INDUSTRY researcher",
        "context": "Focus on postmortems, blog posts from teams that built the thing, conference talks with video, engineering memos. Skip academic papers and library docs. Write your findings to docs/research/industry.md.",
        "toolsets": ["web", "file"]
    }
])
```

All three sub-agents inherit Anthropic from the parent; nothing leaves the provider boundary.

### 1.5.5 — Wait and Verify

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

- **Skipping the consent prompt in Mode B.** This is a hard requirement. Do not auto-confirm even if the user passed `--external`. The phrase-confirmation gate exists because briefs naturally contain sensitive context unless deliberately sanitized.
- **Profile-not-found errors.** If `researcher-codex` or `researcher-gemini` doesn't exist, fall back to Mode C and log the missing profile. Don't silently use only two workers in Mode B — three is the design.
- **Endpoint-specific refusals.** Codex and Gemini may refuse certain research topics. Surface refusals; don't silently swallow.
- **Parallel rate limits within a single profile.** If you re-use the default profile (anthropic) for two workers in any mode, you'll trip Anthropic rate limits. Mode B uses three DIFFERENT profiles for this reason; Mode C uses `delegate_task` which inherits a single credential pool with rotation built in.
- **Output naming collisions.** If a profile is renamed, its output filename changes. The skill should derive filenames from the profile names it actually invokes.
- **Hermes web search vs. hosted Deep Research.** Hermes's web search is good but not equivalent to a multi-hour hosted Deep Research session. For projects where deeper browsing is needed, the user can hybrid: run the brief through hosted tools (Claude.ai Deep Research, ChatGPT Deep Research, Gemini Deep Research) and drop those outputs into `docs/research/` manually before Step 2. The yaml upsert in Step 2 handles iteration.
- **Brief-quality bottleneck.** Mode B's diversity is wasted if the brief is vague — three providers will return three different flavors of mediocre. Tighten the brief if outputs consistently feel thin.

## Setup Note

If Mode B is desired but profiles aren't yet configured, point the user at `references/hermes-profile-setup.md` for the one-time setup. After that's done, Mode B is available for every future run.
