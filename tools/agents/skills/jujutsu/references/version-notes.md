# jj v0.44 Version Notes

The jujutsu skill is pinned to jj v0.44. This file documents what differs from older
tutorials and blog posts, which flags are **removed** (not merely deprecated), and what
to watch when upgrading further.

Load this when:
- A command from a tutorial doesn't work as expected
- jj prints an "unknown flag" or "unexpected argument" error
- Alyssa asks "what changed in v0.44?"

Every claim below was verified against `jj --version` = 0.44.0 via `--help` output.

---

## Removed flags — these hard-error, they don't warn

These are the ones that actually break. Older tutorials use all of them.

### `jj git push --allow-new` — removed

Use `--named <name>=<revision>`, which creates the bookmark and tracks it in one step:

```
jj git push --named my-feature=@        # push @ as a new bookmark, auto-tracked
jj git push --named my-feature=@-       # same, for the parent
```

The old two-step (`jj bookmark track` then push) is no longer necessary for a bookmark
you are creating — `--named` "automatically tracks the bookmark if it is new."

### `jj describe --edit` — removed

`--editor` still exists but **does not mean the same thing**. In v0.44 it "forces an
editor to open when using `--stdin` or `--message`", i.e. it is a modifier on a supplied
message, not a standalone "open the editor" flag. Irrelevant for agent use, which always
passes `-m`.

---

## Revset syntax changes in v0.44 — these fail confusingly

Two revset behaviours changed. Neither produces an error that points at the real
cause, and both spellings appear throughout older notes.

### The `all:` modifier is gone

A multi-commit revset passed to `-d`/`--onto` used to need an explicit `all:` prefix
to confirm "yes, I meant more than one commit". In v0.44 the prefix is a parse error,
and the message blames the colon rather than the modifier:

```
$ jj rebase -r done -d 'all:heads(parents(done))'
Error: Failed to parse revset: `:` is not an infix operator
Hint: Did you mean `::` for DAG range?
```

The hint is a red herring — nothing here wants a DAG range. Drop the prefix; a bare
revset resolving to several commits is now accepted on its own:

```
jj rebase -r done -d 'heads(parents(done))'
```

### `description()` matches exactly, not as a substring

`description("foo")` is an **exact** match in v0.44. A miss returns the empty set
with exit status 0 — no error, no warning — so a script capturing it into a variable
gets an empty string and fails later, somewhere unrelated.

The exact form also fails when the description looks correct, because jj stores
descriptions with a trailing newline:

```
description("oops")            -> <empty>
description(exact:"branch-b")  -> <empty>   # the description IS "branch-b"
description(substring:"oops")  -> nkylquwn
description(glob:"*oops*")     -> nkylquwn
```

**Use `substring:` or `glob:` for descriptions.** The bare form only matches if you
supply the entire description including its newline, which in practice never happens.

---


## The `--destination` → `--onto` rename (still just an alias)

The destination flag for `jj rebase`, `jj split`, and `jj revert` is canonically
`--onto`/`-o`. The old spellings are registered as plain aliases in v0.44:

```
-o, --onto <REVSETS>
        [aliases: -d, --destination]
```

| Old (works, aliased) | Canonical |
| --- | --- |
| `jj rebase -d <dest>` | `jj rebase -o <dest>` |
| `jj split -d <dest>` | `jj split -o <dest>` |
| `jj revert -d <dest>` | `jj revert -o <dest>` |

**`jj squash` was not renamed** — it continues to use `--from`/`--into` (`-f`/`-t`).

**Tutorial impact:** Steve Klabnik's tutorial, Chris Krycho's posts, and older official
docs were written when `-d` was canonical. Their examples still run. New patterns Claude
writes should use `-o`.

---

## Config keys

The per-remote `remotes.<name>.auto-track-bookmarks` key that older notes describe as the
replacement for `git.auto-local-bookmark` / `git.push-new-bookmarks` is **not** present in
v0.44's defaults. Don't write it into a config expecting it to take effect. The relevant
real keys in v0.44:

