# Step 0 — Seed Generation (Interactive)

The only interactive step in the pipeline. Produces `SEED.md` at the project root.

**Skip if** `SEED.md`, `IDEA.md`, or `README.md` already exists at project root. Otherwise, follow the procedure below.

## Procedure

### 0.1 — Confirm Principles Are Loaded

Confirm `references/strongdm-principles.md` is in context. If `--refresh` was passed at the slash command, web-fetch the current versions of:

- https://factory.strongdm.ai/principles
- https://factory.strongdm.ai/techniques
- https://factory.strongdm.ai/products

Overwrite the cached references.

### 0.2 — Probe the User (Four Sections, In Order)

Ask focused questions across the four principle sections. Show each draft section before moving to the next.

#### Section 1: Seed (What + Why)

- What are you building? (one sentence)
- Why now? What's the catalyst?
- What's the current state? What's the target state?
- Is there a secondary use case worth surfacing?
- Is there a one-line version of the project you'd want at the top of the doc?

Draft "What We're Building" + "Why This Exists" sections. Show user. Refine.

#### Section 2: Validation Harness

- What does "real environment" mean for this project? (binaries, services, platforms, customer-shape)
- Give me 5–7 holdout scenarios — concrete, end-to-end, the kind that would be the loop's exit condition if they all passed and stayed passing.
- What's explicitly out of scope?

Draft "Validation Harness" section with a Holdout Scenarios table. Show user. Refine.

#### Section 3: Feedback Loop

- For each output type your validation harness will produce (test results, coverage maps, drift reports, traces, integration test failures), what does it tell us, and how does it change the next iteration?
- What's the loop exit condition?

Draft "Feedback Loop" section with an Output → Fed Back As table. Show user. Refine.

#### Section 4: Apply More Tokens

- What obstacles are you anticipating?
- For each obstacle, what existing artifact (header file, ticket, code, CI trace, customer interview, screen capture) can be converted into model-readable context?

Draft "Apply More Tokens" section with an Obstacle → Token Form table. Show user. Refine.

### 0.3 — Surface Open Questions

After all four sections are drafted, list 3–5 things the agent is uncertain about as a numbered "Open Questions" section. Examples (from `references/exemplar-seed.md`):

- "Does the current API surface cover enough to do X, or do new exports need to land first?"
- "Which runtime is the test target — A or B?"
- "Does Y share Z, or is it a downstream consumer?"

Have the user answer in-line. Fold each resolution back into the SEED, marking the section "Open Questions (Resolved)".

### 0.4 — Add Optional Sections

If the user has them:

- **Related Tickets** — links to issues/PRs the seed connects to
- **Inspiration / Adjacent prior art** — projects already known to be relevant (these will be carried forward into the brief in Step 1)

### 0.5 — Write SEED.md

Use `templates/seed-skeleton.md` as the structure. Write the final document to `SEED.md` at the project root.

## Output

`SEED.md` containing:

- Title
- "What We're Building" + "Why This Exists"
- "Validation Harness" with Holdout Scenarios table
- "Feedback Loop" with Output → Fed Back As table
- "Apply More Tokens" with Obstacle → Token Form table
- (Optional) Related Tickets
- (Optional) Open Questions (Resolved)
- Footer: `*Seed authored: <date>. Loop not yet started. Holdout scenarios: not yet green.*`

## Verification

The seed is ready to proceed to Step 1 when:

- The one-line version is concrete enough that a stranger could repeat it back
- Holdout scenarios are testable, not aspirational ("Initialize a peer from C" ✓; "Be performant" ✗)
- Each Feedback Loop entry actually closes the loop (output → input)
- Apply More Tokens table has at least 3 entries with concrete artifact pointers

## Pitfalls

- **Vague holdouts.** "All tests pass" is not a holdout. A holdout names a specific scenario, platform, and observable behavior.
- **Skipping the Open Questions step.** This is where the seed gets sharpened. Don't just write what you know — write what you don't know and resolve it.
- **Treating SEED.md as one-shot.** It's the entry point for an agentic loop. Expect to revise as Steps 1–4 surface gaps.
- **Forgetting Gene Transfusion.** If the user has prior SEEDs they liked, point at them as the structural model. Don't reinvent.
