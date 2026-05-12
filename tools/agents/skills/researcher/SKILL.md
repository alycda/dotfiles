---
name: research
description: Bootstraps a research-driven project end-to-end using StrongDM's Software Factory pattern. Generates a SEED.md, drafts a research brief, runs parallel deep-research sub-agents (Anthropic-only by default; multi-provider via Hermes profiles when --external is passed), downloads materials, and builds a semantic index. Trigger when the user wants to start a new project that needs systematic prior-art collection — phrases like "prior art", "research brief", "set up factory", "seed and research", "compound engineering", "bootstrap a project", or any reference to the multi-step pipeline. Do NOT use for one-off questions, single web searches, or projects that already have docs/research/index/ built.
version: 0.4.0
metadata:
  hermes:
    tags: [research, factory, prior-art, seed, deep-research]
    category: research
---

# Researcher

A 5-step pipeline that bootstraps a research-driven project: **intent → seed → research brief → executed parallel research → downloaded materials → semantic index.**

Built on the StrongDM Software Factory pattern: *Seed → Validation harness → Feedback loop. Tokens are the fuel.*

## When to Use

Use this skill when:

- Starting a new project that needs systematic prior-art collection
- The user mentions "research brief", "prior art", "seed", "factory", "compound engineering", or "bootstrap a project"
- The user wants to bootstrap a project the way the existing exemplar (see `references/exemplar-seed.md`) was bootstrapped
- The user has a `SEED.md` and wants to drive it through to a built semantic index

Do NOT use for:

- One-off questions ("what is X?")
- Single web searches
- Code review or implementation tasks
- Projects that already have `docs/research/index/` complete (jump to whatever step is actually needed instead, or run a single `/researcher <step>` slash variant)

## Inputs

| Input | Source | Required? |
|---|---|---|
| Project intent | User (interactive Q&A in Step 0) | Yes, unless `SEED.md` already exists |
| Seed exemplar | `references/exemplar-seed.md` | Built-in |
| Research brief exemplar | `references/exemplar-research-brief.md` | Built-in |
| StrongDM principles + techniques + products | `references/strongdm-*.md` | Built-in (refresh from web with `--refresh`) |
| Worker profiles for cross-provider Mode B | `~/.hermes/profiles/researcher-codex/`, `~/.hermes/profiles/researcher-gemini/` | Optional — required only for `--external` flag. Setup: `references/hermes-profile-setup.md` |
| `writer` profile (Haiku 4.5) | `~/.hermes/profiles/writer/` (default model: `claude-haiku-4-5`) | Recommended for Step 2 dispatch. Falls back to parent provider if missing. |
| Web search tool | Hermes built-in `web_search` (requires backend: Tavily / Firecrawl / Exa / Parallel / SearXNG) | Required for Step 1.5 *for the Anthropic worker only* — codex and gemini workers use provider-native browsing. See `references/hermes-profile-setup.md` "Web Search Backend" section. |

## Procedure

### Step 0 — Seed (interactive)

Skip if `SEED.md`, `IDEA.md`, or `README.md` already exists at project root.

Otherwise follow `references/prompt-0-seed.md`:

1. Confirm `references/strongdm-principles.md` is loaded (refresh from web if `--refresh` was passed).
2. Probe the user across the four principle sections in order: Seed → Validation → Feedback → Apply More Tokens.
3. Draft `SEED.md` section-by-section, showing each draft to the user before continuing.
4. Surface 3–5 Open Questions; fold resolutions back in.
5. Write `SEED.md` at project root.

### Step 1 — Research Brief

Read `references/prompt-1-research-brief.md`. Produce `RESEARCH-BRIEF.md` at project root, modeled on `references/exemplar-research-brief.md`.

**Important:** the brief is external-safe by default — internal ticket IDs, customer names, and incident IDs are stripped or generalized so it can be dispatched to non-Anthropic providers in Step 1.5 without leaking. If internal anchors must be preserved, the brief is marked `internal_only: true` and Step 1.5 will refuse `--external`.

### Step 1.5 — Execute Research

Read `references/prompt-1.5-execute-research.md`. Two modes:

- **Mode C (default, no flag)** — Anthropic-only multi-perspective. Three `delegate_task` sub-agents on the parent's Anthropic provider, each with a different system prompt (theory / tooling / industry). Outputs `docs/research/{theory,tooling,industry}.md`. Safe — nothing leaves Anthropic.
- **Mode B (`--external`)** — Cross-provider via Hermes profiles. Parent's `terminal` tool runs `hermes -p <profile> chat -q ...` for the default (anthropic), `researcher-codex`, and `researcher-gemini` profiles in parallel. Outputs `docs/research/{claude,codex,gemini}.md`. Requires `--external` AND explicit consent prompt confirmation.

In both modes, workers prefer specialist research skills (`arxiv`, `polymarket`, `blogwatcher`, `llm-wiki`) when the brief warrants and fall back to browser tools / `scrapling` when `web_search` returns nothing useful. See `references/prompt-1.5-execute-research.md` §1.5.3 for the loadout.

If Mode B is requested but worker profiles are missing, fall back to Mode C and point the user at `references/hermes-profile-setup.md`.

### Step 2 — Download Manifest

Read `references/prompt-2-download-manifest.md`. Dispatch to the **`writer` profile (Haiku 4.5)** via `hermes -p writer chat -q "$WORKER_PROMPT"` — Step 2 is structured extraction (URL detection / normalization / classification), and Haiku handles it at ~1/5 the cost of Sonnet with no quality regression. The worker produces `docs/research/downloads.yaml` (idempotent-upsert format; see `templates/downloads.yaml.example`). Fall back to the parent provider if the `writer` profile is missing.

