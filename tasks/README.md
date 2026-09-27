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

The one exception is `scripts/`, which holds the tooling behind the `just`
recipes rather than a task. It has no `TASK.md`, so nothing lists it as one.

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
file, retrying once if the second is already taken. `just task-edit` also opens
it in `$EDITOR`.

The recipes are global (`just -g task` works in any repo), so a repo that can't
track HUIDs gets them in `.tasks/` instead, which the global git ignore keeps
untracked. `TASKS_DIR` overrides where they go.

mise puts the task commands in `scripts/` on `PATH`. `import-issue` isn't one:
it only makes sense in this repo, so its recipe calls it by path.

`just import-issue 183` imports issue #183 from alycda/dotfiles the same way,
with the HUID taken from when the issue was opened and `issue-183` as its tag.
Closed issues also record what closed them. The logic is in
`scripts/import-issue`, with its GraphQL query and jq template next to it.

Adapted from [tatr](https://github.com/tsoding/tatr#huid) and
[trask](https://github.com/marcsantiago/trask).
