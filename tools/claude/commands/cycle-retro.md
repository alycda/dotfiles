---
name: cycle-retro
description: Synthesize a cycle retro from Linear, GitHub, agent sessions, and in-sprint retro-notes — only fires when the current Linear cycle ends within 24h
argument-hint: [--force to bypass the 24h gate]
---

You are generating a human-cycle retrospective for Alyssa Evans. This skill is normally cron-invoked the Monday evening before a cycle ends. It is also user-invokable for ad-hoc runs.

## Phase 0 — Gate on cycle endsAt

Call `mcp__claude_ai_Linear__list_cycles` with `teamId: c2a26e30-58ca-48d4-a8dd-abb56557dcca` and `type: current`. Read `title`, `startsAt`, `endsAt`.

Compute hours until `endsAt`:
- **`endsAt` is more than 24h away AND argument is not `--force`** → no-op. Echo a one-line "Cycle <title> ends <endsAt> (>24h away). Skipping retro." and exit. Do not write files.
- **`endsAt` is within 24h, OR argument is `--force`** → continue.

This gate is what makes the daily/weekly cron robust to cycle shifts: when the cycle slides in Linear, the gate slides with it.

## Phase 1 — Resolve paths

- Cycle dir: `~/Work/sprints/<DIR>/` where `<DIR>` is the upper-cased, hyphenated title (`"Cycle 17"` → `CYCLE-17`).
- Notes file (input): `<dir>/retro-notes.md` — the in-sprint slash-command output. May not exist if no notes were captured.
- Retro file (output): `<dir>/retro.md`
- Evidence pack dir (output): `<dir>/data/`

Create the cycle dir and `data/` subdir if missing. **Do not overwrite an existing `retro.md`** — if one exists, save the new one as `retro-vN.md` (next N) and tell the user at the end.

## Phase 2 — Gather evidence (parallel)

Run these in parallel and write each to its own file under `<dir>/data/`:

1. **Linear** (`data/linear.md`):
   - `mcp__claude_ai_Linear__list_issues` with `assignee: "me"`, `updatedAt: -P14D` (or the cycle window), `limit: 250`.
   - The response may be very large. If it exceeds the inline limit, jq through the saved tool-result file.
   - Bucket by `status`: Done / In Review / In Progress / Blocked / Triage / Backlog. Count each, list IDs+titles per bucket.

2. **GitHub** (`data/github.md`):
   - `gh search prs --author=alycda --updated=">=<cycle startsAt>" --limit=100 --json number,title,state,url,repository,updatedAt,createdAt,isDraft`
   - Bucket by `state`: merged / open / closed-unmerged. Count cycle time for merged PRs (createdAt → updatedAt).
   - Also: `gh search issues --author=alycda --updated=">=<cycle startsAt>" --limit=30` for upstream bug reports.

3. **Agent sessions** (`data/sessions.md`):
   - Both `~/.claude/projects/` JSONL files and `hermes sessions list` modified within the cycle window.
   - For each substantive session (>10KB), extract the first user message (the topic) and skim for friction signals ("no", "stop", "still broken", "this isn't working", repeated corrections). Note: when reading large session files, spawn a Claude sub-agent via the Agent tool — this also handles cases where Hermes lacks full session access.
   - Output: a list of session topics + a short list of friction signals.

4. **In-sprint retro-notes** (`data/retro-notes.md` — copy):
   - If `<dir>/retro-notes.md` exists, copy its contents into `data/`. This is the **highest-signal input** — it's the user's contemporaneous capture via `/win`, `/decision`, `/surprise`, `/deferred`, `/friction` slash commands.

## Phase 3 — Synthesize the retro

Read all four evidence files. Write `<dir>/retro.md` with this structure (mirrors `~/Work/sprints/CYCLE-16/retro.md` as a template):

```
# Cycle <N> Retro

_Window: <startsAt> → <endsAt>_

_Sources: agent sessions; Linear (assignee=me); GitHub (author=alycda); in-sprint retro-notes._

## Outcome (quantitative)

- N Linear issues closed.
- M GitHub PRs touched (X merged / Y open / Z closed-unmerged).
- K upstream bug reports filed.
- J issues still `In Review` at cycle end → carryover.

## What went well
- ...concrete, evidence-cited bullets. Lean on `/win` and `/decision` notes; cross-reference Linear IDs + PR numbers.

## What could have gone better
- ...lean on `/friction`, `/surprise`, `/deferred` notes; surface review-stuck PRs (open >5d), abandoned drafts, recurring CI flake, rolled-forward toolchain debt.

## Action items for next cycle
- ...derived from `/deferred` notes + carryover Linear issues + open friction patterns.

## References
- Evidence pack: <dir>/data/
- Previous retro: <dir of CYCLE-(N-1)>/retro.md (if exists)
```

Rules for synthesis:
- **Quantify outcomes** with counts and IDs, not adjectives.
- **Cite sources**: every claim should be backed by a Linear ID, PR number, retro-note timestamp, or session topic.
- **Lean hardest on retro-notes** when present — they are the only source captured in the moment.
- If a retro-notes section is empty or thin, say so explicitly (the cron run is then leaning on Linear/GitHub/sessions; that's worth flagging).
- Single-model synthesis by default. Multi-model is not built in here — if you want triple-distillation, run this skill and then have the user pipe the result through codex/gemini themselves.

## Phase 4 — Update the cron's next-run hint

After writing the retro, query Linear for the **next** cycle's `endsAt` (`type: next`). Note it in chat so the user can verify the schedule is still aligned. Do not attempt to reschedule the cron from inside this skill (Hermes does not allow nested cron mutations); instead, if the next cycle has a non-standard length (≠14 days from current), surface that prominently:

> ⚠️ Next cycle (Cycle <N+1>) ends <date>, which is <X> days after this one (vs. usual 14). Consider `hermes cron edit cycle-retro` if the daily-poll cron doesn't catch the new boundary.

## Phase 5 — Report

One short message:
- Path to the new retro file.
- Top 2 lessons (one line each).
- Pointer to the evidence pack.

Do not re-dump the retro in chat — the file is the artifact.
