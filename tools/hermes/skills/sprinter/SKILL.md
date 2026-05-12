---
name: sprinter
description: Orchestrates plan → execute → retro pipelines across one or more sprints derived from Linear tickets, using Hermes Kanban as the durable substrate. Decomposes a Linear parent ticket (or single ticket) into sprint-sized chunks, creates a Kanban task pipeline per sprint, and wires retro outputs from sprint N to feed sprint N+1's planner. Use when the user wants to plan, execute, or retro multiple sprints across a Linear ticket with subissues — phrases like "plan sprints from this Linear ticket", "kick off SDKS-XXXX sprint", "orchestrate the SDK work", "set up sprints for the parent ticket". Wraps the existing sprint-planner / sprint-execute / sprint-retrospective skills as the per-sprint specialists; this skill is the cross-sprint orchestrator.
version: 0.1.0
metadata:
  hermes:
    tags: [sprint, orchestration, kanban, linear, multi-sprint]
    category: orchestration
    requires_tools: [kanban_create, kanban_link]
    requires_toolsets: [linear]
---

# Sprinter

Cross-sprint orchestrator. Reads a Linear ticket (with or without subissues), decomposes into one or more sprint-sized units, and creates a Hermes Kanban task pipeline that runs `sprint-planner` → `sprint-execute` → `sprint-retrospective` for each, with retro outputs feeding subsequent sprints' planners as parent handoffs.

This skill **orchestrates**. It does not plan, execute, or retro itself — those are the existing per-sprint specialist skills:

| Specialist skill | What it does | Where it runs |
|---|---|---|
| `sprint-planner` | Quad-pattern (codex + gemini + claude + Opus merge) → `SPRINT-XXXX.md` | Spawned as kanban worker |
| `sprint-execute` | Pick implementer (opus / gpt-5.5 / gemini), work checkboxes, log inline retro notes | Spawned as kanban worker |
| `sprint-retrospective` | Quad-pattern over evidence pack → `SPRINT-XXXX-retro.md` | Spawned as kanban worker |

## When to Use

Trigger when the user wants:

- Plan one or more sprints from a Linear parent ticket with subissues
- Plan a single sprint from a single Linear ticket
- Set up the full plan → execute → retro pipeline for already-decomposed work
- Run multiple sprints in parallel where Linear dependencies allow
- Have retro insights from one sprint feed the next sprint's plan automatically

Phrases: "plan sprints from this Linear ticket", "kick off SDKS-XXXX sprint", "orchestrate the SDK work", "set up sprints", "decompose this parent ticket".

Do NOT use for:

- Single-sprint, single-ticket work where you're going to manually invoke `sprint-planner` / `sprint-execute` / `sprint-retrospective` yourself — that's still fine; sprinter is for when manual orchestration becomes friction.
- Tickets that aren't "sprint-sized" work in the first place (one-line bug fixes, doc tweaks, single-PR refactors). Decomposition heuristic will fold these into a parent sprint or surface them to the user.

## Inputs

| Input | Source | Required? |
|---|---|---|
| Linear ticket URL or ID | User | Yes — at least one |
| Decomposition heuristic | `references/decomposition-heuristic.md` | Built-in |
| Kanban task shapes | `references/kanban-task-shapes.md` | Built-in |
| Linear MCP fetch patterns | `references/linear-fetch-patterns.md` | Built-in |
| Specialist skills installed in target profile(s) | `~/.hermes/skills/software-development/sprint-{planner,execute,retrospective}/` | Yes — see Setup below |
| Kanban dispatcher running | `kanban.dispatch_in_gateway: true` (default) | Yes |

## Procedure

### Step 1 — Fetch the Linear ticket(s)

Read `references/linear-fetch-patterns.md` for dual-workspace handling. The user may have multiple Linear MCPs configured; route based on URL workspace prefix, or probe both and use whichever resolves.

For a parent ticket: fetch the parent + all subissues, including their estimates, labels, blocking relationships, descriptions.

For a single ticket: fetch just that ticket. Treat as a degenerate one-sprint case.

### Step 2 — Decompose into sprint manifest

