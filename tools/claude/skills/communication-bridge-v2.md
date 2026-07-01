---
name: communication-bridge
description: Translate between Alyssa's natural communication style and professional formats expected by different audiences. Use this skill when Alyssa invokes `/bridge` or `/communication-bridge`, or when she needs to convert raw/messy input (bullet dumps, stream of consciousness, fragmented thoughts) into polished professional output; Slack messages, emails, PR descriptions, ADRs, RFDs, exec briefs, standup updates, or conference abstracts. Also invoke when she needs help analyzing workplace communications to distinguish what was "said explicitly" vs "implied." Use this even when the request seems simple — bridge helps preserve authentic thinking while translating to audience-expected formats.
---

# Communication Bridge

**Purpose:** Translate between natural processing style and professional format expectations, without losing the insight or requiring masking.

**Invocation:** `/communication-bridge`, `/bridge`, or just `bridge`

---

## What This Skill Does

Accepts input in any format that works — bullet dumps, stream of consciousness, fragmented thoughts, questions instead of statements, mixed formats. Then:

1. **Helps clarify** — Before translating, identifies what you're actually trying to communicate. Separates "thinking out loud" from "message to convey."
2. **Translates for audience** — Converts to the expected professional format.
3. **Preserves both versions** — Returns the polished output plus notes on what changed and why.
4. **Applies your communication framework** — Core request first, context second, no apologetic framing, technical precision maintained.

---

## Core Translation Principles

- **Invert chronology:** Problem first, journey second
- **Distinguish signal from noise:** Context is valuable; label it as skippable for busy readers
- **Remove apologetic framing:** Let structure handle communication style concerns
- **Maintain precision:** Reorganize technical details; never simplify them
- **Async-optimize:** Busy readers should grasp the ask in the first 1–2 sentences
- **Preserve both versions:** Your format for processing; their format for consumption

---

## Formats

### Standard message (default)
Slack message, email, async update — applies the core framework above.

### `--format=standup`
Ditto standup structure:
- **Synchronous Bits** (read aloud): Coordination needs, blockers, anything requiring same-day response
- **Asynchronous Bits** (management review): Project updates with risk assessments, progress notes, horizon items

