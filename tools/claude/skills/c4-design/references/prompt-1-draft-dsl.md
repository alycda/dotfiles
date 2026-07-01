# Step 1 — Draft Likec4 DSL

Produces `docs/c4/model.c4` from the Step 0 interview notes + available upstream planning docs.

## Inputs

- `docs/c4/interview.md` (produced by Step 0; required)
- `templates/model.c4.template` (skill-bundled skeleton)
- Whichever upstream planning docs exist: `STRATEGY.md`, `SEED.md`, `RESEARCH-BRIEF.md`, ce-plan output, `docs/research/index/`

## Procedure

1. Read `docs/c4/interview.md`. Extract: external actors, system boundary, containers (with technology + responsibility), components (per container).
2. Read `templates/model.c4.template` as the structural skeleton.
3. Translate the interview into Likec4 DSL:
   - One `actor` per external human (from Section 1)
   - One `external system` per external system (from Section 1, split inbound/outbound)
   - One top-level `system` containing all containers (from Section 2's "Inside" set)
   - Inside the system, one `container` per Section 3 entry (with `technology` and `description` fields)
   - For each container that Section 4 decomposed, add nested `component` definitions
   - One `->` edge per dependency mentioned in the interview (actor → container, container → container, container → external system)
4. Define at least three views in the DSL `views { ... }` block:
   - A System Context view (top-level — system + all actors + all external systems)
   - A Container view (one per system — all containers + their immediate dependencies)
   - A Component view per non-trivially-decomposed container
5. Write `docs/c4/model.c4`.
6. Validate: `npx @likec4/cli validate docs/c4/model.c4` (or check via `references/likec4-syntax-primer.md`). If validation fails, fix syntax and re-validate before proceeding to Step 2.

## DSL Translation Cheatsheet

| Interview concept | Likec4 element |
|---|---|
| External human | `element actor` (spec) + `<name> = actor 'Display Name'` (model) |
| External system (3rd-party service) | `element externalSystem` (spec) + `<name> = externalSystem 'Display Name'` (model) |
| Inside-boundary deployable unit | `element container` (spec) + `<name> = container 'Display Name'` (model, nested under the system) |
| Internal module of a container | `element component` (spec) + `<name> = component 'Display Name'` (model, nested under the container) |
| "X talks to Y" / "X uses Y" | `x -> y 'Verb/Protocol'` (model) |

See `references/likec4-syntax-primer.md` for fuller syntax and `https://likec4.dev/docs/dsl` for the canonical grammar.

## Naming Conventions

- **Element IDs** (the identifier on the left of `=`): lowercase, no spaces, system-internal. E.g., `web`, `api`, `customer`, `stripe`.
- **Display names** (the string after the element keyword): human-readable Title Case. E.g., `'Web Application'`, `'Customer'`.
- **Edge labels**: short verb phrase or protocol. E.g., `'HTTP/JSON'`, `'Reads from'`, `'Authenticates against'`.
- **Component names within a container**: prefix with container ID for clarity. E.g., `api.auth_handler`, `api.sync_engine`.

## Output

`docs/c4/model.c4` — Likec4 DSL, the source of truth for the architectural model. Must parse cleanly with `npx @likec4/cli validate`.

## Verification

A good `model.c4`:

- Validates cleanly (`npx @likec4/cli validate docs/c4/model.c4` exits 0)
- Has at least one `actor`, one `system`, one or more `container`s
- Has at least three `view` definitions (Context, Container, one Component)
- Every container has both `technology '...'` and `description '...'` fields
- Every edge has a non-empty label

## Pitfalls

- **Over-translating prose into DSL.** The DSL is for the model and views, not the rationale. Don't paste the upstream docs' "Why this exists" sections into `description` fields. Keep descriptions to one sentence about *what the element is*, not *why it exists*.
- **Inventing elements the interview didn't surface.** If the interview didn't mention a CDN, don't add one because "most web apps have one." Stay disciplined to what the user authorized.
- **Skipping the Component view.** A Container view alone is C4 Level 2; the real review value of pre-code design comes at Component level (Level 3). At least one container — the riskiest one — gets a Component view.
- **Forgetting external system edges.** Containers that depend on Stripe or an LLM API must have a `->` edge to the external system. Otherwise the Context view shows a disconnected external system, which is usually a bug.
- **DSL fields you're not sure about.** When in doubt, omit. Likec4 ignores unknown fields gracefully sometimes and not others; if the validator complains, check the docs link instead of guessing.
