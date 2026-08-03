# StrongDM Software Factory — Principles

> Cached from <https://factory.strongdm.ai/principles>

The recipe: **Seed → Validation harness → Feedback loop. Tokens are the fuel.**

## Entry Point: Seed

Every piece of software needs an initial seed. Historically this was called a PRD or a spec. Today it can equally be:

- a few sentences
- a screenshot
- an existing codebase

## The Loop

### 1. Validation

The validation harness must be **end-to-end, as close to the real environment as possible**: real customers, real integrations, real economics.

### 2. Feedback

A sample of the output, **fed back into the inputs**. This closed loop allows the system to self-correct and compound correctness.

The loop runs until the holdout scenarios pass — and stay passing.

## The Fuel: Apply More Tokens

The theory of Validation and Feedback is easy to understand. The practice requires creative, frontier engineering.

**For every obstacle, ask: how can we convert this problem into a representation the model can understand?**

Token forms include:

- traces
- screen capture
- conversation transcripts
- incident replays
- adversarial use
- agentic simulation
- just-in-time surveys
- customer interviews
- price elasticity testing

## The Mantras

In kōan form:
- *Why am I doing this?* (implied: the model should be doing this instead)

In rule form:
- Code **must not be** written by humans
- Code **must not be** reviewed by humans

In practical form:
- If you haven't spent at least **$1,000 on tokens today** per human engineer, your software factory has room for improvement

## How This Maps to a SEED.md

A well-formed SEED has four sections that mirror the principles:

| Principle | SEED.md section | Contents |
|---|---|---|
| Seed (spec) | "What We're Building" + "Why This Exists" | One-line version, current state vs. target state, secondary use cases |
| Validation harness | "Validation Harness" | Holdout scenarios table, what "real environment" means, what's out of scope |
| Feedback loop | "Feedback Loop" | Output → fed back as input table, loop exit condition |
| Apply More Tokens | "Apply More Tokens" | Obstacle → token form table |

Optional but useful additions:
- **Related Tickets** — links to issues/PRs the seed connects to
- **Open Questions (Resolved)** — questions the agent had during seed creation, with resolutions folded back in