### Step 3 — Download

Read `references/prompt-3-download.md`. Spawn 5 sub-agents to download materials into `inspiration/`. Update yaml status as each completes. Verify and update `.gitignore`.

### Step 4 — Semantic Index

Read `references/prompt-4-semantic-index.md`. Build `docs/research/index/` using MapReduce-style sub-agents (one per source).

## Pitfalls

- **Web backend silently missing.** Hermes's `web_search` requires a configured backend (Tavily / Firecrawl / Exa / Parallel / SearXNG). Without one, the Anthropic worker silently falls back to training-corpus knowledge and produces stale citations. Step 1.5.0 preflight catches this — do not bypass. Codex and Gemini workers are unaffected (provider-native browsing).
- **Cold-start overconfidence.** First runs cannot rely on cross-session memory. Spend more time on Step 0 probe questions than feels natural.
- **Mode B without consent.** The `--external` flag does not bypass the consent prompt. Briefs naturally contain sensitive info; the phrase-confirmation gate exists because of that. Don't auto-confirm.
- **Sub-agent provider inheritance.** Hermes's `delegate_task` sub-agents inherit the parent's provider — there is no per-call override. Cross-provider diversity requires profile-level orchestration (Mode B), not in-process sub-agents (Mode C). The same escape hatch is used in Step 2 to route to Haiku via the `writer` profile, for cost reasons rather than diversity.
- **Mode C toolsets and skill visibility.** Mode C's `delegate_task` calls now pass `["web", "browser", "file"]` so browser fallbacks work for resistant sources. Specialist research skills (`arxiv`, `polymarket`, `blogwatcher`, `llm-wiki`) are available because they're installed at `~/.hermes/skills/research/` and sub-agents see them automatically. Renaming or moving those skill directories silently disables the Mode C augmentation — leave them where they are.
- **Brief-quality bottleneck.** Steps 2–4 only produce useful output if the Step 1 brief was high-quality. Vague brief → mediocre prior art across all researchers regardless of mode.
- **Token budget at Step 4.** Don't read all of `inspiration/` into a single context. MapReduce sub-agents are mandatory; serial reads will OOM.
- **`inspiration/` gitignore.** Step 3 must verify `.gitignore` excludes `inspiration/`. Failure can commit gigabytes of cloned repos and PDFs.
- **Hermes web search vs. hosted Deep Research.** Hermes's web search is good but not equivalent to a multi-hour hosted Deep Research session. For projects where deeper browsing is needed, the user can hybrid: run the brief through hosted tools too, drop those outputs into `docs/research/`, and proceed with Step 2.
- **Profile name drift.** Step 1.5 derives output filenames from profile names. If profiles are renamed (`researcher-codex` → `codex`), output filenames change. Document chosen names if the user is sharing the skill with teammates.

## Verification

After Step 4, the project root should contain:

```
.
├── SEED.md                          # from Step 0
├── RESEARCH-BRIEF.md                # from Step 1
├── .gitignore                       # contains "inspiration/"
├── inspiration/                     # populated, gitignored
└── docs/
    └── research/
        ├── claude.md (Mode B) or theory.md (Mode C)
        ├── codex.md  (Mode B) or tooling.md (Mode C)
        ├── gemini.md (Mode B) or industry.md (Mode C)
        ├── downloads.yaml           # from Step 2
        └── index/                   # from Step 4
            ├── README.md
            ├── by-topic.md
            ├── by-tag.md
            ├── clusters.md
            ├── top-N.md
            ├── cross-references.md
            ├── open-questions.md
            └── _per_source/
```

A successful run means a downstream non-interactive coding agent (Attractor, Fabro, Kilroy, or equivalent) can be pointed at this directory and start producing code. This skill is **tool-agnostic** — it produces the artifacts; downstream agents consume them.

## Slash Command Behavior

| Command | Behavior |
|---|---|
| `/researcher` | Start the pipeline; if `SEED.md` exists, ask whether to skip Step 0. Default Mode C for Step 1.5. |
| `/researcher --refresh` | Refresh cached StrongDM principles before Step 0 |
| `/researcher --external` | Use Mode B for Step 1.5 (cross-provider via worker profiles). Requires consent prompt. |
| `/researcher seed` | Step 0 only |
| `/researcher brief` | Step 1 only (assumes SEED.md exists) |
| `/researcher research` | Step 1.5 only — Mode C |
| `/researcher research --external` | Step 1.5 only — Mode B |
| `/researcher manifest` | Step 2 only |
| `/researcher download` | Step 3 only |
| `/researcher index` | Step 4 only |
| `/researcher index --rebuild` | Step 4, regenerating from scratch |

## First-Time Setup (Mode B Only)

If the user wants Mode B (cross-provider diversity), point them at `references/hermes-profile-setup.md` for one-time profile creation. Mode C requires no setup — it works out of the box on the default Anthropic profile.

## Related

- StrongDM Software Factory: https://factory.strongdm.ai/
- Hermes Agent: https://hermes-agent.nousresearch.com/docs/
- Hermes Profiles: https://hermes-agent.nousresearch.com/docs/user-guide/profiles
- Hermes Subagent Delegation: https://hermes-agent.nousresearch.com/docs/user-guide/features/delegation
- Compound Engineering brainstorm/seed plugin (TBD — investigate as alternative to Step 0)
- Attractor: https://github.com/strongdm/attractor (downstream consumer of the artifacts produced)
- Fabro: https://fabro.sh/ (Attractor implementation)
- Kilroy: https://github.com/danshapiro/kilroy (Attractor implementation)
