# jj-state: an owner move during a long Bash command is marked seen

- STATUS: OPEN
- TAGS: agents, hooks, jj

## Description

Finding #4 of the code review of "agents(hooks): read the jj state before
writing to it" (run `20261003-203329-04655721`). It is the one finding that
"agents(hooks): fix the jj-state review findings" left open.

`.claude/hooks/jj-state` marks a Bash command that runs a jj look or write
as seen in PostToolUse, with the newest operation at the moment the command
**ends**. When the command runs long after its jj part, an owner move in
that time is marked seen without being reported:

```text
agent:  jj st && just test        # jj st shows @ = A, then tests run
owner:  jj edit B                 # while the tests run
hook:   PostToolUse -> seen = the op of `jj edit B`
agent:  Edit ...                  # not blocked; the agent still thinks @ = A
```

The window is the whole runtime of the command (builds, tests, `sleep`),
not milliseconds.

### Suggested approach

Keep the operation from the start of the command until it ends:

1. PreToolUse, Bash, when the command runs a jj look or write: record the
   current operation as *pending* for the key and workspace (a new
   `jj-state pending KEY` action, stored next to the seen record).
2. PostToolUse, a pure look: mark seen = the pending operation, not the
   newest. Anything after it is reported on the next check.
3. PostToolUse, a write: the agent's own operations come after the pending
   one, and must not be reported back to it. Options:
   - mark seen = newest only if every non-noise operation between pending
     and newest could be the command's own (count the jj writes in the
     command, or match `jj op log` args tags such as `args: jj describe
     ...` against the command line);
   - otherwise mark seen = pending, and accept one block on the agent's
     own operation.
4. A command whose PostToolUse never comes (interrupted, timed out): the
   pending record must not be mistaken for a look. Clear it on the next
   PreToolUse.

`jj op log -T` exposes `parents` (used for ancestry since the fix) and op
tags; check what jj 0.45.1 shows for `args` before relying on it.

### Done when

- The scenario above blocks the agent's next write and lists `jj edit B`.
- An agent's own `jj describe -m x && sleep 5` is not reported back to it.
- `tools/agent/test-jj-state` has a case for both, and all its checks pass.

## Open questions

- Is one extra block on the agent's own write (option "seen = pending")
  acceptable, or must own writes always pass?

## Verification
