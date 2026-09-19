# Moment documents: version control

You are inside a Moment document: a colocated jj + git repository under
`~/.moment/documents/<id>/` that the Moment desktop app edits. The document's
own `CLAUDE.md` is Moment's and covers the file format (`moment.yml`,
`pages/`). This file covers committing. It applies to every document, because
Claude Code loads it from the parent directory.

## Commit as yourself

Alyssa needs to tell your changes from hers. A jj config scope
(`~/.config/jj/conf.d/moment-claude-authorship.toml`) makes jj use the
identity `Claude <noreply@anthropic.com>` here, but only for changes *created*
from your shell - jj records the author when a change is created, not when it
is described or committed. So:

1. **Before editing**, create your own change and drop Moment's empty draft:

   ```sh
   jj new -m "<what you are about to do>"
   jj abandon -r '@- & empty() & description(exact:"")'
   ```

   The abandon is a no-op when the draft holds unsaved edits; those stay in
   Alyssa's change underneath yours.

2. **Edit the files.** jj snapshots them into your change.

3. **When done**, hand Moment a fresh draft authored by Alyssa:

   ```sh
   env -u CLAUDECODE jj new
   ```

   Skip this and her next commit in Moment is attributed to you.

Check with `jj log -r '::@' -n 3`: your change shows `Claude`, the empty draft
on top shows Alyssa.

## Do not

- Move `main` or any other bookmark. Moment does not follow bookmark moves
  made outside the app.
- Publish (Moment's publish pushes to `git.moment.dev`).
- Rewrite, describe, or squash changes you did not author.
- Commit with plain `git`: it bypasses the jj author scope.
