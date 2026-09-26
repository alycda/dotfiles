---
name: review
description: >
  Review the changes since a fixed point along two axes that never see each
  other: Standards (does the diff conform to this repo's rubrics and its
  CODING_STANDARDS.md, judged by the code-critic agent) and Spec (does the
  diff do what the originating issue or spec asked). Trigger on "review
  this", "review since X", "code review", "does this match the issue", after
  an implementation commit and before a PR, or when power-of-ten hands off.
  Runs each axis in its own subagent with only the diff, reports them side by
  side without reranking, and applies mechanical findings as one separate
  conformance commit. Standards are enforced here, not in the
  implementer's context.
allowed-tools: Bash(jj status), Bash(jj log *), Bash(jj diff *), Bash(jj show *), Bash(git status), Bash(git log *), Bash(git diff *), Bash(git rev-parse *), Bash(git merge-base *), Bash(sem diff *), Bash(gh issue view *), Bash(gh pr view *)
---

# Review

Two-axis review of the diff between a fixed point and the working copy. The
shape is Matt Pocock's `code-review` skill (adapted, not installed: #90); the
Standards axis is this repo's own critic and rubrics instead of a Fowler
smell list.

- **Standards**: does the code conform to the rubrics `code-critic` holds
  (TigerStyle, Power of Ten and its Rust/FFI checks, Test Desiderata,
  Hyrum's Law, behavioral subtyping) and to whatever the repo documents?
- **Spec**: does the code do what the originating issue or spec asked, no
  less and no more?

Each axis runs in its own subagent so neither sees the other's reasoning,
and the implementation context that produced the diff sees neither until
they report. That is the point: the implementer carries exploration, the
change, and debugging; the reviewer carries a diff. Standards are imposed
here.

## Process

### 1. Pin the fixed point

Whatever Alyssa named: a change ID, bookmark, commit, tag, `main`. If she
named nothing, use `trunk()` in a jj repo and the merge-base with the
default branch in a git repo, and say so.

Take the working copy, not just committed history. Pocock's version
reviews `git diff <base>...HEAD`, which misses staged and unstaged work,
and its own `implement` skill runs it before committing, so the diff can
be empty. Here:

```sh
# jj: @ is the working copy, so this includes everything
jj diff --git --from 'trunk()' --to @
jj log -r 'trunk()..@' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'

# git: two-dot against the merge-base includes the working tree
base=$(git merge-base main HEAD)
git diff "$base"
git log --oneline "$base"..HEAD
```

Confirm the base resolves and the diff is non-empty before spawning
anything. A bad ref fails here, not inside two subagents.

### 2. Produce the diff the subagents will read

Prefer `sem diff --no-cosmetics <base>` when `sem` is on PATH: entity-level,
formatter churn removed, fewer tokens for the same information (see the
`entity-level-git` skill). Fall back to the unified diff above and say so.
Either way, the subagents get the diff text in their prompt. They do not
get the conversation.

### 3. Find the spec

In order:

1. Issue references in the commit messages (`#123`, `Closes #45`):
   `gh issue view 123 --json title,body`
2. A path Alyssa passed
3. A file under `docs/`, `specs/`, or `.scratch/` whose name matches the
   bookmark or branch
4. Ask. If she says there is none, skip the Spec axis and say so in the
   report. Do not invent a spec from the commit messages; that is the diff
   grading itself.

### 4. Find the standards sources

`CODING_STANDARDS.md` and `CONTRIBUTING.md` at the repo root, when they
exist. Paste their contents into the Standards prompt. Not `CLAUDE.md`: in
this repo it is orientation for the implementer, and its Meta section says
standards do not live there. The rubrics are already inside `code-critic`.

Skip anything tooling already enforces (statix, deadnix, clippy, rustfmt,
the CI frontmatter check). A finding a linter would have raised is noise.

### 5. Spawn both axes in parallel

**Standards**: spawn the `code-critic` subagent. Its prompt holds the diff
from step 2, the commit list, the pasted standards files from step 4, and
this brief:

> Judge only the diff. Report, per file or hunk, every place it violates a
> rubric rule or a documented standard, citing the rule or the file and
> line. Distinguish "violates the rule" from "violates its spirit". Label
> each finding **mechanical** (a fixed pattern; the fix needs no decision:
> a missing `#[must_use]`, a `cfg` inside a function body, a name that
> breaks a documented convention) or **judgement** (the fix is a design
> choice: a TigerStyle ordering, a Hyrum enumeration, a contract change).
> Skip anything a linter enforces. End with the single change that would
> most improve the diff. Under 400 words.

**Spec**: spawn a general subagent with no persona. Its prompt holds the
same diff and commit list, the spec text from step 3, and this brief:

> Judge the diff against the spec and nothing else. Report (a)
> requirements the spec asks for that are missing or partial; (b)
> behavior in the diff the spec did not ask for; (c) requirements that
> look implemented but where the implementation looks wrong. Quote the
> spec line for each finding. Under 400 words.

Neither prompt says the other axis exists. Neither subagent may spawn
further subagents; say so in the prompt, because the standards brief can
otherwise rediscover this skill and fan out again.

When the surface has no subagent mechanism (crush, a plain API wrapper),
run the two briefs sequentially in this context, Standards first, and say
in the report that the axes were not isolated.

### 6. Report

Two headings, `## Standards` and `## Spec`, each subagent's report verbatim
or lightly cleaned. Do not merge or rerank across them. A change can pass
one and fail the other, and picking a single winner is the masking the
separation exists to prevent. End with one line per axis: finding count and
the worst finding within that axis.

Then a **Merge Danger** block, which is what a PR body will want:

- **Door**: one-way or two-way. Can this be reverted by reverting the
  commit, or does it migrate data, publish a version, change a wire
  format, or delete something?
- **Blast radius**: one phrase, from the Hyrum enumeration in the Standards
  report when there is one (what observably moves, promised or not), else
  from the diff.

### 7. Apply mechanical findings, and only those

Mechanical findings become **one** conformance commit, separate from the
implementation commit, never an amend of it. The implementation commit is
the record of what the implementer did; the conformance commit is the
record of what review changed. Describe first, then edit
(`jj new -m "Conform: <what>"`; in git, commit with the same message), and
list each finding the commit addresses in its body, by rule name.

Judgement findings stay in the report. A design choice is Alyssa's, not
the reviewer's; do not touch the code for those, and do not open a second
round unprompted.

Before making the commit, say which findings it will carry. After it,
`review` does not re-run itself; if she wants a second pass, she asks.

## Handoffs

- **power-of-ten** runs before the code exists and hands off here at its
  Process step 5. The Rust/FFI checks it deliberately does not run are the
  Standards axis's job.
- **entity-level-git** owns `sem diff` and the fallback rules when sem is
  absent or the language is Dart.
- **jujutsu** owns revsets, `trunk()`, and what `@` means.
- **commit-craft** owns the conformance commit's message.
- The `outbound-comment-gate` rule applies unchanged: this skill never
  posts a review to GitHub. It writes commits and a local report.

## Why two axes

Code that follows every rubric but implements the wrong thing passes
Standards and fails Spec. Code that does exactly what the issue asked but
breaks the project's conventions passes Spec and fails Standards. Reporting
them separately stops one from hiding the other, and keeping them in
separate subagents stops one from reasoning its way to the other's
conclusion.
