---
name: sprint-execute
description: Execute a planned sprint by handing it to one of opus, gpt-5.5, or gemini. Use whenever the user wants to start, run, work, or implement a sprint, kick off sprint execution, or do the work in a SPRINT-XXXX.md plan. Lets the user pick the implementer model, updates the ledger (status + executor) to track progress, and instructs the executor to check off `- [ ]` boxes as tasks are completed.
---

# Sprint Execute

The companion to `sprint-planner`. A planner sprint produces a checkbox plan at `docs/sprints/SPRINT-XXXX.md`; this skill picks the sprint, the implementer, and runs the work — then keeps the ledger honest about who did what and where it stands.

## What this skill is and is not

- **Is**: a controlled handoff. It picks a sprint plan, picks an implementer model (opus / gpt-5.5 / gemini), updates the ledger, and runs the implementer with instructions to tick off `- [x]` checkboxes as it goes.
- **Is not**: a multi-model merge. Unlike `sprint-planner`, only **one** model executes — the others would just collide on the same files. The choice of model is the user's call, not a vote.

## Workflow

### 1. Pick the sprint

Default to the most-recent sprint with status `in-progress` (resuming work) or, failing that, `planned` (starting fresh). If the user named a sprint id explicitly, use that.

```bash
python3 .claude/skills/sprint-planner/scripts/ledger.py list
```

If multiple candidates exist and the user didn't specify, ask which one. Verify the plan file `docs/sprints/{SID}.md` exists before going further — no plan, no execution.

### 2. Pick the implementer

Ask the user via `AskUserQuestion` which model should implement (single question, three options):

- **opus** — runs in *this* Claude Code session. Use when the user wants tight oversight, fine-grained control, or interactive course-correction.
- **gpt-5.5** — dispatched via the `codex` CLI in YOLO mode. Use for autonomous bulk execution; trades interactivity for throughput.
- **gemini** — dispatched via the `gemini` CLI in YOLO mode. Use as an alternative autonomous implementer (different model, different blind spots).

If the user has already said which one in their original message, skip the question.

### 3. Mark the ledger

Atomically reflect the choice before any work begins:

```bash
python3 .claude/skills/sprint-planner/scripts/ledger.py set-status   {SID} in-progress
python3 .claude/skills/sprint-planner/scripts/ledger.py set-executor {SID} {opus|gpt-5.5|gemini}
```

The ledger is the source of truth for "who is currently working on what". Set it *before* dispatch so a crash mid-run still leaves an accurate trail.

### 4. Run the implementer

#### 4a. opus (this session)

You are Opus. Read `docs/sprints/{SID}.md` in full. Then work the checkboxes top-to-bottom:

1. Pick the next unchecked `- [ ]` task.
2. Implement it. If a task is bigger than expected, split it in your head — don't rewrite the plan unless the user asks.
3. As soon as a task is genuinely done (code written, tested where applicable), edit the plan file to flip `- [ ]` → `- [x]` for that line. Don't batch the check-offs at the end — the file is the live progress signal.
4. **Log retro notes as you go.** See "Retro notes during execution" below. Append a short entry to the plan's `## Retro notes` section after each task, while the context is fresh — not at the end. This survives compaction; your working memory does not.
5. If you hit a blocker that requires a user decision (ambiguous spec, missing access, scope question), stop and ask. Don't guess your way past a real fork in the road.
6. Use `TaskCreate`/`TaskUpdate` to mirror the sprint tasks if it helps you stay coherent across many tasks. Optional but recommended for sprints with >5 tasks.

When all checkboxes are `[x]` (or the user calls it done), proceed to step 5.

#### 4b. gpt-5.5 (codex)

Dispatch in YOLO mode. The CLI is verified — don't second-guess the flags:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"
```

Prompt:

> You are implementing sprint **{SID}**. The plan is at `docs/sprints/{SID}.md`. Read it in full first.
>
> Work the `- [ ]` checkboxes top-to-bottom. For each task: implement it, then immediately edit the plan file to flip that line's `- [ ]` to `- [x]` so progress is visible on disk. Do not batch the check-offs.
>
> **Log retro notes as you go.** After each task, append a 1–3 line entry to a `## Retro notes` section at the bottom of the plan file (create the section if it doesn't exist). Use these tags, one per line, only the ones that apply: `- surprise: ...` (something diverged from the plan), `- decision: ...` (an ambiguity you resolved and how), `- win: ...` (something that worked better than expected, worth repeating), `- friction: ...` (a non-blocking annoyance or near-miss), `- deferred: ...` (work you noticed but consciously left out of scope). Skip a task only if none apply. These are the inputs for the retrospective — write them while context is fresh, not at the end.
>
> Stay within the sprint's scope — non-goals in the plan are non-goals. If you hit a real blocker (ambiguous requirement, missing access, decision the plan didn't make), stop and write a short note at the bottom of the plan under a `## Blockers` heading, then exit. Otherwise, keep going until every checkbox is `[x]`.
>
> Do not modify the ledger; the orchestrator handles that. Do not touch `docs/sprints/drafts/` — those are historical.

