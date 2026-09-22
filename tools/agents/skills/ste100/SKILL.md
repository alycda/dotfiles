---
name: ste100
description: >
  Rewrite or lint English so it has exactly one reading, using ASD-STE100
  (Simplified Technical English) rules, on the surfaces Alyssa writes for agents
  and SDK users: skill descriptions and rule files under tools/agents/,
  CONCEPTS.md entries, docs/solutions symptoms and steps, commit and PR bodies,
  Rust `# Safety` and FFI doc comments, error strings, and tool descriptions.
  Trigger on "ste", "ste100", "one reading", "can an agent misread this",
  "lint the instructions", "tighten this", or when she edits a SKILL.md
  description or a rule file. Do not trigger on persona, constitution,
  brag-doc, failure-doc, or pushback text; voice is the point there. Carries no
  rule text: it delegates the rule set, examples, and linter to the pinned
  asd-ste100 skill and adds only what is specific to Alyssa's surfaces.
---

# STE100

This skill applies ASD-STE100 to the text Alyssa writes for readers who cannot
ask her what she meant: agents that parse a skill description, a developer who
reads an FFI safety contract, a future self who reads a symptom list. It adds
three things the generic skill does not have: a mode per surface, a project
dictionary, and handoffs to the other writing skills in this repo.

## The rules live in the pinned skill

Read `~/.agents/skills/asd-ste100/SKILL.md` before you rewrite anything. It
holds the 53-rule summary, the strict / STE-flavored split, the hedge rule
(a hedge is content, never cut one to shorten a sentence), and the output
contract. Its `references/writing-rules.md` has the full rule summary with
citations; its `examples/before-after.md` has worked examples.

If that directory does not exist, say so and stop. Do not reconstruct the
rules from memory. The skill is installed by `agent-skills.nix` from the
`nix-skills` pin in `lib/skills-sh.nix`.

## Mode by surface

Pick the mode from the surface, then state the mode in one line.

| Surface | Mode |
|---|---|
| `SKILL.md` frontmatter descriptions, `tools/agents/rules/*.md` | Strict |
| `CONCEPTS.md` entries | Strict |
| `docs/solutions/` frontmatter `symptoms`, numbered steps, commands | Strict |
| Rust `# Safety` sections, FFI doc comments, `unsafe` call-site comments | Strict |
| Error strings, log messages, tool and function descriptions, MCP tool schemas | Strict |
| Commit bodies, PR bodies | STE-flavored |
| `CLAUDE.md` lesson paragraphs, `docs/solutions/` prose sections, READMEs | STE-flavored |
| `SKILL.md` bodies (the prose under the frontmatter) | STE-flavored |
| `persona-core.md`, `personal-constitution*.md`, `company-values.md` | Never |
| Output of `brag-doc`, `failure-doc`, `communication-bridge --format=pushback` | Never |
| Talk abstracts, HTML decks, anything persuasive | Never |

For a surface not in the table: strict when an agent or a compiler-adjacent
reader parses it with Alyssa absent; STE-flavored when a person reads it for
the reasoning; never when voice is the point.

Strict keeps every fact, hedge, number, and scope qualifier. It changes form
only. A sentence that reads better because the rewrite supplied a cause or a
frequency is a different claim, not a rewrite.

## The dictionary is CONCEPTS.md

ASD does not permit redistribution of its dictionary, so the pinned skill
applies the principle (one word, one meaning) without a word list. This repo
has a word list: `CONCEPTS.md`. STE allows technical names outside the
dictionary as long as each name has one meaning and one spelling. Treat
`CONCEPTS.md` as that list.

1. Read `CONCEPTS.md` when it exists in the repo you are working in. Each
   heading is an approved technical name. Its "Flagged ambiguities" section
   lists the synonym pairs that already caused confusion.
2. Use each approved name verbatim. Do not vary it for style. "Profile" and
   "user environment" are different things there; a rewrite that swaps one
   for the other introduced a bug, not polish.
3. When a rewrite needs a term that has no entry, keep the term the source
   used and add one `Dictionary:` line after the output that proposes the
   entry: the name, one sentence of meaning, and the section it belongs
   under. Do not edit `CONCEPTS.md` unprompted.
