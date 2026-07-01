---
name: sprint-planner
description: Multi-model sprint planning. Use this whenever the user wants to plan a sprint, draft a sprint, kick off sprint planning, create SPRINT-XXXX.md, or asks for a sprint plan / sprint doc — even phrased casually ("let's plan the next sprint", "draft a sprint for X"). Orchestrates codex, gemini, and claude CLIs to produce independent drafts, cross-critiques, and a merged final plan at docs/sprints/SPRINT-XXXX.md, and updates the sprint ledger.
---

# Sprint Planner

Given a concentrated **intent** from the user (a paragraph describing what the sprint should accomplish), produce a merged sprint plan at `docs/sprints/SPRINT-XXXX.md` built from three independent drafts (codex, gemini, claude) and three cross-critiques, and record the sprint in the YAML ledger.

## Why multi-model?

One model's sprint plan reflects one model's blind spots. Three independent drafts surface a wider set of tasks, risks, and sequencing ideas. Cross-critiques force each model to defend its choices against peers, exposing weak assumptions. The Opus merge step then synthesizes the strongest version — not the average, the best of each.

## Layout

```
docs/sprints/
├── ledger.yaml                        # tracked
├── SPRINT-0001.md                     # tracked — the merged final plan
├── SPRINT-0002.md
└── drafts/                            # gitignored
    ├── SPRINT-0001-CODEX.md           # draft from codex
    ├── SPRINT-0001-GEMINI.md          # draft from gemini
    ├── SPRINT-0001-CLAUDE.md          # draft from claude
    ├── SPRINT-0001-CODEX-critique.md  # codex critiquing gemini + claude
    ├── SPRINT-0001-GEMINI-critique.md # gemini critiquing codex + claude
    └── SPRINT-0001-CLAUDE-critique.md # claude critiquing codex + gemini
```

## Workflow

Follow these phases in order. Don't skip, don't parallelize across phases, but **do parallelize within phases** where noted — the three drafts are independent, and so are the three critiques once drafts exist.

### 1. Capture the raw intent

If the user's request is vague ("plan a sprint"), ask for a concentrated intent paragraph: the goal, rough scope, and any non-negotiables. If they've already given you one, proceed straight to the interview. Don't clarify here — the interview phase does that work.

### 2. Interview to sharpen the intent

Three independent drafts amplify whatever ambiguity is in the intent. A fuzzy intent produces three fuzzy (and divergent) plans, and the merge can't rescue that. Spend one round here to pin down scope before spending three CLI calls.

**Read the repo first.** Skim the obvious context — top-level `README.md`, `CLAUDE.md` if present, `docs/sprints/ledger.yaml` for recent sprint history, and any files the intent explicitly names. The interview should ask things you *can't* infer from the repo, not things you were too lazy to look up.

**Ask in one batched round**, not a back-and-forth. Use the `AskUserQuestion` tool with 2–5 questions covering whichever of these are genuinely ambiguous for this intent:

- **Scope boundary** — what's explicitly *out* of scope? (The single highest-leverage question — drafts otherwise balloon.)
- **Success signal** — what does "done" look like concretely? A merged PR? A metric moving? A demo?
- **Sequencing constraint** — any task that must land first, or any dependency on other teams / sprints?
- **Non-negotiables** — tech choices, patterns, or files that are fixed vs. open for the drafters to decide.
- **Size / timebox** — rough sprint length or effort ceiling, if the user has one in mind.
- **Known risks or prior attempts** — anything that's already been tried, or landmines the drafters should know about.

Skip questions the raw intent already answers. If the intent is already crisp (explicit scope, clear success criteria, named constraints), the interview can be a single confirmation question or skipped entirely — note that decision to the user and move on.

