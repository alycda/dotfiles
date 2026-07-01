---
name: researcher
description: Bootstraps a research-driven project end-to-end using StrongDM's Software Factory pattern. Generates a SEED.md, drafts a research brief, runs parallel deep-research sub-agents (Claude-only by default; multi-provider via sibling codex/gemini CLIs when --external is passed), augments with a required hosted Deep Research pass (Claude.ai / ChatGPT / Gemini browser DR), downloads materials, and builds a semantic index. Trigger when the user wants to start a new project that needs systematic prior-art collection — phrases like "prior art", "research brief", "set up factory", "seed and research", "compound engineering", "bootstrap a project", or any reference to the multi-step pipeline. Do NOT use for one-off questions, single web searches, or projects that already have _docs/research/index/ built.
version: 0.8.0-claude
metadata:
  tags: [research, factory, prior-art, seed, deep-research]
  category: research
---

# Researcher

A 5-step pipeline that bootstraps a research-driven project: **intent → seed → research brief → executed parallel research → downloaded materials → semantic index.**

Built on the StrongDM Software Factory pattern: *Seed → Validation harness → Feedback loop. Tokens are the fuel.*

This is the Claude-Code-native adaptation of the original Hermes researcher skill. Sub-agent orchestration uses the Agent tool; cross-provider diversity uses sibling `codex` and `gemini` CLIs invoked via Bash, matching the pattern used by `sprint-planner` / `sprint-retrospective` / `sprint-execute`.

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
- Projects that already have `_docs/research/index/` complete (jump to whatever step is actually needed instead, or run a single `/researcher <step>` slash variant)

## Inputs

| Input | Source | Required? |
|---|---|---|
| Project intent | User (interactive Q&A in Step 0) | Yes, unless `SEED.md` already exists |
| Seed exemplar | `references/exemplar-seed.md` | Built-in |
| Research brief exemplar | `references/exemplar-research-brief.md` | Built-in |
| StrongDM principles + techniques + products | `references/strongdm-*.md` | Built-in (refresh from web with `--refresh`) |
| `codex` and `gemini` CLIs | Installed and authenticated on PATH | Required only for `--external` flag (Mode B). Setup: `references/cli-setup.md` |
| Web search / fetch | Built-in `WebSearch` + `WebFetch` tools | Available automatically; no backend config needed |
| Hosted Deep Research access | Claude.ai DR, ChatGPT DR, Gemini DR (browser apps via existing subscriptions) | Required for Step 1.6 unless `--skip-deep-research` is passed. No setup beyond having the accounts. |

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

- **Mode C (default, no flag)** — Claude-only multi-perspective. Three parallel Agent sub-agents on the parent's Claude model, each with a different perspective prompt (theory / tooling / industry). Outputs `_docs/research/{theory,tooling,industry}.md`. Safe — nothing leaves Claude.
- **Mode B (`--external`)** — Cross-provider via sibling CLIs. Parent uses Bash to invoke `codex` and `gemini` CLIs in parallel alongside a Claude Agent worker. Outputs `_docs/research/{claude,codex,gemini}.md`. Requires `--external` flag AND explicit consent prompt confirmation.

If Mode B is requested but `codex` or `gemini` is missing from PATH, fall back to Mode C and point the user at `references/cli-setup.md`.

### Step 1.6 — Hosted Deep Research Augmentation

Read `references/prompt-1.6-deep-research.md`. **Required** in the Claude harness; skip with `--skip-deep-research`.

The skill renders `templates/web-prompt.md` against `RESEARCH-BRIEF.md` and writes `WEB-PROMPT.md` at the project root. The user pastes that prompt into Claude.ai Deep Research, ChatGPT Deep Research, and Gemini Deep Research browser apps (in parallel tabs while doing other work) and saves the returned reports to `_docs/research/{claude,chatgpt,gemini}-deep-research.md`. The skill waits for `continue` (or `skip`) before proceeding to Step 2.

Why required: Claude Code's built-in `WebSearch` + `WebFetch` undershoots hosted Deep Research on breadth-of-citations tasks. Empirical comparison on a recent project found the Gemini CLI worker produced ~13% of its hosted DR counterpart's depth (8k bytes vs 63k bytes; 31 URLs vs 86). The Claude and Codex workers tracked their hosted counterparts more closely but still missed long-tail primary sources. Step 1.6 is positioned as a fourth pass on top of Step 1.5's three inline workers — not a replacement.

### Step 2 — Download Manifest

Read `references/prompt-2-download-manifest.md`. Dispatch to an Agent sub-agent with `model: "haiku"` — Step 2 is structured extraction (URL detection / normalization / classification), and Haiku handles it at a fraction of the Opus/Sonnet cost with no quality regression. The sub-agent produces `_docs/research/downloads.yaml` (idempotent-upsert format; see `templates/downloads.yaml.example`).

### Step 3 — Download

Read `references/prompt-3-download.md`. Invoke `scripts/download.py` via Bash to download all `pending` entries into `_inspiration/`. The script handles per-domain rate limits, atomic yaml updates via `flock`, exponential-backoff retries, and idempotent re-runs. **No LLM dispatch** — downloads are mechanical (`curl` / `git clone` / `wget`) and `kind` is already decided by Step 2.

```bash
python3 ~/.claude/skills/researcher/scripts/download.py --project-root "$PROJECT_ROOT" --workers 5
```

Surfaces `status: failed` entries at the end for manual triage. Don't auto-retry via Agents — failed entries usually mean paywalled, deleted, or auth-gated content and need the user's judgment.

### Step 4 — Semantic Index

