# StrongDM Software Factory — Techniques

> Cached from <https://factory.strongdm.ai/techniques>

Patterns the StrongDM AI team returns to frequently while building with the Software Factory.

## Digital Twin Universe (DTU)

Clone the externally observable behaviors of critical third-party dependencies. Validate at volumes and rates far exceeding production limits, with deterministic, replayable test conditions.

**When to apply:** Your validation harness depends on services with rate limits, costs, or destructive side effects. Build behavioral clones (their term: "twins") of those services.

## Gene Transfusion

Move working patterns between codebases by pointing agents at concrete exemplars. A solution paired with a good reference can be reproduced in new contexts.

**When to apply:** You have an existing solved problem somewhere. Point the agent at the exemplar; let it reproduce the pattern.

## The Filesystem

Models can navigate repositories quickly and adjust their own context by reading and writing files. Directories, indexes, and on-disk state become a practical memory substrate.

**When to apply:** Always. Structure agent-facing material as files-on-disk rather than as a single monolithic prompt.

## Shift Work

Separate interactive work from fully specified work. When intent is complete (specs, tests, existing apps), an agent can run end-to-end without back-and-forth.

**When to apply:** Front-load the human's interactive time on intent gathering; back-load the agent's autonomous time on execution.

## Semport

Semantically-aware automated ports, one time or ongoing. Move code between languages or frameworks while preserving intent.

**When to apply:** Translation tasks — e.g. a project with a Rust core that generates code for multiple target languages (C/Wasm/Flutter SDKs).

## Pyramid Summaries

Reversible summarization at multiple zoom levels. Compress context without losing the ability to expand back to full detail.

**When to apply:** Indexes over large research or reference material: the index is the compressed top of the pyramid; the full material is the base layer.

## The Validation Constraint

Code is treated like an ML model snapshot: opaque weights whose correctness is inferred exclusively from externally observable behavior. Internal structure is treated as opaque.

**Why it matters:** Prefer behavioral assertions over internal-state assertions when designing holdout scenarios.
