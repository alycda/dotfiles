---
name: c4-design
description: Produces a Likec4 architectural model + interactive dashboard from planning artifacts BEFORE code is written. Bridges the gap between strategy/plan documents (STRATEGY.md, SEED.md, ce-plan output, RESEARCH-BRIEF.md) and a Context → Container → Component hierarchy you can browse and review. The dashboard is the artifact you'd point Understand-Anything at AFTER code exists; this skill gives you the same shape of artifact BEFORE. Trigger when the user wants to design system architecture before writing code — phrases like "c4 model", "architecture diagram", "system design", "container diagram", "design the hierarchy", or when an upstream plan/strategy doc is ready and the user wants a visual review surface.
version: 0.1.0
metadata:
  tags: [architecture, c4, design, pre-code, likec4]
  category: design
---

# C4 Design

A short pipeline that turns planning artifacts into a navigable C4 architectural model: **inputs (strategy/plan/seed) → interview gaps → Likec4 DSL → interactive dashboard → iterate.** Optionally closes the loop post-build via a drift check against [Understand-Anything](https://github.com/Lum1104/Understand-Anything).

Positioned in the workflow between `ce-plan` / `ce-strategy` (which produce the **why/what/how-sequenced**) and writing code (or `understand-anything` to verify what got built):

```
ce-strategy        ce-plan          c4-design                        understand-anything
STRATEGY.md   →    plan.md     →    docs/c4/{model.c4, dashboard/} → knowledge-graph.json
(why/what)         (how, seq)       (architectural hierarchy)         (verify against built code)
```

Uses [Likec4](https://likec4.dev) — text DSL → interactive HTML dashboard. Free, OSS, MIT.

## When to Use

Use this skill when:

- A strategy or plan document exists and the user wants to see the architectural hierarchy before code lands
- The user mentions "C4 model", "architecture diagram", "container diagram", "system design", "design the hierarchy"
- The user wants a review surface for architectural decisions that's richer than a Mermaid block in a plan doc
- The user wants drift-detection between planned architecture and built code (Step 3, post-`understand-anything`)

Do NOT use for:

- One-off Mermaid diagrams in a doc (just write the Mermaid inline)
- Reverse-engineering an existing codebase (that's `understand-anything`)
- Strategy or planning itself (that's `ce-strategy` / `ce-plan`)
- After the code is already written and stable (the C4 model becomes documentation drift bait at that point)

## Inputs

| Input | Source | Required? |
|---|---|---|
| Project intent | One or more of `STRATEGY.md`, `SEED.md`, `RESEARCH-BRIEF.md`, ce-plan output | At least one |
| User interview answers | Step 0 (interactive) | Yes, on first run |
| `npx` and Node 18+ | On PATH | Required for dashboard build |
| Likec4 CLI | `npx @likec4/cli` (auto-downloads on first run) | Available via npx; no install needed |
| `understand-anything` plugin | Installed | Optional, only for Step 3 drift check |

## Procedure

### Step 0 — Interview (interactive)

Skip if `docs/c4/model.c4` exists (re-run on existing model — go to Step 2). Otherwise follow `references/prompt-0-interview.md`:

Probe the user on the four things planning docs typically leave implicit:

1. **External actors** — humans and other systems that touch this system
2. **System boundary** — what's inside vs. outside this design
3. **Containers** — deployable units (web app, API, worker, database, ...) the design calls for
4. **Component-level decomposition** — for the 1–3 most non-obvious containers, what are the key internal modules

Output: a structured notes block the skill carries into Step 1.

### Step 1 — Draft DSL

Read `references/prompt-1-draft-dsl.md`. Combine:

- The interview output from Step 0
- Available upstream docs (`STRATEGY.md`, `SEED.md`, `RESEARCH-BRIEF.md`, ce-plan files, `docs/research/index/` if researcher ran)
- `templates/model.c4.template` as the structural skeleton

Produce `docs/c4/model.c4` (Likec4 DSL). For Likec4 syntax reminders see `references/likec4-syntax-primer.md` and the canonical docs at https://likec4.dev/docs.

### Step 2 — Render and Iterate

Run `scripts/build-dashboard.sh` to produce the interactive dashboard at `docs/c4/dashboard/`. Open `docs/c4/dashboard/index.html`.

Then follow `references/prompt-2-iterate.md`: surface the dashboard to the user, gather feedback on each view (Context, Container, Component), edit `model.c4`, rebuild. Repeat until the user accepts.

The DSL is the source of truth. Don't hand-edit the built dashboard — re-render after every DSL change.

### Step 3 — Drift Check (optional, post-build)

Read `references/prompt-3-drift-check.md`. Run only after some of the planned system has been built AND `understand-anything` has produced `knowledge-graph.json`.

Diff the planned model against the built knowledge graph:

- **Planned not built** — containers/components in `model.c4` with no corresponding nodes in `knowledge-graph.json`
- **Built not planned** — significant code structures in `knowledge-graph.json` not represented in `model.c4` (drift)
- **Dependency mismatches** — edges in the planned model that don't appear in the built graph, or vice versa

Report. The user decides whether to update the model (architecture evolved correctly) or refactor the code (architecture is drifting).

## Pitfalls

- **DSL hand-edits get lost on rebuild.** The dashboard is generated; never edit it directly. Always edit `model.c4` and rerun `scripts/build-dashboard.sh`.
- **Over-decomposition at Component level.** C4's Component level (level 3) is for the 5–15 most important internal modules of a container, not every class or file. If you find yourself listing 50 components in one container, stop — that's a Code level (level 4) view, and most projects never need level 4.
- **Drifting toward implementation detail.** Pre-code C4 should describe *what* the system is, not *how* every internal function works. Leave function-level detail to the actual code and `understand-anything` afterward.
- **Likec4 version drift.** The DSL has evolved; this skill targets Likec4 1.x conventions. If `likec4 build` fails on syntax, check https://likec4.dev/docs/dsl for current grammar and update `templates/model.c4.template` accordingly.
- **External system pretending to be a container.** A third-party service the system *uses* (Stripe, Anthropic API, etc.) is an *external system*, not a container. Containers are deployable units of the system being designed.
- **One mega-view.** A single all-in-one view defeats C4's layered design. Always produce at least: a System Context view, a Container view, and one Component view per non-trivial container.
- **Skipping interview because docs feel complete.** Plan docs rarely surface external actors and deployment boundaries explicitly. Skipping Step 0 produces a model that misses key elements every time. Do the interview even if it feels redundant.
- **`understand-anything` not installed when running Step 3.** Step 3 reads `knowledge-graph.json` produced by Understand-Anything. If it's absent, surface the install link and stop — don't fake the drift check.

## Verification

After Step 2, the project root should contain:

```
docs/
└── c4/
    ├── model.c4              # Likec4 DSL — source of truth
    └── dashboard/
        ├── index.html         # entry point for the interactive dashboard
        └── ...                # Likec4-generated assets (HTML, CSS, JS, JSON)
```

A successful run means:

- `model.c4` parses cleanly (`npx @likec4/cli validate` exits 0)
- `dashboard/index.html` opens in a browser and shows at least three views: Context, Container, and one Component view
- Every external actor in the interview answer appears in the Context view
- Every container in the interview answer appears in the Container view
- Each non-trivial container has its own Component view

## Slash Command Behavior

| Command | Behavior |
|---|---|
| `/c4-design` | Full pipeline. If `model.c4` exists, ask whether to re-interview (Step 0) or jump to iteration (Step 2). |
| `/c4-design interview` | Step 0 only — produces interview notes; doesn't write `model.c4` |
| `/c4-design draft` | Step 1 only — assumes interview notes exist (either inline or as `docs/c4/interview.md`) |
| `/c4-design render` | Step 2 build only — `model.c4` → `dashboard/` (no DSL edits) |
| `/c4-design iterate` | Step 2 review-and-edit loop |
| `/c4-design drift` | Step 3 — requires `knowledge-graph.json` from `understand-anything` |

## First-Time Setup

No setup required. `npx @likec4/cli` auto-downloads on first run. Node 18+ must be on PATH (check with `node --version`).

Optional: install Likec4's VS Code extension for syntax highlighting and inline diagram preview while editing `model.c4`. See https://likec4.dev/tooling/vscode.

## Related

- Likec4 docs: https://likec4.dev/docs
- Likec4 DSL grammar: https://likec4.dev/docs/dsl
- The C4 model (Simon Brown): https://c4model.com
- Structurizr (alternative, by C4's author): https://structurizr.com
- Understand-Anything (downstream verifier): https://github.com/Lum1104/Understand-Anything
- ce-strategy (upstream input): https://github.com/EveryInc/compound-engineering-plugin/blob/main/docs/skills/ce-strategy.md
- ce-plan (upstream input): part of the compound-engineering plugin
- researcher (sibling skill): `~/.claude/skills/researcher/` — produces prior-art index that informs container choices
