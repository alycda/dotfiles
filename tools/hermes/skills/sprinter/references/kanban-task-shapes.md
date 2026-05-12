# Kanban Task Shapes — Plan / Execute / Retro

How sprinter creates Kanban tasks for each sprint in the manifest. Three tasks per sprint, linked in a pipeline.

## The shape

For sprint with slug `<slug>` (e.g. `kitchen-sink-ffi-callback-contract`):

```
plan-<slug>          (assignee: planner profile)
    ↓ kanban_link (downstream blocked until plan completes)
exec-<slug>          (assignee: executor profile)
    ↓ kanban_link
retro-<slug>         (assignee: retroer profile)
    ↓ kanban_link (only when downstream sprint exists per manifest)
plan-<next-slug>     (gets retro-<slug> metadata as parent handoff)
```

Each task's `kanban_complete(metadata={...})` carries the structured handoff for the next stage.

## plan-* task

```yaml
title: "Plan SPRINT for: <ticket-titles or sprint title>"
assignee: planner-profile           # or default if no specialist profiles set up
body: |
  Sprint slug: <slug>
  Linear tickets: [<ID-1>, <ID-2>, ...]
  Estimate: <total>
  SDK targets: [<sdk-1>, <sdk-2>]
  
  <Linear ticket descriptions, concatenated, with section headers per ticket>
  
  Apply the sprint-planner skill to produce docs/sprints/SPRINT-XXXX.md.
  When complete, call kanban_complete with metadata:
    - sprint_id (e.g. SPRINT-0042)
    - plan_path (docs/sprints/SPRINT-0042.md)
    - tickets_covered (the Linear IDs)
    - sdk_targets
metadata:
  sprinter_run_id: <run-id>          # groups all tasks for this orchestration
  stage: plan
  manifest_path: docs/sprints/manifests/<parent-id>-<timestamp>.yaml
links:
  blocked_by: [<retro-IDs from upstream sprints, if any>]
```

The planner reads `kanban_show()` on entry to find:
- The body (sprint context + tickets to cover)
- Any parent handoffs from upstream retro tasks (cross-sprint feedback)

## exec-* task

```yaml
title: "Execute <sprint_id>: <short title>"
assignee: executor-profile
body: |
  The plan is at <plan_path> (will be filled in by parent handoff).
  
  Apply the sprint-execute skill. Pick implementer per user preference
  or sprint shape (see sprint-execute's solo-vs-quad rule).
  
  When complete, call kanban_complete with metadata:
    - sprint_id
    - executor (opus / gpt-5.5 / gemini)
    - tasks_done (count of [x] checkboxes)
    - tasks_total (count of [ ] + [x])
    - blockers (list, possibly empty)
    - iteration_commits (count past plan's budget)
metadata:
  sprinter_run_id: <run-id>
  stage: exec
links:
  blocked_by: [<id of plan-* task>]
```

The executor inherits `sprint_id` and `plan_path` from the planner's `kanban_complete(metadata={...})` via `kanban_show()` parent handoffs.

## retro-* task

```yaml
title: "Retro <sprint_id>: <short title>"
assignee: retroer-profile
body: |
  Apply sprint-retrospective skill. Generate evidence pack from:
    - the plan at <plan_path>
    - checkbox state
    - the ## Retro notes section in the plan
    - the ## Blockers section in the plan (if any)
    - git log within the sprint window
    - executor identity
  
  When complete, call kanban_complete with metadata:
    - sprint_id
    - retro_path (docs/sprints/SPRINT-XXXX-retro.md)
    - key_lessons (list of strings, ≤5 items, each one actionable)
    - patterns_to_carry_forward (list of strings)
    - antipatterns_to_avoid (list of strings)
    - executor_assessment (one-paragraph string)
metadata:
  sprinter_run_id: <run-id>
  stage: retro
links:
  blocked_by: [<id of exec-* task>]
  blocks: [<plan-* IDs of downstream sprints, if manifest declared them>]
```

The retroer's metadata is the **cross-sprint feedback payload**. Downstream planner tasks pick up `key_lessons`, `patterns_to_carry_forward`, `antipatterns_to_avoid` via their parent handoffs.

## Profile assignment

Three options for assigning workers, in increasing complexity:

### Option A — All tasks on default profile

Simplest. All tasks `assignee: default`. The default profile (Anthropic Enterprise) runs everything. Works because:

- `sprint-planner`'s quad pattern shells out to `codex`, `gemini`, `claude` CLIs — those are independent of the kanban worker's main provider
- `sprint-execute` lets the user pick the implementer interactively (still asks via `AskUserQuestion`)
- `sprint-retrospective` runs the same quad-shell-out pattern as planner

Drawback: the orchestrating session for each task is anthropic-default, which means token cost on Anthropic for orchestration even if the actual heavy lifting is on codex/gemini.

### Option B — Specialist profile per stage

Set up three Hermes profiles:

| Profile | Default model | Used for |
|---|---|---|
| `sprint-planner-profile` | claude-opus (heavier reasoning for merges) | `plan-*` tasks |
| `sprint-executor-profile` | claude-sonnet (or codex if executor pattern demands) | `exec-*` tasks |
| `sprint-retroer-profile` | claude-sonnet | `retro-*` tasks |

In sprinter manifest, set `assignee: sprint-planner-profile` etc. on each task. The kanban dispatcher spawns workers in the named profile.

Drawback: requires 3 profile setups. Configuration overhead.

### Option C — Co-locate profiles with the task

If you only want, say, the planner on a different profile but executor/retroer on default, mix and match. Manifest's `assignee` field is per-task.

## Idempotency keys

Sprinter passes a deterministic `--idempotency-key` per kanban task so re-running sprinter on the same manifest doesn't create duplicate tasks:

```
<sprinter_run_id>-<stage>-<sprint_slug>
```

Example: `sprinter-run-2026-05-08T14:23:00Z-plan-kitchen-sink-ffi-callback-contract`.

This makes "I closed my laptop, sprinter half-finished, let me re-run" safe — only the missing tasks get created.

## Workspace per task

Kanban supports per-task workspace dirs (`--workspace dir:<path>` or `--workspace clone-from:<git-url>`). For sprint work:

- `plan-*`: workspace is the project root (planner needs to read the repo to draft tasks)
- `exec-*`: workspace is the project root, possibly in a worktree if the user runs the quad pattern across multiple parallel implementer worktrees
- `retro-*`: workspace is the project root (retroer reads plan + git log)

Sprinter sets all three to the project root by default. If the user prefers worktree isolation per stage (e.g., the executor in a worktree, the retroer back at main), they can override per-task in the manifest before approval.

## Cross-sprint dependency edges

When manifest declares sprint B `blocked_by: [sprint A]`, sprinter creates these kanban links:

```
retro-A.blocks = [plan-B]
plan-B.blocked_by = [retro-A]
```

Note: B's *plan* is blocked by A's *retro*, not A's *exec*. This means B's planner sees A's retro lessons before drafting — which is the whole point of the cross-sprint feedback loop. If you instead linked `exec-A` → `plan-B`, B's planner would draft without retro feedback (lower-quality plans).

For sprints with no declared dependency, plan tasks fan out — dispatcher claims them in parallel up to the concurrency limit.
