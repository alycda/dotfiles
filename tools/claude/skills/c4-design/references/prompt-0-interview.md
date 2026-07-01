# Step 0 — Interview (Interactive)

The only interactive step. Probes the user on the four things planning docs typically leave implicit. Output is consumed by Step 1.

**Skip if** `docs/c4/model.c4` already exists. In that case, ask: "An existing model is in place. Re-interview from scratch, or jump to iteration (Step 2)?"

## Procedure

### 0.1 — Load Upstream Context

Read whichever of these exist (in priority order):

1. `STRATEGY.md` — tracks of work imply containers; personas imply external actors
2. `SEED.md` — holdout scenarios constrain what containers must support
3. `RESEARCH-BRIEF.md` and `docs/research/index/` — reference architectures from prior art suggest patterns
4. ce-plan output (`docs/sprints/SPRINT-XXXX.md` or wherever) — concrete task structure suggests components
5. `README.md` — fallback if nothing else exists

Carry the loaded context into the interview. Reference specific lines when probing ("Your STRATEGY.md says the third track is 'embedded auth' — does that imply a separate auth container or is it inside the API?").

### 0.2 — Probe the User (Four Sections, In Order)

Ask focused questions. Show a draft answer block before moving to the next section.

#### Section 1: External Actors

Who and what touches the system from outside?

- Which humans interact directly? (Customer? Operator? Developer? Auditor? Different personas often need different views.)
- Which other systems does this system call OUT to? (Payment providers, LLM APIs, identity providers, data warehouses, ...)
- Which other systems call IN to this system? (Webhooks, scheduled poll-ers, partner integrations, ...)

Draft an "External Actors" list. Show user. Refine.

#### Section 2: System Boundary

What's inside vs. outside the design?

- What's the deployable boundary? (One service? Many? A monorepo? A monolith?)
- Is anything technically "ours" but treated as external for this design? (Legacy systems we don't touch; shared platform services managed elsewhere.)
- Are there parts of the system the user explicitly wants to defer beyond this design pass? (Get them on record as "future scope" so they don't pollute the current C4 model.)

Draft a "System Boundary" statement. Show user. Refine.

#### Section 3: Containers

What deployable units does the design call for?

For each container, capture:

- **Name** — short, system-internal name (e.g., `web`, `api`, `worker`)
- **Technology** — best-current-guess (e.g., "React + TypeScript", "Node.js + Express", "PostgreSQL")
- **Responsibility** — one sentence on what it owns
- **External dependencies** — which external actors / systems it talks to

Cross-check against the planning docs: every track in `STRATEGY.md` should map to at least one container or component. Surface any track that doesn't map cleanly and ask the user to resolve.

Draft a "Containers" table. Show user. Refine.

#### Section 4: Component-Level Decomposition

For the 1–3 most non-obvious containers, decompose into components.

Heuristic: if a container's responsibility is a single well-understood role (e.g., "PostgreSQL — application database"), skip it. If it's where the meat of the design lives (e.g., "API — orchestrates sync between mobile clients and the cloud event store"), decompose.

For each chosen container, capture 5–15 components with:

- **Name** — internal module name
- **Responsibility** — one sentence

Don't go below 15 components in one container — that's C4 Level 4 (Code level) territory, and pre-code C4 doesn't benefit from it.

### 0.3 — Surface Open Questions

After all four sections are drafted, list 3–5 things the agent is uncertain about as a numbered "Open Questions" section. Examples:

- "Is the auth flow you described handled by the API container, or does it need its own auth-service container? The plan implies the former; STRATEGY.md's 'Auth as a track' implies the latter."
- "You mentioned a worker for background jobs, but no queue. Is the queue an in-memory implementation detail of the worker, or a separate container (e.g., Redis)?"
- "Mobile clients are listed as external actors. Are they considered out of scope for this C4 model, or do they need their own Container view inside the system boundary?"

Have the user answer in-line. Fold each resolution into the appropriate Section 1–4 block above.

### 0.4 — Write the Interview Notes

Save the consolidated interview output to `docs/c4/interview.md`. This is consumed by Step 1.

The notes file has these sections (mirroring the interview):

1. External Actors
2. System Boundary
3. Containers (with table)
4. Components (one subsection per decomposed container)
5. Open Questions (Resolved)
6. Source docs consulted (paths to the upstream files read in 0.1)

## Output

`docs/c4/interview.md` at the project's c4 dir. Will be consumed by Step 1.

## Verification

The interview is ready to proceed to Step 1 when:

- Every external actor is named and categorized (human / system / inbound / outbound)
- Every container is named with technology and one-sentence responsibility
- At least one container has been decomposed to components
- Every Open Question is resolved
- Every track in `STRATEGY.md` (if it exists) maps to at least one container or component

## Pitfalls

- **Probing too shallowly.** "What containers do you need?" is a bad question. "Looking at your plan's tracks — Auth, Sync, Analytics — which of these is a separate container and which is a module inside an existing container?" is a good question. Anchor every probe in the upstream docs.
- **Skipping Section 4 because containers feel obvious.** Pre-code C4 derives its value from forcing component-level decomposition for the gnarly containers. Don't skip even if it feels like over-spec.
- **Letting external systems sneak into containers.** Stripe is not your container. Anthropic API is not your container. They're external systems on the System Context diagram and dependencies in your container definitions, full stop.
- **Decomposing trivial containers.** A managed Postgres is one node. Don't list "tables" as components inside it — that's a schema diagram, not a C4 view.
