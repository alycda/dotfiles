---
name: moment-docs
description: Editing or committing in a Moment document (any repo under ~/.moment/documents). Wrap every edit in `jj agent-start` / `jj agent-done` so the commit is attributed to the agent, not Alyssa.
---

# Moment documents

A Moment document is a jj + git repo at `~/.moment/documents/<id>/` that the
Moment desktop app edits. For the file format (`moment.yml`, `pages/`), read
the document's own `AGENTS.md`; Moment generates it, so never edit it.

## Every edit

```sh
jj agent-start <claude|codex|crush> "<what you are about to do>"
# ...edit files...
jj agent-done
```

- Name yourself: `claude`, `codex` or `crush`.
- crush: the author becomes `<model>@crush` (`@crush.local` for ollama), read
  from crush's config. If it says the model is unknown, add the model you are
  running as a third argument: `<provider>/<model>`.
- Always finish with `jj agent-done`. Without it, Alyssa's next commit in
  Moment is attributed to you.
- Check: `jj log -r '::@' -n 3` shows your change under your name and an
  empty draft under Alyssa's on top.

## Never

- Move `main` or any bookmark.
- Publish from Moment, or push anywhere.
- Rewrite, describe or squash changes you did not author.
- Commit with plain `git`.