Apply the heuristic in `references/decomposition-heuristic.md`:

- **Subissue with estimate ≥ 3** → its own sprint
- **Subissues with estimate 1-2** → batch into a multi-ticket sprint, optionally grouped by SDK target / theme
- **Subissue with no estimate** → flag to user; default to standalone sprint pending confirmation
- **Parent ticket with no subissues** → single-sprint manifest

Build a `sprint-manifest.yaml` in `docs/sprints/manifests/<parent-id>-<timestamp>.yaml` (see `templates/sprint-manifest.example.yaml`). Include sprint slug, ticket list, total estimate, SDK targets, and `blocked_by` relationships derived from Linear's `blocks`/`blockedBy` graph.

**Show the manifest to the user before creating any Kanban tasks.** Use `AskUserQuestion` with options like "approve as-is", "let me edit the manifest first", or "abort". This is the gate — wrong decomposition is hard to undo once kanban tasks are flowing.

### Step 3 — Create Kanban task pipeline

For each sprint in the approved manifest, create three linked Kanban tasks per `references/kanban-task-shapes.md`:

```
plan-{sprint_slug}     →  exec-{sprint_slug}     →  retro-{sprint_slug}
```

`kanban_link` enforces ordering: each downstream task is blocked until its upstream completes. `kanban_complete(metadata={...})` carries the handoff payload (sprint_id, plan_path, executor, etc.) — the next worker reads it via `kanban_show()`.

**Cross-sprint dependencies** from Linear's `blocks` graph become `kanban_link` edges between sprint pipelines: `retro-A` → `plan-B` if B blocked-by A in Linear.

**Cross-sprint retro feedback** from `references/kanban-context-additions.md`: retro tasks complete with structured `key_lessons` / `patterns_to_carry_forward` / `antipatterns_to_avoid` arrays in `metadata`. The next sprint's plan task reads these via `kanban_show()` and feeds them into `sprint-planner` as a "lessons from prior sprints" input section.

### Step 4 — Allocate sprint IDs in the ledger

Each `plan-*` task on entry calls `python3 .claude/skills/sprint-planner/scripts/ledger.py add "<title>"` to reserve a `SPRINT-XXXX` id. The id flows forward through `kanban_complete(metadata={sprint_id, ...})`.

Sprinter does NOT pre-allocate sprint IDs — that would create gaps if some sprints get cancelled or re-decomposed before they run. IDs are claimed lazily by the planner workers when they actually start.

### Step 5 — Report to the user

Output:
- The kanban dashboard URL (typically `http://localhost:<dashboard-port>/kanban`)
- The list of created tasks (slug → kanban id) for traceability
- The sprint count + parallelism map (which sprints can run concurrently, which are gated)
- Reminder: dispatcher will pick up `ready` tasks on next tick (60s default)

Don't dump the manifest into chat — the file is the artifact. Point at it.

## Decomposition Heuristic Summary

See `references/decomposition-heuristic.md` for full rules. Quick reference:

| Subissue shape | → Sprint placement |
|---|---|
| Estimate ≥ 3, single SDK | Standalone sprint |
| Estimate ≥ 3, cross-SDK | Standalone sprint, marked `cross-sdk: true` |
| Estimate 1-2, single SDK | Batch with other small subissues into a multi-ticket sprint |
| No estimate | Flag to user; default standalone pending confirmation |
| Has `blocks`/`blockedBy` to other subissues | Sprint dependencies derived from graph |
| Parent ticket only (no subissues) | Single-sprint manifest |

## Multi-Sprint Parallelism

Sprints with no `blocked_by` edges in the manifest fan out automatically — Kanban dispatcher claims multiple `plan-*` tasks at once (up to dispatcher concurrency limit). This is the **P1 Fan-out** pattern from Hermes Kanban docs.

Sprints with `blocked_by` edges form a DAG. Kanban honors the DAG via task linking — the dispatcher won't claim a task whose upstream isn't `done`. This is the **P2 Pipeline** pattern, generalized to multi-sprint.

## Setup (one-time, before first run)

