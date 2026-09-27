# tasks

One directory per task, named with a HUID.

## HUID

A Human-Unique IDentifier: a UTC timestamp matching `[0-9]{8}-[0-9]{6}`,
optionally suffixed `(-[a-zA-Z0-9-]*)?`.

```text
tasks/YYYYMMDD-HHMMSS/TASK.md
tasks/YYYYMMDD-HHMMSS-claude/TASK.md
```

IDs are generated at human speed - never faster than one second apart - so they
collide rarely, and when they do, waiting a second and retrying is the fix.

Unlike a sequential counter, two branches can each add tasks and merge without
conflict. That is the property that matters in a repo whose history fans out
into independent lanes and collapses through an octopus merge: a counter would
collide at exactly that point.

Suffix when two people or two machines might land on the same second.

Each directory holds a mandatory `TASK.md` plus any attachments it references.

## TASK.md

```markdown
# Task title

- STATUS: OPEN
- TAGS: comma, separated

## Description

Markdown.
```

`STATUS` is `OPEN` or `CLOSED`. Everything after `## Description` is free-form
Markdown.

`just task "Some title"` creates a directory with a fresh HUID and seeds this
file, retrying once if the second is already taken.

Adapted from [tatr](https://github.com/tsoding/tatr#huid) and
[trask](https://github.com/marcsantiago/trask).