### `--format=adr`
Architecture Decision Record using [MADR 4.0.0](https://github.com/adr/madr/tree/4.0.0/template). Structure:

```markdown
---
status: {proposed | accepted | deprecated | superseded by ADR-XXXX}
date: {YYYY-MM-DD}
decision-makers: {list of people involved}
consulted: {list of people consulted}
informed: {list of people informed}
---

# {Short noun phrase describing the decision}

## Context and Problem Statement

{Describe the context and problem in 2–3 sentences. Why does this decision need to be made?}

## Decision Drivers

* {driver 1}
* {driver 2}

## Considered Options

* {Option 1}
* {Option 2}

## Decision Outcome

Chosen option: "{Option N}", because {justification}.

### Consequences

* Good: {positive consequence}
* Bad: {negative consequence / accepted tradeoff}

## Pros and Cons of the Options

### {Option 1}

* Good, because {argument}
* Bad, because {argument}

### {Option 2}

* Good, because {argument}
* Bad, because {argument}
```

### `--format=rfd`
Request for Discussion (narrative style). Structure: Problem → Proposed approach → Open questions → What you need from readers.

### `--format=pr`
PR description. Structure: What changed → Why → How to verify → Scope notes (what's explicitly NOT included).

### `--format=exec-brief`
Executive summary for senior/exec audience. Structure: Recommendation or ask first → Supporting rationale (concise) → Risk/tradeoff acknowledgment → What you need from them. Optimize for someone who reads the first paragraph and decides whether to read further.

### `--format=conf-abstract`
Conference talk abstract (Rust meetup / CFP submission). Structure: Hook → Problem statement → What this talk covers → Audience takeaway. Connects to your talk arc: FFI fundamentals → production FFI at scale.

### `--format=email`
Email with subject line. Applies async-optimize principles; assumes recipient is busy.

### `--audience=nick`
Nick expects clear narrative prose, not bullet lists. Translate to story arc: motivation → context → argument → ask. Show the mapping between your bullets and the output.

### `--audience=team`
Team-level communication. Can be more technical. Prioritize shared context and coordination needs.

### `--audience=exec`
Executive audience. Lead with the ask or recommendation. One paragraph max before the key point. Trim rationale to what changes the decision.

### `--keep-technical`
Preserve all technical depth. Reorganize structure but don't simplify content.

---

## Analysis Mode

### `--mode=analyze`
Use when reviewing workplace communications you've received — not composing.

Specifically helps with:
- **Explicit vs. implied:** What was literally said vs. what was probably meant
- **Tone calibration:** What emotional register is this coming from
- **What they actually want:** Core ask vs. context vs. subtext
- **What you might be missing:** Unstated expectations, norms in play

Provide the message or summary, and flag what you're uncertain about.

---

## Meta-Help

### `--explain`
Shows what changed between your input and the output, and why each change was made.

### `--teach`
Explains the underlying pattern so you can apply it yourself next time.

### `--validate`
Checks a draft you've already written against:
- Your communication framework
- The target audience's expectations
- The specified format requirements

Returns: what's working, what to tighten, what might land differently than intended.

---

## Usage Pattern

Invoke, then provide:
- **What you want to communicate** (any format)
- **Who it's for** (Nick, team, PR, exec, conference, etc.)
- **Context** (optional: what feedback you've gotten, what you're worried about)

---

## Examples

### Exec brief from bullet dump
```
bridge --format=exec-brief --audience=exec

we advertise flutter 3.19 support but CI only tests 3.32
nobody has actually validated 3.19 in months
if a customer hits a 3.19 bug we won't catch it before they do
this is customer risk not just a CI gap
either fix validation or stop advertising 3.19 - need someone to make a call
```

**Output:**
> **Ask:** Decide whether we fix Flutter 3.19 validation or revise our advertised support floor before it becomes a customer-facing bug.
>
> We currently advertise 3.19 support but CI only tests against 3.32. There's no automated validation on the minimum version we're shipping against. A regression would reach customers before we'd catch it internally. Options: add a `sdk-flutter-linux-native-min-version` CI job (low overhead, already scoped), or formally drop 3.19 from our support statement. Either is fine — the current gap is the problem.

---

### Standup from scattered notes
```
bridge --format=standup

<INTERNAL-TICKET-B> still blocked on <INTERNAL-TICKET-D>, circular dep still in play
finished deprecation annotations, waiting on sergiu review
tomorrow: trying to scope the lockfile decision - haven't gotten alignment yet
should the lockfile thing be a blocker or just a risk?
```

**Output:**
> **Sync Bits**
> <INTERNAL-TICKET-B> remains blocked pending <INTERNAL-TICKET-D> merge — circular dependency is unresolved. If you're working across that boundary, check in before making changes that depend on the new FFI contract.
>
> Need alignment call on pubspec.lock tracking strategy. Happy to do async but want to make sure Cameron and Maddie are in the loop before I change the gitignore.
>
> **Async Bits**
> Deprecation annotations PR (SPO-204/SPO-207) complete, in Sergiu review. Scope is annotations-only per ticket — no functional DittoConfig backport.
>
> Scoping lockfile decision tomorrow. Evidence is solid (Dart official guidance, major package precedents, Cameron's prior acknowledgment), but Flutter/CocoaPods tooling concerns may apply. Will surface if it becomes a blocker.

---

### ADR from investigation findings
```
bridge --format=adr

decision: stop tracking pubspec.lock for the flutter SDK (library, not application)
dart docs say libraries shouldn't commit lockfiles - constraints consumers
cameron and maddie discussed this in april 2025, acknowledged it theoretically but said tooling was "wobbly" - cocoapods
riverpod, drift, dio - none of them track lockfiles
pub.dev strips the lockfile from published packages anyway
we're getting lockfile churn every flutter version switch and it's noise in code review
risk: flutter/cocoapods interactions may be flaky without pinned deps
```

**Output:**
```markdown
---
status: proposed
date: 2025-01-14
decision-makers: Alyssa, Cameron McLoughlin, Maddie Mortensen
consulted: Cameron McLoughlin, Maddie Mortensen
informed: SDK team
---

# Do Not Track pubspec.lock for the Flutter SDK Library Package

## Context and Problem Statement

The Flutter SDK is a Dart library package published to pub.dev. We currently commit `pubspec.lock`, which generates noise on every Flutter version switch and creates merge churn unrelated to code changes. The question is whether the lockfile should be tracked at all given our package type.

## Decision Drivers

* Dart official guidance recommends against lockfiles for library packages
* pub.dev strips lockfiles from published packages — consumers never see it
* Every Flutter version switch rewrites the lockfile, creating review noise
* Cameron McLoughlin acknowledged in April 2025: "Theoretically, they should probably be ignored"

## Considered Options

* Stop tracking `pubspec.lock` (gitignore it)
* Continue tracking `pubspec.lock`

## Decision Outcome

Chosen option: "Stop tracking `pubspec.lock`", because our package type is a library, not an application. The lockfile provides no value to consumers and active harm to contributors.

### Consequences

* Good: Eliminates lockfile churn from version switches; aligns with Dart best practices
* Bad: Flutter/CocoaPods tooling interactions may surface instability that was previously masked by pinned deps — monitor after change

## Pros and Cons of the Options

### Stop tracking pubspec.lock

* Good, because official Dart guidance explicitly recommends this for libraries
* Good, because riverpod, drift, dio, and Flutter's own SDK packages all follow this pattern
* Good, because pub.dev doesn't publish lockfiles — committed lockfile has zero consumer value
* Bad, because Flutter/CocoaPods interactions were flagged as "wobbly" by Cameron in April 2025; removing pin could expose latent issues

### Continue tracking pubspec.lock

* Good, because current behavior is stable (team has worked around the churn)
* Bad, because generates review noise on every Flutter version switch
* Bad, because conflicts with official Dart guidance and ecosystem norms
```

---

### Analyzing a message received
```
bridge --mode=analyze

Sergiu said the PR "reads like a migration bridge but you said annotations-only"
I thought my PR description was accurate?
what did he actually mean and what does he want me to do
```

**Output:**
> **What was literally said:** The PR description describes implementing `DittoConfig` as a migration bridge — new files, new methods, functional changes. Sergiu is saying the description matches what was built, not what was requested.
>
> **What he probably means:** The scope of the PR is wrong, not just the description. The ask was annotations-only (`@Deprecated` markers). The implementation added `ditto_config.dart`, `openWithConfig`, and new exports — none of which were in scope.
>
> **What he wants:** Revert to annotations-only. The PR description wasn't just generated wrong — it accurately described code that went beyond the ticket.
>
> **What might be getting lost:** If you thought the migration bridge was the right thing to build, that's a separate conversation. But the current PR needs to be scoped back first. The description and the diff need to match the ticket.

---

### Conference abstract
```
bridge --format=conf-abstract

talk idea: production FFI at scale - what ditto's sync engine taught us
jan talk at rust LA covered fundamentals: ownership at ffi boundary, async safety, ref vs box
this one goes further: what happens when you do this at scale in a real product
- the circular dependency deadlock pattern (<INTERNAL-TICKET-D> situation)
- breaking changes in rust that deadlock SDK validation
- kitchen sink C test suite as the solution
- why native rust tests can't catch FFI bugs (drop vs close, lifetime contract never valid async)
audience: rust engineers shipping FFI in production
goal: build body of work in rust community, ditto talk at major conference
```

**Output:**
> **Title:** Production FFI at Scale: Hard-Won Lessons from Ditto's Sync Engine
>
> **Abstract:**
> FFI is easy to get working. It's hard to get right when your Rust core ships to a dozen SDK targets, breaking changes are unavoidable, and a single callback signature error means corrupted CBOR bytes in production.
>
> This talk picks up where FFI fundamentals leave off. We'll look at real problems from Ditto's sync engine: why a lifetime-managed callback that passed synchronous tests silently corrupted data under async load; how breaking changes in Rust core can deadlock SDK validation in a circular dependency that blocks both sides from merging; and why native Rust tests can't catch the class of FFI bug that will absolutely bite you in production.
>
> We'll walk through the validation architecture we built to catch these earlier — a C-level test suite that sits between Rust native tests and full SDK integration — and what we learned about ownership contracts, lifetime semantics at FFI boundaries, and what "safe" actually means when your callers are Dart, JS, and Swift.
>
> Audience: Rust engineers shipping FFI to real consumers. You will leave with a concrete pattern for FFI contract testing and a checklist for async ownership correctness.

---

## What This Skill Won't Do

- Tell you your communication style is wrong
- Force neurotypical patterns on your thinking
- Hide what changed or why
- Make you guess at unstated expectations
- Simplify technical content in the name of brevity

---

## Integration with Your Communication Framework

You already have a strong framework (in Project Memory): core question first, context second, no meta-commentary, preserve technical depth.

**Use this skill when:**
- You need to apply that framework to raw/messy input
- You're translating to a format that isn't a standard message (ADRs, execs briefs, conf abstracts)
- You got feedback like "needs narrative" and aren't sure how to apply it
- You want to validate a draft before sending
- You received a message and need help parsing what was actually said vs. implied

---

*Bridge, not assimilation. Translation ≠ suppression.*