Read `references/prompt-4-semantic-index.md`. Build `_docs/research/index/` using MapReduce-style Agent sub-agents (one per source for the Map phase; single agent or inline for the Reduce phase).

## Pitfalls

- **Cold-start overconfidence.** First runs cannot rely on cross-session memory. Spend more time on Step 0 probe questions than feels natural.
- **Mode B without consent.** The `--external` flag does not bypass the consent prompt. Briefs naturally contain sensitive info; the phrase-confirmation gate exists because of that. Don't auto-confirm.
- **Per-call model override is per-Agent-call.** The Agent tool's `model:` parameter is how Step 2 routes to Haiku without leaving Claude. Mode C uses the default (parent's model). Mode B uses external CLIs for actual vendor diversity — that's why Mode B exists.
- **Brief-quality bottleneck.** Steps 2–4 only produce useful output if the Step 1 brief was high-quality. Vague brief → mediocre prior art across all researchers regardless of mode.
- **Token budget at Step 4.** Don't read all of `_inspiration/` into a single context. MapReduce sub-agents are mandatory; serial reads will OOM.
- **`_inspiration/` gitignore (nested stub).** The 0.8 convention is a nested `_inspiration/.gitignore` containing `*` and `!.gitignore`, which ignores the directory's contents while keeping the directory itself trackable. Step 3 creates this stub idempotently when missing. Failure to gitignore can commit gigabytes of cloned repos and PDFs.
- **Skipping Step 1.6 silently.** Step 1.6 (hosted Deep Research augmentation) is *required*, not optional, in the Claude harness — `WebSearch` + `WebFetch` alone undershoots hosted DR on breadth-of-citations tasks (especially Gemini-style). The `--skip-deep-research` escape hatch exists for quick iterative reruns, but the skill must always warn loudly when skipping. Don't let it become a silent default.
- **Arxiv ID hallucination in Step 1.6.** Hosted Deep Research occasionally invents plausible arXiv IDs that don't resolve. Step 3's download phase will fail loudly on 404 — that's the natural check. Flag arxiv IDs dated after the current month as suspicious in `cited_in` notes.
- **CLI not on PATH.** Mode B requires `codex` and `gemini` reachable from the shell. If either is missing, fall back to Mode C and tell the user — don't silently run with two workers.
- **`internal_only: true` and external dispatch.** If the brief was authored with internal anchors preserved, Step 1.5 must refuse `--external` outright AND Step 1.6 must refuse to emit `WEB-PROMPT.md`. Surface the conflict and ask whether the user wants to author a sanitized version or run Mode C with `--skip-deep-research`.

## Verification

After Step 4, the project root should contain:

```
.
├── SEED.md                          # from Step 0
├── RESEARCH-BRIEF.md                # from Step 1
├── WEB-PROMPT.md                    # from Step 1.6 (unless --skip-deep-research)
├── _inspiration/
│   ├── .gitignore                   # nested stub: `*` + `!.gitignore`
│   └── ...                          # downloaded materials (gitignored by the stub)
└── _docs/
    ├── .gitignore                   # nested stub: `*` + `!.gitignore`
    └── research/
        ├── claude.md (Mode B) or theory.md (Mode C)     # from Step 1.5
        ├── codex.md  (Mode B) or tooling.md (Mode C)    # from Step 1.5
        ├── gemini.md (Mode B) or industry.md (Mode C)   # from Step 1.5
        ├── claude-deep-research.md                       # from Step 1.6 (≥1 of these 3)
        ├── chatgpt-deep-research.md                      # from Step 1.6
        ├── gemini-deep-research.md                       # from Step 1.6
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
| `/researcher` | Start the pipeline; if `SEED.md` exists, ask whether to skip Step 0. Default Mode C for Step 1.5; Step 1.6 required. |
| `/researcher --refresh` | Refresh cached StrongDM principles before Step 0 |
| `/researcher --external` | Use Mode B for Step 1.5 (cross-provider via codex+gemini CLIs). Requires consent prompt. Step 1.6 still required. |
| `/researcher --skip-deep-research` | Skip Step 1.6 (hosted DR augmentation). Warns about reduced output quality, especially on breadth-of-citations tasks. |
| `/researcher seed` | Step 0 only |
| `/researcher brief` | Step 1 only (assumes SEED.md exists) |
| `/researcher research` | Step 1.5 only — Mode C |
| `/researcher research --external` | Step 1.5 only — Mode B |
| `/researcher web-prompt` | Step 1.6 only — emit `WEB-PROMPT.md` and wait for hosted DR outputs |
| `/researcher manifest` | Step 2 only |
| `/researcher download` | Step 3 only |
| `/researcher index` | Step 4 only |
| `/researcher index --rebuild` | Step 4, regenerating from scratch |

## First-Time Setup (Mode B Only)

Mode B requires `codex` and `gemini` CLIs installed and authenticated. See `references/cli-setup.md`. Mode C requires no setup — the Agent tool is built into Claude Code.

## Related

- StrongDM Software Factory: https://factory.strongdm.ai/
- Original Hermes researcher skill (this one's ancestor): `~/.hermes/skills/research/researcher/`
- Sibling CLI orchestration pattern: `~/.claude/skills/sprint-planner/SKILL.md`
- Compound Engineering brainstorm/seed plugin (TBD — investigate as alternative to Step 0)
- Attractor: https://github.com/strongdm/attractor (downstream consumer of the artifacts produced)
- Fabro: https://fabro.sh/ (Attractor implementation)
- Kilroy: https://github.com/danshapiro/kilroy (Attractor implementation)
