---
name: win
description: Capture a win for the current cycle — appends a tagged bullet to retro-notes.md
argument-hint: <what went well>
---

You are appending a `win:` retro note for the user's current Linear cycle.

## Inputs
- Tag: `win`
- Body: `$ARGUMENTS` — the user's free-form text

## Steps

1. **Resolve current cycle** via the Linear MCP:
   - Call `mcp__claude_ai_Linear__list_cycles` with `teamId: c2a26e30-58ca-48d4-a8dd-abb56557dcca` and `type: current`.
   - Read the `title` field of the returned cycle (e.g. `"Cycle 16"`).
   - Convert to directory name by upper-casing and hyphenating: `"Cycle 16"` → `CYCLE-16`.

2. **Resolve paths**:
   - Cycle dir: `~/Work/sprints/<DIR>/`
   - Notes file: `~/Work/sprints/<DIR>/retro-notes.md`

3. **Append the note**:
   - If the notes file does not exist, create it with the header:
     ```
     # <Cycle Title> retro notes

     ```
   - Append a bullet of the form:
     ```
     - [YYYY-MM-DD HH:MM] win: <BODY>
     ```
     Use the local date/time. If `$ARGUMENTS` is empty, ask the user one short follow-up question for the body and then proceed.

4. **Confirm** in chat with one line: `Logged win to <relative path>`. Do not repeat the body.

## Notes
- Do not edit existing entries.
- Do not summarize or paraphrase the body — write it verbatim.
- Do not query session history, GitHub, or other sources. This is a fast capture.