#### 4c. gemini

Same shape, different CLI:

```bash
gemini -y -p "<prompt>"
```

Use the same prompt as 4b, just substituting the agent self-identifier if you'd like.

### Retro notes during execution

The `sprint-retrospective` skill runs after execution and only sees what's on disk. The plan file's `## Retro notes` section is the durable surface for everything that would otherwise live in the executor's working memory and get lost — to compaction (opus path), to process exit (codex/gemini paths), or to plain forgetting between task and end-of-sprint. Treat it as load-bearing.

What goes in:

- `surprise:` something diverged from the plan — a task was harder/easier than expected, an assumption was wrong, a dependency behaved differently
- `decision:` the plan was ambiguous and the executor picked something — what was picked and the one-line reason
- `win:` a pattern, refactor, or tactic that worked better than expected and is worth repeating
- `friction:` a non-blocking annoyance or near-miss — slow tests, a confusing API, a flaky tool, a fix that took three tries
- `deferred:` work the executor noticed but consciously left out of scope, with one line on why

What does *not* go in: progress narration, restating what the task was, or anything already obvious from the checkbox state or git diff. The retro will read those directly. Only write what's *not* recoverable from the artifacts.

Cadence: append after each task, not at the end of the sprint. End-of-sprint logging is exactly the failure mode this section exists to prevent.

### 5. Reconcile and close out

When the implementer returns (or you finish, in the opus case):

1. Re-read `docs/sprints/{SID}.md`. Count remaining `- [ ]` boxes.
2. If zero unchecked **and** no `## Blockers` section was added: mark done. (A `## Retro notes` section is *expected* and not a signal of incompleteness — it's the input for `sprint-retrospective`.)
   ```bash
   python3 .claude/skills/sprint-planner/scripts/ledger.py set-status {SID} done
   ```
3. If there are remaining unchecked boxes or a blockers note: leave status at `in-progress` and surface the gap to the user. Don't auto-mark done on partial work — the ledger is supposed to reflect reality.
4. Leave the `executor` field set. It's a record of who ran the sprint, not just a current-lock; future re-runs by a different model would overwrite it via `set-executor`.

### 6. Report back

One short message: which sprint, which implementer, how many tasks were checked off vs. left, and any blockers. Don't re-dump the plan — point at the file.

## Ledger fields used by this skill

| Field | Meaning |
|---|---|
| `status` | `planned` → `in-progress` (on dispatch) → `done` (on full completion). Stays `in-progress` if any checkboxes remain. |
| `executor` | `opus`, `gpt-5.5`, or `gemini`. Set on dispatch. The `set-executor` subcommand on `ledger.py` accepts `""` to clear. |

Other fields (`title`, `created`, `updated`) are managed by `ledger.py` automatically.

## Notes and edge cases

- **Resuming an in-progress sprint.** If the chosen sprint is already `in-progress` with an executor set, ask the user whether they want to continue with the same model (the natural default) or switch. Switching mid-sprint is fine — just call `set-executor` again — but flag it so the user knows the running history is mixed.
- **Plan file missing.** If `docs/sprints/{SID}.md` doesn't exist, refuse to proceed and suggest running `sprint-planner` first. Don't synthesize a plan on the fly — that's a different skill's job.
- **Plan with no checkboxes.** If the plan exists but has no `- [ ]` tasks, the planner output is malformed. Surface to the user; don't paper over it.
- **Don't touch drafts.** `docs/sprints/drafts/` is the planner's historical scratch. Execution operates only on the merged `SPRINT-XXXX.md`.
- **Don't delegate the opus path.** When opus is chosen, *this* session does the work. Don't shell out to `claude -p` — that would lose the conversation context the user is steering from.
- **Codex/gemini are headless.** They run non-interactively. If they need a decision, the prompt above tells them to write a `## Blockers` section and exit. Don't try to make them interactive.

## Pre-dispatch logistics

Before calling any implementer CLI — especially when dispatching from a worktree that does not contain the plan file (e.g. when implementers run in sibling worktrees while `docs/sprints/` lives at the parent project root) — preflight workspace access. Different CLIs have different sandbox shapes:

| CLI | Permission flag | Workspace confine |
|---|---|---|
| `codex exec` | `--dangerously-bypass-approvals-and-sandbox` | none (reads anywhere the user can) |
| `claude -p` | `--dangerously-skip-permissions` | none |
| `gemini -y` | `-y` | **confined to the working directory and `~/.gemini/tmp/<workdir-name>`** |

**Preflight rule.** If the implementer will be dispatched from a directory that does not include the plan file (`docs/sprints/{SID}.md`), do one of:

1. Stage the plan into the worktree before dispatch: `cp docs/sprints/{SID}.md <worktree>/SPRINT-{XXXX}.md` and reference it in the prompt at that path.
2. Verify the CLI can read the plan at its absolute path (test with a no-op prompt first).
3. Run from a parent directory that includes both the worktree and the plan.

The gemini CLI's workspace confine is the most restrictive of the three — gemini cannot read paths outside its working directory or its own temp dir. If the plan file's path resolves outside `<worktree>` and `~/.gemini/tmp/<workdir-name>`, gemini will refuse the read.

**Quota stop rule.** If an implementer CLI fails on a *deterministic* error (workspace path denial, missing file, permission denied), do **not** retry through the failure. Recovery retries on a deterministic error burn API quota — a few retries against a workspace-denial error can exhaust a daily token quota and lock the model out for 12+ hours. Treat the first deterministic failure as a hard stop: record an orchestration blocker, surface to the user, and either fix the harness or pick a different implementer. Retries are appropriate only for transient errors (network blips, temporary 5xx).

## Solo vs quad: when is solo execution safe?

The user's quad-implementer pattern (chatgpt + gemini + haiku + opus, four parallel branches, opus integrates fourth) buys two things: **bug-surface enumeration** (different models hit different blind spots, so the union of their bugs is bigger than any one's) and **cross-implementer retro-diff** (the SPRINT-0002 retro caught a haiku self-report error by reading retros side-by-side). Both have cost — orchestration overhead, quota across multiple CLIs, integration time.

