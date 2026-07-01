# StrongDM Software Factory — Techniques

> Cached from https://factory.strongdm.ai/techniques
> Refresh manually with `--refresh` flag.

Patterns the StrongDM AI team returns to frequently while building with the Software Factory.

## Digital Twin Universe (DTU)

Clone the externally observable behaviors of critical third-party dependencies. Validate at volumes and rates far exceeding production limits, with deterministic, replayable test conditions.

**When to apply:** Your validation harness depends on services with rate limits, costs, or destructive side effects. Build behavioral clones (their term: "twins") of those services.

## Gene Transfusion

Move working patterns between codebases by pointing agents at concrete exemplars. A solution paired with a good reference can be reproduced in new contexts.

**When to apply:** You have an existing solved problem somewhere. Point the agent at the exemplar; let it reproduce the pattern. This skill itself uses Gene Transfusion — `references/exemplar-seed.md` and `references/exemplar-research-brief.md` are the working patterns being transfused.

## The Filesystem

Models can navigate repositories quickly and adjust their own context by reading and writing files. Directories, indexes, and on-disk state become a practical memory substrate.

**When to apply:** Always. This is why the skill itself is structured as files-on-disk (SKILL.md + references/ + templates/) rather than as a single monolithic prompt.

## Shift Work

Separate interactive work from fully specified work. When intent is complete (specs, tests, existing apps), an agent can run end-to-end without back-and-forth.

**When to apply:** Front-load the human's interactive time on intent gathering (e.g., the seed-generation Q&A); back-load the agent's autonomous time on execution (the 4-prompt pipeline). This skill uses Shift Work explicitly: Step 0 is interactive; Steps 1-4 are non-interactive.

## Semport

Semantically-aware automated ports, one time or ongoing. Move code between languages or frameworks while preserving intent.

**When to apply:** Translation tasks. Not directly used by this skill but relevant downstream when the project under research generates code in multiple target languages (e.g., a Rust core with C/Wasm/Flutter SDKs).

## Pyramid Summaries

Reversible summarization at multiple zoom levels. Compress context without losing the ability to expand back to full detail.

**When to apply:** Step 4 (semantic index) is a Pyramid Summary applied to research materials: the index is the compressed top of the pyramid; `_inspiration/` is the full base layer.

## The Validation Constraint

Code is treated like an ML model snapshot: opaque weights whose correctness is inferred exclusively from externally observable behavior. Internal structure is treated as opaque.

**Why it matters for this skill:** When designing holdout scenarios in the SEED, prefer behavioral assertions over internal-state assertions.