1. **Specialist skills must be in Hermes form.** Copy your existing `~/.claude/skills/sprint-{planner,execute,retrospective}/` into `~/.hermes/skills/software-development/` (preserving structure). They work in Hermes unchanged because they shell out to `codex` / `gemini` / `claude` CLIs the same way Claude Code does. See `references/kanban-context-additions.md` for optional kanban-aware additions to each.

2. **Linear MCP must be configured.** `hermes mcp list` should show at least one Linear server. If you have multiple workspaces, both can be present — sprinter routes by URL prefix.

3. **Kanban dispatcher must be running.** Default config (`kanban.dispatch_in_gateway: true`) is fine. Verify with `hermes kanban dispatch status`.

4. **Optional — specialist profiles for per-stage routing.** If you want planner on Opus + executor on Codex + retroer on Sonnet, set up profiles per `references/kanban-task-shapes.md` "Profile assignment" section. Otherwise all stages run on default profile.

## Pitfalls

- **Decomposition without user review.** Never auto-create Kanban tasks. The manifest review step is non-negotiable — wrong decomposition cascades into wrong sprints.
- **Linear ticket without estimates.** The heuristic falls back to "ask user" rather than guessing. If a parent ticket's subissues are all unsized, surface that as a precondition: ask the user to estimate, or skip those subissues, before manifesting.
- **Subissue churn during dispatch.** If a Linear subissue gets renamed / re-estimated / deleted while sprinter is in flight, the manifest goes stale. Sprinter's manifest is point-in-time — it does not auto-re-sync. If subissues change materially, regenerate the manifest.
- **Skipping the kanban-context additions.** The existing sprint-planner / sprint-execute / sprint-retrospective skills work fine standalone. But if they don't read parent handoffs from `kanban_show()`, the retro→next-plan feedback loop is lost — you get parallel sprint execution but no cross-sprint learning. The additions in `references/kanban-context-additions.md` are small (~20 lines per skill) but load-bearing for the cross-sprint feedback property.
- **Kanban worker provider inheritance.** Workers inherit the parent profile's provider. If you want `sprint-planner` to run on Opus but the kanban dispatcher is on a different default, set per-task `assignee` to a profile whose default is Opus. See `references/kanban-task-shapes.md`.
- **Linear quota / rate limits.** Fetching a parent ticket + N subissues + their dependency graphs is a few API calls per sprint. Manageable for small parent tickets (5-10 subissues); for large epics (50+), consider chunked fetching or accept manifest delay.

## Verification

After running sprinter, verify:

- Manifest file exists at `docs/sprints/manifests/<parent-id>-<timestamp>.yaml`
- `hermes kanban list --board default` shows the expected `plan-*`, `exec-*`, `retro-*` tasks
- `kanban_link` graph matches manifest's `blocked_by` edges (`hermes kanban show <task-id>` shows upstream/downstream)
- Independent sprints (no `blocked_by`) are in `ready` status
- Dependent sprints are in `blocked` status awaiting their upstream
- Dashboard renders the pipeline correctly (`hermes dashboard` → Kanban tab)

## Slash Command Behavior

| Command | Behavior |
|---|---|
| `/sprinter <linear-url-or-id>` | Full pipeline: fetch → decompose → review manifest → create kanban tasks |
| `/sprinter --plan-only <linear-url-or-id>` | Stop after manifest review; don't create tasks |
| `/sprinter --from-manifest <path>` | Skip Linear fetch + decomposition; create tasks from an already-approved manifest |
| `/sprinter status` | List active sprinter-orchestrated pipelines (groups Kanban tasks by their `sprinter_run_id` metadata) |
| `/sprinter cancel <sprinter_run_id>` | Cancel all in-flight tasks for a given sprinter run; preserve completed work |

## Related

- Hermes Kanban: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban
- Hermes Profiles: https://hermes-agent.nousresearch.com/docs/user-guide/profiles
- Existing specialist skills: `sprint-planner`, `sprint-execute`, `sprint-retrospective`
- Generalized quad pattern: `try-cycle`
- Linear MCP integration: per the user's installed Linear MCP servers (multiple workspaces supported)