Solo opus skips both. SPRINT-0003 ran solo successfully; SPRINT-0001/0002 used quad. The honest decision rule, derived from the SPRINT-0003 retro:

**Solo execution is appropriate when *all three* hold:**

1. **Per-phase verification gates are programmatic and comprehensive.** Every phase produces a runnable artifact (compile + test, not just file existence). Gate failures surface bugs *before* retro notes are written. SPRINT-0003 had a Phase 0 FFI symbol audit, a Phase 1 encoder isolation test, Phase 2 source-level grep guards, a Phase 3 prototype audit, and Phase 4 integration recipes — five distinct programmatic gates. Without that, solo's safety net (cross-implementer triage) is gone and nothing replaces it.
2. **Inherited machinery has no gaps.** All build recipes, host matrix, prebuilt fast-paths, docker fallbacks already work on the branch base. The sprint adds code; it does not stress-test infrastructure. SPRINT-0003 added 5 files into a 3-sprint-mature kitchen-sink scaffold with no machinery edits. If the next sprint touches `cmake/`, `scripts/`, the host matrix, or the FFI build pipeline, solo is the wrong call — quad's bug-surface enumeration is exactly what catches infrastructure regressions.
3. **All plan Open Questions can plausibly resolve on first run.** If the plan has Open Questions whose answers might require multiple attempts (a sentinel value, a header line range, an enum variant, a CBOR shape), solo gives one shot. Quad gives three or four. SPRINT-0003 had four Open Questions that all resolved cleanly on the first opus run; if even one had failed, the substring/CBOR/`_id`-clause re-pinning loop would have eaten the wall-clock advantage.

**If any of the three would not hold, run quad.** New FFI surface (observers, multi-peer, ABI drift), new runtime behavior (async callbacks, network sockets, BLE), or sprints that touch the build system are exactly the cases where quad's cross-validation pays off.

When the user invokes `/sprint-execute opus` and the sprint shape suggests quad would fit better, surface the trade-off in one sentence and let them confirm — don't override silently.

## Iteration-commit budget — annotate, don't ignore

Each sprint's plan should set an explicit budget for iteration commits past the final phase gate (typically 0–3). Even when the budget is zero — as in SPRINT-0002 and SPRINT-0003 — the executor (or integration pass) records, in Phase-N retro notes, every commit past the planned phase boundary with a one-line `what surfaced` tag. Examples:

- `iteration #1: docker build cached host CMakeCache.txt — fixed by isolating build-docker/ dir`
- `iteration #2: Apple ASan rejects detect_leaks=1 — added platform conditional`

This convention came from the SPRINT-0001 retrospective (which found 8 unbudgeted iteration commits framed as overruns). It carried through SPRINT-0002 (0 commits, budget honored) and SPRINT-0003 (0 commits, mid-phase friction caught and fixed inline rather than as iteration). Treat zero as a *target* under stable conditions, not a guarantee — observers, multi-peer, and ABI-drift sprints will likely require 1–3 iteration commits, and unannotated overruns are the failure mode this convention exists to prevent.