**Synthesize a refined intent paragraph** from the raw intent plus the answers, and show it back to the user in one line: *"Drafting against this intent — stop me if it's wrong: …"*. This refined paragraph is what every draft and critique in later phases will receive, so it must be self-contained (don't rely on the interview answers being visible downstream).

### 3. Allocate the sprint id and reserve it in the ledger

```bash
SID=$(python3 .claude/skills/sprint-planner/scripts/ledger.py next-id)
python3 .claude/skills/sprint-planner/scripts/ledger.py add "<short title>"
```

`add` also prints the id it assigned; prefer that over computing it twice. Use a short title derived from the intent (≤60 chars).

### 4. Generate three independent drafts — in parallel

Run all three CLI calls **in the same turn** (parallel Bash tool calls). Each agent writes directly to its own draft file. Hand each agent the same intent and the same instructions about structure.

The YOLO / non-interactive invocations — these have been verified, don't second-guess them:

- **codex**: `codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"`
- **gemini**: `gemini -y -p "<prompt>"`
- **claude**: `claude -p --permission-mode acceptEdits "<prompt>"`

Prompt each agent with:

> You are drafting sprint **{SID}**. Intent: *{intent}*.
>
> Write a sprint plan to `docs/sprints/drafts/{SID}-{AGENT}.md` (where AGENT is CODEX, GEMINI, or CLAUDE as appropriate for you). Freestyle the structure, but every concrete piece of work must be a checkbox task `- [ ] ...`. Cover goals, scope boundaries, task list with checkboxes, sequencing, risks, and acceptance criteria. Be concrete — task names should be things someone can actually start on.

Each agent runs headless; do not wait interactively. After all three return, verify the three files exist before moving on.

### 5. Generate three cross-critiques — in parallel

Once the drafts exist, ask each agent to critique the **other two** drafts. Again, run all three in parallel in the same turn.

Prompt each critiquing agent with:

> You drafted `docs/sprints/drafts/{SID}-{YOU}.md` for sprint **{SID}**. Read the other two drafts at `docs/sprints/drafts/{SID}-{OTHER_1}.md` and `docs/sprints/drafts/{SID}-{OTHER_2}.md`. Write a critique to `docs/sprints/drafts/{SID}-{YOU}-critique.md`.
>
> For each of the other two drafts: what is stronger than yours, what is weaker, what tasks are missing, what risks are underweighted, what sequencing is wrong. Be specific and cite task names. End with a short "if I were merging, I'd keep X from draft A and Y from draft B" section.

### 6. Merge with Opus

You (the Claude session running this skill) are Opus. **Do not delegate the merge to another CLI call.** Read all six files yourself — three drafts and three critiques — and write the merged final plan directly to `docs/sprints/{SID}.md`.

The merge is not an average. Prefer concrete, well-sequenced tasks. When drafts disagree, use the critiques as evidence: a task that two critiques called out as missing is probably a real gap; a task that two critiques called overengineered probably is. The final doc should feel like a single coherent plan, not a stitched compilation.

Required in the final file:
- A title line and one-paragraph restatement of intent
- Goals / non-goals
- Task list with `- [ ]` checkboxes (every actionable item)
- Sequencing (phases, dependencies, or ordering)
- Risks and mitigations
- Acceptance criteria / done-ness definition

### 7. Update the ledger

```bash
python3 .claude/skills/sprint-planner/scripts/ledger.py set-status {SID} planned
```

(The sprint is already `planned` from step 3; this is a no-op unless you want to jump it straight to `in-progress`. Leave at `planned` by default — the user decides when work starts.)

### 8. Report back

Tell the user: the sprint id, the final path (`docs/sprints/{SID}.md`), and a one-line summary of what the merge emphasized or deprioritized vs. the individual drafts. Don't re-dump the plan in chat — the file is the artifact.

## Ledger operations (reference)

`python3 .claude/skills/sprint-planner/scripts/ledger.py` subcommands:

| Command | What it does |
|---|---|
| `add "<title>" [--id SPRINT-XXXX]` | Register a new sprint as `planned`. Prints the id. |
| `list [--status S]` | List all sprints, optionally filtered. |
| `get SPRINT-XXXX` | Show one sprint's fields. |
| `set-status SPRINT-XXXX {planned,in-progress,done,abandoned}` | Change status. |
| `set-title SPRINT-XXXX "new title"` | Rename. |
| `remove SPRINT-XXXX` | Delete the row (does not touch the .md files). |
| `next-id` | Peek at what the next id would be without creating anything. |

Valid statuses: `planned`, `in-progress`, `done`, `abandoned`.

## Notes and edge cases

- **Ledger and file drift.** The ledger tracks sprint *records*; the `.md` files are the plans themselves. Removing a ledger row doesn't delete files, and vice versa. If a user asks "what sprints do we have?", trust the ledger. If they ask to read a plan, read the file.
- **Draft failures.** If one agent's CLI call fails (rate limits, network), surface that to the user and ask whether to retry that one agent or proceed with two drafts. Don't silently drop.
- **Re-planning.** If the user asks to redo a sprint plan, either overwrite the existing `SPRINT-XXXX.md` (and regenerate drafts) or allocate a new sprint id. Ask which.
- **Intent quality matters.** A one-line intent ("make the thing better") produces three bad drafts and a bad merge. The interview phase (step 2) exists precisely to catch this — don't skip it unless the raw intent is already explicit about scope, success, and constraints.
- **Distinguish measurements from narrative in retro tasks.** When a Phase-N task asks the executor to *capture* a measurable value (byte length, equality boolean, line count, named defaults, a count of N in some artifact), require it to ship as a programmatic dump (stderr/log emit that the executor pastes verbatim into retro notes), not a free-form bullet the executor writes from memory. Free-form retro entries are graded by the executor itself; under YOLO mode that grading drifts toward "plausible." Verification gates have hard pass/fail; observation-only retro tasks don't. **Concrete planner rule:** if the plan body contains a phrase like "capture the diff" or "record the size," it should also specify the exact `printf`/`grep`/`wc` command that produces the value, and the retro entry should be the command's output, not a paraphrase. SPRINT-0002 retro #1 is the case study — haiku conflated `getter == round_trip(input)` with `input == round_trip(input)` because the latter was a free-form retro task; a programmatic emit would have made the conflation impossible.
- **Mark execution-shape-conditional acceptance items explicitly.** Some Acceptance criteria only apply under the quad-implementer pattern (per-CLI workspace preflight evidence, cross-implementer retro-diff-clean) and are structurally N/A when the user later picks `/sprint-execute opus` for solo execution. The planner should write those items with a clear conditional tag — e.g. `**(quad-only):** ...` — so the executor and the retrospective don't confuse "N/A in solo mode" with "unmet." SPRINT-0003 had AC #13 and #14 both in this category; both correctly resolved as N/A in solo mode, but the plan didn't mark them upfront and the retro had to explain the resolution after the fact. **Concrete planner rule:** every Acceptance item that depends on the quad pattern (multi-implementer staging, no-op CLI probes, cross-implementer retro-diff, per-implementer progress files) gets a `**(quad-only):**` prefix. Items that hold for any execution shape are unprefixed.
