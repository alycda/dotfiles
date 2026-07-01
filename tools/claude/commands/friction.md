---
name: friction
description: Capture a pain point for the current cycle and evaluate whether to escalate to a Linear ticket
argument-hint: <what hurt and how often>
---

You are appending a `friction:` retro note for the user's current Linear cycle, AND evaluating whether the friction is large enough to warrant a Linear ticket.

## Inputs
- Tag: `friction`
- Body: `$ARGUMENTS`

## Steps

### 1. Resolve current cycle
- Call `mcp__claude_ai_Linear__list_cycles` with `teamId: c2a26e30-58ca-48d4-a8dd-abb56557dcca` and `type: current`.
- Read the `title`; convert to directory: `"Cycle 16"` → `CYCLE-16`.

### 2. Append to retro-notes
- Path: `~/Work/sprints/<DIR>/retro-notes.md`
- Create with `# <Cycle Title> retro notes` header if missing.
- Append `- [YYYY-MM-DD HH:MM] friction: <BODY>`.

### 3. Linear-size evaluation
Ask the user one question (use the harness's blocking question tool if available — `AskUserQuestion` in Claude Code; otherwise numbered options):

> How big is this friction?
> 1. **small** — gripe / one-time annoyance (no ticket)
> 2. **medium** — recurring; needs a ticket but not a sprint slot
> 3. **large** — blocking / compounding cost; needs a sprint slot

- **small** → done. Confirm in chat: `Logged friction to <path> (small, no ticket).`
- **medium** or **large** → continue to step 4.

### 4. Draft Linear ticket (medium/large only)
Gather context:
- Current branch (`git -C ~/Work/ditto-worktree rev-parse --abbrev-ref HEAD`).
- Last 5 commits on that branch (`git -C ~/Work/ditto-worktree log -5 --oneline`).
- Open PRs that mention the friction keywords (best-effort `gh pr list` filter).

Draft a Linear issue body:
```
## Friction

<BODY verbatim>

## Cycle context

- Captured during: <Cycle Title>
- Branch: <branch>
- Recent commits:
  <commits>
- Related open PRs: <list or "none">

## Size

<medium | large>
```

Pick a team (default `SDKs` = `c2a26e30-58ca-48d4-a8dd-abb56557dcca`; if the friction is clearly DevEx-y or SPO-y, propose that team instead and ask the user to confirm before filing).

Show the user the drafted title + body + team and ask **before** filing: "File this Linear ticket? (y/n/edit)".

- `y` → call `mcp__claude_ai_Linear__save_issue` with the drafted fields. Append the resulting issue ID back to the retro-notes bullet (e.g. `→ filed as SDKS-NNNN`).
- `n` → done. Confirm log saved.
- `edit` → ask the user what to change, then re-show.

### 5. Confirm
One line: `Logged friction to <path>` plus the Linear ID if filed.

## Notes
- Never auto-file a ticket without confirmation.
- If MCP write fails (auth/permissions), append the drafted ticket body to the retro-notes bullet so it's not lost.
- Do not query session history.