```toml
[git]
track-default-bookmark-on-clone = true    # default

[snapshot]
auto-track = "all()"                      # default — governs what auto-snapshot picks up

[split]
legacy-bookmark-behavior = true           # default
```

`snapshot.auto-track` is the one that matters for the file-tracking rules in SKILL.md —
narrowing it is the config-level lever for keeping generated artifacts out of commits.
See `gitignore-recovery.md`.

---

## New since the older notes: `jj bookmark advance`

v0.44 has a `jj bookmark advance` subcommand (alias `a`) — "Advance the closest bookmarks
to a target revision." It is configured by two revset keys:

```toml
[revsets]
bookmark-advance-from = 'heads(::to & bookmarks())'   # default: the closest bookmarks
bookmark-advance-to = '@'                              # default: the working copy
```

**This does not make bookmarks auto-advance.** The "bookmarks aren't branches" rule in
SKILL.md still holds — nothing moves without an explicit command. `advance` is just
ergonomic sugar over `jj bookmark move <name> --to @` that finds the bookmark for you.
`bookmark-advance-to = '@-'` is a documented alternative for squash-heavy workflows.

---

## Behavior unchanged but commonly confused

### `jj file untrack` still requires the path to be ignored first

v0.44's help is explicit: "Paths to untrack. They must already be ignored. The paths
could be ignored via a .gitignore or .git/info/exclude (in colocated workspaces)."

So Rule 2 in SKILL.md's file-tracking section stands unchanged, and upstream issue
jj-vcs/jj#5225 (untrack without gitignoring first) is **still open** as of v0.44.

### `jj new --insert-before` / `--insert-after` apply per-commit

Long-standing behavior (since v0.18): repeating the flag means "insert relative to EACH
listed commit," not one global setting.

```
# This creates ONE commit with BOTH A and X as parents
jj new --insert-after A --insert-after X
```

Practical implication: usually you want a single `--insert-before`/`--insert-after`.

### `jj diff` default format is NOT git-style

Default is a side-by-side numbered format that looks broken to anyone used to git. Always
add `--git` for unified diff output. Same for `jj show`.

### Auto-snapshot timing

jj snapshots the working copy at the *start* of every command. So:

```
echo "new content" > foo.txt        # not yet snapshotted
jj st                                # NOW it gets snapshotted; @ updates
```

To inspect state without snapshotting (rare), use `jj --ignore-working-copy st` — almost
never the right move.

### Message via stdin

`jj describe --stdin` reads the description from stdin. Available on the message-taking
commands; not usually relevant for agent use, which passes `-m`.

---

## What to watch on future upgrades

- **`jj file untrack` for non-ignored files** — issue #5225. If it lands, Rule 2 in
  SKILL.md's file-tracking section gets simpler. Watch for it.
- **Bookmark advance defaults** — `revsets.bookmark-advance-to` is new enough that its
  default (`@`) may be revisited. If it ever becomes automatic on commit, the
  "bookmarks aren't branches" rule needs rewriting.
- **Native (non-git) backend.** The git backend is production-ready; a native jj backend
  is in development. Switching would require migration. Not imminent.

---

## Cross-references

Tutorials that may show older syntax:

- **Steve Klabnik's tutorial** (jj-tutorial.github.io) — uses `-d` in rebase examples;
  still runs via the alias. Mental-model content unchanged.
- **Chris Krycho's "jj init"** and follow-ups — uses `-d`. Same.
- **Official jj docs** — version-pinned; use the version switcher for v0.44 at
  `https://docs.jj-vcs.dev/`.

If a tutorial command fails in v0.44, check in this order:

1. Is it `--allow-new`? → use `--named <name>=<rev>`.
2. Is it `describe --edit`? → pass `-m` instead.
3. Is it a config key under `[remotes]`? → it probably doesn't exist; see Config keys.
4. Is it `-d`? → that one still works; the failure is something else.
