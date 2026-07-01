---
name: surprise
description: Capture an unexpected finding for the current cycle — appends a tagged bullet to retro-notes.md
argument-hint: <what surprised you>
---

You are appending a `surprise:` retro note for the user's current Linear cycle.

## Inputs
- Tag: `surprise`
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
   - Append `- [YYYY-MM-DD HH:MM] surprise: <BODY>`.

4. **Confirm** in chat: `Logged surprise to <relative path>`.

## Notes
- Surprises are the highest-signal input for the bi-weekly retro merge. Write them verbatim.
- Do not query other sources.
