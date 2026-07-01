---
name: sprint-retrospective
description: Multi-model sprint retrospective. Use this whenever the user wants to retro a sprint, run a postmortem, write a sprint retrospective, or asks "what did we learn from SPRINT-XXXX". Orchestrates codex, gemini, and claude CLIs to produce independent retros and cross-critiques over the actual sprint evidence (plan, checkbox state, blockers, git history), then merges them into a final retro at docs/sprints/SPRINT-XXXX-retro.md.
---

# Sprint Retrospective

Given a finished (or finishing) sprint, produce a merged retrospective at `docs/sprints/SPRINT-XXXX-retro.md` built from three independent retros (codex, gemini, claude) and three cross-critiques, grounded in the actual sprint evidence — not vibes.

## Why multi-model?

A single model's retro reflects one model's blind spots, and is especially prone to two failure modes: glossing over its own work if it was the executor, and inventing themes that sound insightful but aren't grounded in the evidence. Three independent retros surface a wider set of observations; the cross-critiques force each model to defend specific claims against peers, which knocks out the ungrounded ones. The Opus merge keeps the strongest grounded findings from each.

## Layout

```
docs/sprints/
├── ledger.yaml                              # tracked
├── SPRINT-0001.md                           # the plan (input)
├── SPRINT-0001-retro.md                     # tracked — the merged final retro
└── drafts/                                  # gitignored
    ├── SPRINT-0001-CODEX-retro.md           # retro draft from codex
    ├── SPRINT-0001-GEMINI-retro.md          # retro draft from gemini
    ├── SPRINT-0001-CLAUDE-retro.md          # retro draft from claude
    ├── SPRINT-0001-CODEX-retro-critique.md  # codex critiquing gemini + claude
    ├── SPRINT-0001-GEMINI-retro-critique.md # gemini critiquing codex + claude
    └── SPRINT-0001-CLAUDE-retro-critique.md # claude critiquing codex + gemini
```

## Workflow

Follow these phases in order. Don't skip, don't parallelize across phases, but **do parallelize within phases** where noted — the three retro drafts are independent, and so are the three critiques.

### 1. Pick the sprint

Default to the most-recent sprint with status `done`. If none, fall back to the most-recent `in-progress` sprint and confirm the user wants a mid-sprint retro (those are valid but smaller in scope).

```bash
python3 .claude/skills/sprint-planner/scripts/ledger.py list
```

If the user named a sprint id explicitly, use that. Verify both the plan file `docs/sprints/{SID}.md` and a ledger entry exist before going further — no plan, no retro.

### 2. Gather the evidence pack

A retro that isn't grounded in evidence is just three models' vibes. Before any drafting, assemble the inputs every drafter will receive. Read these yourself in this session and write a short *evidence pack* file at `docs/sprints/drafts/{SID}-retro-evidence.md` so all three drafters see the same thing.

Collect:

- **The plan** — full contents of `docs/sprints/{SID}.md`. The drafters need to compare *intended* vs *actual*.
- **Checkbox state** — count of `- [x]` vs `- [ ]` in the plan, and the literal list of unchecked items if any.
- **Retro notes section** — the `## Retro notes` section of the plan (written by the executor during `sprint-execute`). Copy it verbatim. This is the highest-signal input — it's the executor's per-task observations captured while context was fresh, and the only place where things like "decision: picked X because Y" or "friction: tests took 4 tries to stabilize" survive after the executor process exits or its session compacts. If the section is missing, flag it: either execution predates the retro-notes convention, or the executor skipped it.
- **Blockers section** — if the plan has a `## Blockers` heading, copy it verbatim. This is the executor's own record of what went wrong.
- **Executor identity** — `executor` field from the ledger (`opus` / `gpt-5.5` / `gemini`). The retro should be honest about who did the work.
- **Sprint timestamps** — `created` and `updated` from the ledger, to anchor the git window.
- **Git evidence** — commits and diffstat in the sprint window:
  ```bash
  git log --since="{created}" --until="{updated}" --pretty=format:'%h %ad %s' --date=short
  git diff --stat $(git log --since="{created}" --until="{updated}" --reverse --pretty=format:'%h' | head -1)^..HEAD
  ```
  If the repo has no commits in the window, note that — execution may have been WIP or non-code.
