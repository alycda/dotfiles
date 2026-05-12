# Kanban Context Additions for the Sprint Skills

Small additive sections to bolt onto your existing `sprint-planner`, `sprint-execute`, and `sprint-retrospective` SKILL.md files to make them kanban-aware. The skills work standalone without these — these enable the cross-sprint feedback loop when run inside sprinter's kanban pipeline.

**Where to add:** copy each section verbatim into the corresponding skill's SKILL.md, just before the existing "Notes and edge cases" section. They're additive — none of the existing skill content needs to change.

---

## Addition for `sprint-planner` SKILL.md

```markdown
## Kanban context (when run as a kanban worker)

If `HERMES_KANBAN_TASK` env var is set, this skill is running inside a kanban worker spawned by sprinter (or another orchestrator). Behave as follows:

### On entry: read parent handoffs

Call `kanban_show()` first thing. The response includes:

- **Task body** — the sprint scope and Linear ticket context (use this in place of the user-asks-for-intent step)
- **Parent handoffs** — completion metadata from upstream tasks. Look for:
  - From upstream `retro-*` tasks of prior sprints: `key_lessons`, `patterns_to_carry_forward`, `antipatterns_to_avoid`. These are cross-sprint feedback — use them.

If parent handoffs include `key_lessons` from prior sprint retros, fold them into a "Lessons from prior sprints" section in the intent paragraph that all three drafters and critics see. Treat them as Gene Transfusion exemplars: not commands, but evidence of what worked / didn't on adjacent sprints.

### Skip the interactive intent capture

When kanban context is detected, the body of the kanban task IS the intent. Skip step 1 (Capture the raw intent) and step 2 (Interview to sharpen). Go straight to allocating the sprint id and producing drafts.

### On exit: structured completion

After writing the merged plan to `docs/sprints/{SID}.md`, call:

```python
kanban_complete(
    summary=f"Sprint plan {SID} created at docs/sprints/{SID}.md",
    metadata={
        "sprint_id": SID,
        "plan_path": f"docs/sprints/{SID}.md",
        "tickets_covered": [...],   # Linear IDs from the task body
        "sdk_targets": [...],
        "task_count": N,            # number of - [ ] items
        "phase_count": M,
    }
)
```

This metadata becomes the `exec-*` task's parent handoff — the executor reads `sprint_id` and `plan_path` from it via its own `kanban_show()`.
```

---

## Addition for `sprint-execute` SKILL.md

```markdown
## Kanban context (when run as a kanban worker)

If `HERMES_KANBAN_TASK` env var is set, this skill is running inside a kanban worker spawned by sprinter (or another orchestrator). Behave as follows:

### On entry: read parent handoffs

Call `kanban_show()` first thing. Look for:

- From upstream `plan-*` task: `sprint_id`, `plan_path`, `tickets_covered`, `sdk_targets`. These tell you which sprint to work on; skip the interactive "pick the sprint" step.

If `plan_path` is missing or doesn't exist on disk, that's a hard failure — refuse and call `kanban_block` with reason "plan handoff incomplete: plan file missing at {plan_path}".

### Implementer choice in kanban context

In kanban context, the user is not actively driving the executor session. Default behavior:

- If the kanban task body explicitly names an implementer (e.g., `executor: opus` in metadata), use that
- Otherwise, default to `opus` — the safest pick for autonomous execution given the existing solo-vs-quad rule favoring opus when verification gates are programmatic
- Surface the choice in the first `kanban_comment` so the user can intervene if they want to change it before significant work happens

### On exit: structured completion

After all `- [ ]` are flipped to `- [x]` (or hard-blocked), call:

```python
kanban_complete(
    summary=f"{SID} executed: {tasks_done}/{tasks_total} tasks, {len(blockers)} blockers",
    metadata={
        "sprint_id": SID,
        "plan_path": f"docs/sprints/{SID}.md",
        "executor": chosen_implementer,
        "tasks_done": tasks_done,
        "tasks_total": tasks_total,
        "blockers": [...],          # Blocker text from ## Blockers section, if any
        "iteration_commits": K,     # commits past plan's budget; can be 0
    }
)
```

If there are unrecoverable blockers and the sprint is genuinely stuck, call `kanban_block(reason=...)` instead of `kanban_complete`. Sprinter / the user can then unblock manually.
```

