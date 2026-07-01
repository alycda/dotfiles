---
name: deferred
description: Capture a punted item for the current cycle — appends a tagged bullet to retro-notes.md
argument-hint: <what you punted and why>
---

You are appending a `deferred:` retro note for the user's current Linear cycle.

## Inputs
- Tag: `deferred`
- Body: `$ARGUMENTS`

## Steps

1. **Resolve current cycle** via the Linear MCP:
   - Call `mcp__claude_ai_Linear__list_cycles` with `teamId: c2a26e30-58ca-48d4-a8dd-abb56557dcca` and `type: current`.
   - Read the `title`; convert to directory: `"Cycle 16"` → `CYCLE-16`.

2. **Resolve paths**:
   - Cycle dir: `~/Work/sprints/<DIR>/`
   - Notes file: `~/Work/sprints/<DIR>/retro-notes.md`

3. **Append the note**:
   - Create the file with `# <Cycle Title> retro notes` header if missing.
   - Append `- [YYYY-MM-DD HH:MM] deferred: <BODY>`.

4. **Confirm** in chat: `Logged deferred to <relative path>`.

## Notes
- Deferrals should record the *trigger* (what got in the way) and the *carry-forward* (where it should go next cycle). If the body is missing either, ask one short follow-up.
- Do not query other sources.
