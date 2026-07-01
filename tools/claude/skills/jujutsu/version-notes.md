# jj v0.36 Version Notes

The jujutsu skill is pinned to jj v0.36. This file documents what changed in v0.36
relative to older tutorials/blog posts, and what's worth flagging in v0.37+ if Alyssa
upgrades.

Load this when:
- A command from a tutorial doesn't work as expected
- jj prints an "unknown flag" or "deprecated" warning
- Alyssa asks "what changed in v0.36?"

---

## The big rename: `--destination`/`-d` → `--onto`/`-o`

In v0.36, the destination flag was renamed for `jj rebase`, `jj split`, and `jj revert`.
Reasoning: `--onto`, `--insert-before`, and `--insert-after` are all destination flags,
and calling one of them `--destination` was confusing.

| Old (still works with deprecation warning) | New |
| --- | --- |
| `jj rebase -d <dest>` | `jj rebase -o <dest>` |
| `jj rebase --destination <dest>` | `jj rebase --onto <dest>` |
| `jj split -d <dest>` | `jj split -o <dest>` |
| `jj revert -d <dest>` | `jj revert -o <dest>` |

**Note:** `--into` for `jj squash` was NOT renamed. Squash continues to use
`--from`/`--into`. The rename affects only the three commands above.

**Tutorial impact:** Steve Klabnik's tutorial, the official docs (depending on version
viewed), and Chris Krycho's posts were all written when `-d` was the canonical flag. They
will read as outdated examples — but `-d` still works in v0.36 with a deprecation
warning. Acceptable to use either, but new patterns Claude writes should use `-o`.

---

## Other v0.36 changes worth knowing

### `jj describe --edit` deprecated

Renamed to `--editor` for consistency. `--edit` still works with a deprecation warning.

```
jj describe --editor              # new
jj describe --edit                # still works, prints deprecation
```

Mostly irrelevant for agent use — the editor flag is only meaningful in interactive
contexts, which Claude avoids anyway.

### `git.auto-local-bookmark` and `git.push-new-bookmarks` deprecated

Replaced by `remotes.<name>.auto-track-bookmarks` (per-remote configuration). Old config
keys still read; new repos should use the new form.

```toml
# Old (deprecated):
[git]
auto-local-bookmark = true
push-new-bookmarks = true

# New:
[remotes.origin]
auto-track-bookmarks = "glob:*"
```

### `jj git push --allow-new` deprecated

To push a new bookmark, track it first:

```
jj bookmark track <name>@<remote>       # then
jj git push -b <name>
```

Or set up `remotes.<name>.auto-track-bookmarks` so new bookmarks are auto-tracked.

### `jj commit`, `jj describe`, `jj squash` accepting message via stdin

In v0.36, these commands gained the ability to read messages from stdin (e.g., for
piping). Not commonly relevant for agent use but worth knowing.

---

## Behavior unchanged but commonly confused

### `jj new --insert-before` / `--insert-after` apply per-commit

As of v0.18 (well before v0.36), specifying `--insert-before` or `--insert-after`
multiple times means "insert relative to EACH of the listed commits," not a single
global setting. This means:

```
# This creates ONE commit with BOTH A and X as parents
jj new --insert-after A --insert-after X
```

vs.

```
# This (old global behavior) is no longer how it works
```

Practical implication: usually you want a single `--insert-before` or `--insert-after`
per command.

### `jj diff` default format is NOT git-style

Default is a side-by-side numbered format that looks broken to anyone used to git. Always
add `--git` for unified diff output. Same for `jj show`.

### Auto-snapshot timing

jj snapshots the working copy at the *start* of every command. So:

```
echo "new content" > foo.txt        # not yet snapshotted
jj st                                # NOW it gets snapshotted; @ updates
```

If Claude needs to inspect the state without snapshotting (rare), use
`jj --ignore-working-copy st` — but this is almost never the right move.

---

## What's likely to change in v0.37+

Worth watching when Alyssa considers upgrading:

- **Configurable bookmark behavior.** Discussion has been ongoing about whether bookmarks
  should auto-advance like git branches when commits are made on top. The default has
  stayed "no" so far. If this changes, the "bookmarks aren't branches" rule in SKILL.md
  may need an update.
- **`jj file untrack` for non-ignored files.** Issue #5225 (file untrack should work even
  when the file isn't gitignored, with the untrack info stored in `.jj/info/exclude` or
  similar). If/when this lands, Rule 2 in SKILL.md's file-tracking section becomes
  simpler. Watch for this.
- **Native (non-git) backend.** Currently the git backend is production-ready. A native
  jj backend is in development. Switching backends would require migration. Not
  imminent.

---

## Cross-references

Tutorials that may show older syntax:

- **Steve Klabnik's tutorial** (jj-tutorial.github.io and steveklabnik.github.io) — uses
  `-d` in rebase examples. Otherwise current as of recent versions.
- **Chris Krycho's "jj init"** and follow-ups — uses `-d`. Mental model content
  unchanged.
- **Official jj docs** — version-pinned. Use the version switcher to view v0.36-specific
  docs at `https://docs.jj-vcs.dev/v0.36/` if needed.
- **Jujutsu for everyone** — tracked against v0.35 as of November 2025. Most v0.36
  changes don't affect tutorial content.

If a tutorial command fails in v0.36, the first thing to check is whether `-d` should
be `-o`, or whether a deprecated config key is in use.