4. When the source uses two names for one concept, pick the one
   `CONCEPTS.md` has. If neither is there, pick one, use it throughout, and
   report the choice in the `Dictionary:` line.

Outside this repo, ask once whether a glossary exists. If none does, apply
step 4 within the text and say so.

## Handoffs

This skill runs after the skills that own structure, never instead of them.

- **communication-bridge** owns audience and format. Run it first, then run
  ste100 on its output only when the target surface is in the strict or
  STE-flavored rows above. Never on `--format=pushback` output.
- **commit-craft** owns the seven rules (subject line, wrap, what-and-why).
  ste100 is a sentence-level pass on the body afterward, in STE-flavored
  mode. It does not touch the subject line; the 50-character limit already
  forces one reading.
- **brag-doc** and **failure-doc** produce records in Alyssa's voice. Do not
  run ste100 on their output. If she asks, say why and offer a strict pass on
  any quoted command or symptom inside the entry instead.
- **outbound-comment-gate** still applies. A rewrite that is destined for a
  PR comment, review, issue, or message is shown to Alyssa before it is
  posted, the same as any other body.

## Process

1. Name the surface and the mode in one line. If the surface is in a Never
   row, say so and stop.
2. Read the pinned `asd-ste100` SKILL.md. In strict mode also read its
   `references/writing-rules.md`.
3. Run the linter when it exists:

   ```sh
   python3 ~/.agents/skills/asd-ste100/scripts/ste-lint.py FILE
   python3 ~/.agents/skills/asd-ste100/scripts/ste-lint.py --baseline N FILE
   ```

   Use `--baseline` when adopting on an existing file: set N to the current
   hard-violation count so the run passes today and fails on regression. If
   `scripts/ste-lint.py` is absent, say "linter absent at this pin" and lint
   from the rule table instead. (This happened at the first pin: the rev
   nix-skills indexed on 2026-08-30 predated the linter. The pin has carried
   it since 2026-09-18. The fallback stays because a nix-skills pin can
   trail any upstream commit by days to weeks.)
4. Read `CONCEPTS.md` and collect the approved names.
5. Rewrite. Keep every fact, hedge, number, and scope qualifier. Keep every
   approved name verbatim. Keep code, paths, flags, and command output
   verbatim; STE applies to the prose around them, never to them.
6. Output per the section below.

## Output

Default: the rewritten text alone, as the pinned skill specifies. Then, only
when there is something to report, one line each:

- `Kept as-is:` a phrase kept longer on purpose and the precision a shorter
  form would have lost.
- `Dictionary:` a proposed `CONCEPTS.md` entry or a synonym choice made.
- `Linter:` "absent at this pin" or the hard-violation count before and
  after.

When Alyssa asks to see the reasoning ("show the diff", "which rules"), use
the pinned skill's rule table format.

## Examples

**A skill description sentence, strict.**

Before:

> Also trigger when the user wants to see a few different approaches next to
> each other or wants to compare how things could be implemented, since the
> right mechanism for that is going to be sibling commits.

After:

> Also trigger when she asks to compare two implementations side by side.
> Sibling commits are the mechanism for that.

Two sentences, one instruction each. "Going to be" dropped: it hedged a fact
the skill body states as a rule, so no confidence was lost.

**A Rust safety contract, strict.** (Generic API names, not a real SDK.)

Before:

```rust
/// # Safety
/// The caller must ensure that the pointer remains valid and is not freed
/// while the callback may still be invoked by the engine.
```

After:

```rust
/// # Safety
/// Keep `ptr` valid until `engine_stop` returns.
/// Do not free `ptr` before `engine_stop` returns.
/// The engine can call `callback` at any time before `engine_stop` returns.
```

"May still be invoked" was an open interval with no named end. The rewrite
names the end. If the source had no such end, the rewrite keeps "at any
time" and adds `Kept as-is:` naming the missing bound, because inventing the
bound would add a fact.

**A commit body sentence, STE-flavored.**

Before:

> This has been bitten by three times now, so it seemed like it would
> probably be worth pulling out into its own module.

After:

> This bit three times, so it is worth its own module.

Present perfect and passive gone, "probably" kept out because the commit
made the decision. In a commit body that still weighed the decision, the
hedge stays.
