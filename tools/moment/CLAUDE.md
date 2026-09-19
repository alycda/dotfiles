# Moment documents: version control

You are inside a Moment document: a colocated jj + git repository under
`~/.moment/documents/<id>/` that the Moment desktop app edits. The document's
own `CLAUDE.md` is Moment's and covers the file format (`moment.yml`,
`pages/`). This file covers committing, for every document.

Alyssa needs to tell your changes from hers, and jj records the author when a
change is created. So wrap every edit in:

```sh
jj agent-start claude "<what you are about to do>"   # before editing
# ...edit files...
jj agent-done                                        # when finished
```

`agent-start` creates your own change authored as `Claude` and drops Moment's
empty draft. `agent-done` hands Moment a fresh draft authored by Alyssa - skip
it and her next Moment commit is attributed to you. Check with
`jj log -r '::@' -n 3`.

## Do not

- Move `main` or any other bookmark. Moment does not follow bookmark moves
  made outside the app.
- Publish (Moment's publish pushes to `git.moment.dev`). Backups go to Soft
  Serve with `just -g moment-backup`, and only when Alyssa asks.
- Rewrite, describe, or squash changes you did not author.
- Commit with plain `git`: it bypasses the jj author identity.
