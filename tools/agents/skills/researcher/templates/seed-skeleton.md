# SEED: <Project Name>

> Entry point for agentic development. Follow the loop: Validation → Feedback → repeat until holdout scenarios pass and stay passing.

---

## What We're Building

<2–3 paragraph description of the project>

**One-line version:** <single sentence>

---

## Why This Exists

**Current state:** <what's broken / blocking / suboptimal today>

**Target state:** <what changes after this project ships>

**Secondary use case:** <optional — adjacent value>

---

## Validation Harness

> Must be end-to-end, as close to real as possible: real binary, real protocol, real platform matrix.

### Holdout Scenarios (loop runs until these pass and stay passing)

| # | Scenario | Platform |
|---|----------|----------|
| 1 | <concrete, end-to-end behavior> | <where it runs> |
| 2 | ... | ... |

### What "Real Environment" Means Here

- <bullet list>

### What Is NOT "Real" (explicitly out of scope)

- <bullet list>

---

## Feedback Loop

Each run of the validation harness produces a feedback signal fed back into the inputs:

| Output | Fed Back As |
|--------|-------------|
| <output type> | <how it changes next iteration> |

**Loop exit condition:** <when do we stop>

---

## Apply More Tokens

> For every obstacle, ask: how can we convert this problem into a representation the model can understand?

| Obstacle | Token Form |
|----------|------------|
| <obstacle> | <existing artifact / data source> |

---

## Related Tickets

- `<TICKET-ID>` — <description>

---

## Open Questions (Resolved)

1. **<question>?**

   **<resolution>.** <reasoning>

---

*Seed authored: <YYYY-MM-DD>. Loop not yet started. Holdout scenarios: not yet green.*