- **Per-model progress files** — if `docs/sprints/{SID}-*-progress.md` files exist (a pattern the user has used to track per-model attempts), include their paths. They're prior art for the retro.

The evidence pack is just a markdown stitching of the above with section headers — it's an input, not an artifact. Don't editorialize in it.

### 3. Generate three independent retro drafts — in parallel

Run all three CLI calls **in the same turn** (parallel Bash tool calls). Each agent writes directly to its own draft file. Hand each agent the same evidence pack path and the same instructions about structure.

The YOLO / non-interactive invocations — these are the same as the planner's, don't second-guess them:

- **codex**: `codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"`
- **gemini**: `gemini -y -p "<prompt>"`
- **claude**: `claude -p "<prompt>"`

Prompt each agent with:

> You are writing a retrospective on sprint **{SID}**. Read the evidence pack at `docs/sprints/drafts/{SID}-retro-evidence.md` first — it contains the plan, checkbox state, blockers, executor identity, and git history. Read the plan itself at `docs/sprints/{SID}.md` for full task context.
>
> Write a retrospective to `docs/sprints/drafts/{SID}-{AGENT}-retro.md` (where AGENT is CODEX, GEMINI, or CLAUDE as appropriate for you). Freestyle the structure, but every claim must be grounded in the evidence — cite specific tasks, commits, retro-note tags (`surprise:`, `decision:`, `win:`, `friction:`, `deferred:`), or blocker text. The `## Retro notes` section in the plan is the executor's contemporaneous record and your highest-signal input — lean on it; if it's missing, say so explicitly and lean harder on git evidence and checkbox state. Cover:
>
> - **Outcome** — what landed vs what was planned. Be quantitative (X/Y tasks checked, Z commits).
> - **What went well** — concrete moments, not platitudes. "Splitting the migration into two PRs avoided the lock contention risk" beats "good teamwork".
> - **What went poorly** — same standard. Cite the blocker, the unchecked task, or the commit that had to be reverted.
> - **Root causes** — for each thing that went poorly, one level deeper than the symptom. If a task was unchecked, *why*?
> - **Lessons for the next sprint** — actionable, concrete. "Add a smoke test before the first migration step" beats "be more careful".
> - **Process notes on the executor** — was the chosen implementer model (opus/gpt-5.5/gemini) a good fit? Where did it shine, where did it struggle?
>
> Be honest about ambiguity. If the evidence doesn't support a confident claim, say so rather than padding.

Each agent runs headless; do not wait interactively. After all three return, verify the three files exist before moving on.

### 4. Generate three cross-critiques — in parallel

Once the retro drafts exist, ask each agent to critique the **other two**. Again, run all three in parallel in the same turn.

Prompt each critiquing agent with:

> You wrote `docs/sprints/drafts/{SID}-{YOU}-retro.md` for sprint **{SID}**. Read the other two retros at `docs/sprints/drafts/{SID}-{OTHER_1}-retro.md` and `docs/sprints/drafts/{SID}-{OTHER_2}-retro.md`. Also re-read the evidence pack at `docs/sprints/drafts/{SID}-retro-evidence.md` so you can check claims against it.
>
> Write a critique to `docs/sprints/drafts/{SID}-{YOU}-retro-critique.md`. For each of the other two retros: which findings are well-grounded in the evidence, which are speculation dressed up as insight, what observations are missing that the evidence clearly supports, and where is the diagnosis shallow (symptom-level when a root cause is reachable). Cite specific lines or claims. End with a short "if I were merging, I'd keep X from retro A and Y from retro B" section.

### 5. Merge with Opus

You (the Claude session running this skill) are Opus. **Do not delegate the merge to another CLI call.** Read all six files yourself — three retros and three critiques — plus the evidence pack, and write the merged final retro directly to `docs/sprints/{SID}-retro.md`.

The merge is not an average. Prefer claims that two or more drafts converged on, *and* that the critiques didn't successfully knock down. When drafts disagree, use the critiques as evidence: a finding two critiques flagged as ungrounded probably is; a missing observation two critiques pointed out is probably real. The final doc should feel like a single coherent retrospective, not a stitched compilation.

