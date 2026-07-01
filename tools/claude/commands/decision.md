---
name: decision
description: Capture a decision (and why) for the current cycle — appends a tagged bullet to retro-notes.md
argument-hint: <decision and reasoning>
---

You are appending a `decision:` retro note for the user's current Linear cycle.

## Inputs
- Tag: `decision`
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
   - Append `- [YYYY-MM-DD HH:MM] decision: <BODY>`.
   - If `$ARGUMENTS` does not include the *why*, ask one short follow-up before writing. A decision without rationale is the kind of note that goes stale fastest.

4. **Confirm** in chat: `Logged decision to <relative path>`.

## Notes
- Do not paraphrase. Write the body verbatim.
- Do not query other sources.