---

## Addition for `sprint-retrospective` SKILL.md

```markdown
## Kanban context (when run as a kanban worker)

If `HERMES_KANBAN_TASK` env var is set, this skill is running inside a kanban worker spawned by sprinter (or another orchestrator). Behave as follows:

### On entry: read parent handoffs

Call `kanban_show()` first thing. Look for:

- From upstream `exec-*` task: `sprint_id`, `plan_path`, `executor`, `tasks_done`, `tasks_total`, `blockers`, `iteration_commits`. Use these to seed the evidence pack — you don't need to re-derive checkbox counts or executor identity.

### On exit: structured completion with cross-sprint payload

This is the load-bearing handoff for cross-sprint feedback. After writing the merged retro to `docs/sprints/{SID}-retro.md`, extract structured signals from the retro and pass them downstream:

```python
kanban_complete(
    summary=f"Retro for {SID}: {len(key_lessons)} lessons surfaced",
    metadata={
        "sprint_id": SID,
        "retro_path": f"docs/sprints/{SID}-retro.md",
        "key_lessons": [
            # 3-5 actionable strings, e.g.:
            # "Programmatic verification gates are mandatory; free-form retro tasks drift toward 'plausible'"
            # "Iteration commit budget should be ≥1 for sprints touching infrastructure"
        ],
        "patterns_to_carry_forward": [
            # 1-3 strings naming patterns to continue, e.g.:
            # "Solo opus + 5 programmatic verification gates"
            # "Mark quad-only acceptance items with **(quad-only):** prefix in plan"
        ],
        "antipatterns_to_avoid": [
            # 1-3 strings naming what NOT to do, e.g.:
            # "Free-form retro tasks where the executor self-grades observation accuracy"
            # "Implicit iteration-commit budgets — must be explicit and annotated"
        ],
        "executor_assessment": "<one-paragraph string from the merged retro's Executor assessment section>",
    }
)
```

The downstream `plan-*` tasks read these arrays via `kanban_show()` parent handoffs. The planner addition section in this same reference file describes how they get folded into next-sprint planning.

### How to extract the structured payload from prose

The merged retro already has these sections — you're just lifting them out:

| Retro section | Metadata field |
|---|---|
| "Lessons for the next sprint" | `key_lessons` (verbatim or lightly trimmed) |
| "What went well" + cross-references in the merge | `patterns_to_carry_forward` (the 1-3 most transferable items) |
| "What went poorly" + "Root causes" | `antipatterns_to_avoid` (the actionable inverses, not just the symptoms) |
| "Executor assessment" | `executor_assessment` (verbatim paragraph) |

Cap each list at 5 items. The payload is for downstream planners; they shouldn't drown in retro detail.
```

---

## Verifying the additions work

After adding the sections:

1. Run sprinter on a small test ticket (one parent, two subissues, both ≥3 points) — expect 2 sprints in the manifest.
2. Approve the manifest. Sprinter creates 6 kanban tasks (2 plans, 2 execs, 2 retros).
3. The dispatcher picks up `plan-*` tasks. Each calls `kanban_show()` → sees its sprint context → drafts.
4. Watch the kanban dashboard. As each task `kanban_complete`s, downstream tasks transition from `blocked` to `ready` to `running`.
5. After the first sprint's retro completes, the second sprint's plan starts — and its planner's first action is to log "Lessons from prior sprints" pulled from the first retro's `key_lessons`. That's the cross-sprint feedback loop in action.

If the loop doesn't fire (the second planner doesn't reference any prior lessons), check:
- Is `kanban_complete(metadata=...)` actually being called? (Look at the task event log.)
- Are the metadata field names consistent? (Typos in `key_lessons` vs `keyLessons` will silently fail.)
- Does the second planner's `kanban_show()` show parent handoffs? (Confirm via `kanban_show` tool call output.)

## What if the user doesn't want kanban awareness yet?

The additions are no-ops outside kanban context (the `if HERMES_KANBAN_TASK` guard handles that). Skills work exactly as before for manual invocation. So adding the sections is non-destructive — there's no reason not to add them, even if you're not using sprinter yet.