Required in the final file:
- A title line and one-paragraph summary of the sprint outcome
- **Outcome** — quantitative landing (tasks, commits, blockers)
- **What went well** — concrete, evidence-cited
- **What went poorly** — concrete, evidence-cited
- **Root causes** — one level below symptom for each "went poorly" item
- **Lessons for the next sprint** — actionable items, ideally phrased so they could become tasks in a future sprint plan
- **Executor assessment** — one short paragraph on the implementer model's fit for this sprint's shape of work

### 6. Update the ledger

The ledger doesn't currently track retro state explicitly. If the sprint was `in-progress` and the user is calling it done as part of the retro, flip it:

```bash
python3 .claude/skills/sprint-planner/scripts/ledger.py set-status {SID} done
```

Otherwise, leave the ledger alone — the existence of `docs/sprints/{SID}-retro.md` is the signal that a retro happened. (If we ever want to surface "has a retro?" in `ledger.py list`, that's a future ledger schema change, not this skill's job.)

### 7. Report back

Tell the user: the sprint id, the final retro path (`docs/sprints/{SID}-retro.md`), and a one-line summary of the top one or two lessons the merge surfaced. Don't re-dump the retro in chat — the file is the artifact.

## Notes and edge cases

- **No commits in the sprint window.** Possible if the work was WIP-only, doc-heavy, or branched but not merged. Note this in the evidence pack so drafters don't silently invent activity. The retro is still valuable — it just leans more on plan/blocker/checkbox evidence than git evidence.
- **Plan with all `[ ]` unchecked.** The sprint may have been abandoned or never executed. Surface to the user before drafting; abandonment retros are valid (and useful), but they should be framed as "why didn't this get picked up" rather than "how did execution go".
- **Mid-sprint retro.** If the sprint is still `in-progress`, frame the prompts as "retro on the work so far" and skip the executor-fit assessment if work is ongoing. Don't auto-flip status to `done` — confirm with the user first.
- **Multiple executors.** If the executor field changed during the sprint (a switch mid-flight), include both in the evidence pack and let the drafters compare phases.
- **Existing per-model progress files.** Files like `docs/sprints/{SID}-CHATGPT-progress.md` are the user's own running notes from when multiple models attempted the sprint. Include them in the evidence pack — they're often the highest-signal input. Don't conflate them with the official `SPRINT-XXXX.md` plan.
- **Retro re-runs.** If the user asks to redo a retro, either overwrite `docs/sprints/{SID}-retro.md` (and regenerate drafts) or write to a versioned path like `{SID}-retro-v2.md`. Ask which.
- **Draft failures.** If one agent's CLI call fails (rate limits, network), surface that to the user and ask whether to retry that one agent or proceed with two retros + two critiques. Don't silently drop.

## Cross-implementer disagreement check (multi-implementer sprints)

When per-model progress files exist (the user's quad-pattern: `{SID}-CHATGPT-progress.md`, `{SID}-GEMINI-progress.md`, `{SID}-HAIKU-progress.md`, `{SID}-OPUS-progress.md`), do an explicit pairwise diff of their retro-note sections **before drafting** and call out any factual disagreement in the evidence pack. This is the kind of meta-correctness check no automated harness performs because it requires reading prose against prose.

Concrete procedure during step 2 (Gather the evidence pack):

1. For each per-implementer progress file, extract the structured retro notes (the `## Retro notes` section, or any `surprise:`/`decision:`/`win:`/`friction:`/`deferred:`-tagged bullets).
2. Group bullets by the task or phase they reference. Compare any two implementers' bullets for the **same** task.
3. If two implementers report contradictory facts about a measurable observation (e.g., "byte diff identical" vs "input map(4) 216 bytes, canonical map(5) 391 bytes"), the evidence pack must:
   - Flag the disagreement with both quotes verbatim,
   - Identify which is grounded in concrete measurement (lengths, byte sequences, exact symbol names) and which is grounded in inference,
   - Mark the inference-grounded one as suspect until the disagreement is resolved.

This is what catches errors that no test gate caught — like a SPRINT-0002-retro-style "haiku conflated `getter == round_trip(input)` with `input == round_trip(input)`" finding. The drafters can then ground their retros on the pre-resolved disagreements rather than re-discovering them in parallel.

If the disagreement is unresolvable from evidence alone (e.g. the executors made different measurements with no shared baseline), surface it as an Ambiguity item in the merged retro rather than picking arbitrarily.
