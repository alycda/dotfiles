---
name: ticket-scope
description: Interrogate a work ticket until someone who did not write it could execute it correctly with no follow-up questions — resolving the baseline/starting context, the observable acceptance criteria, which of several valid approaches is wanted, explicit out-of-scope boundaries, any assumptions that must be validated before work starts, and any prior decisions or history the author holds that the implementer cannot derive. Ask one question at a time. Use this whenever you are writing, refining, or about to assign a ticket, or when the user says "scope this ticket", "is this ready to assign", "pressure-test this ticket", or hands over a ticket that only states a goal. Also use it retroactively — "audit this ticket", "why did this ticket go sideways" — on completed or stalled tickets, where gaps become findings instead of questions. Use it even for tickets that look complete — the field most often left blank (which branch/release/baseline the work targets) is exactly the one that causes rework, and a filled-in DoD checklist can still carry an unresolved either/or inside it.
---

# ticket-scope

Make a ticket executable by a competent engineer who is new to this codebase, using only what the ticket says. This skill interrogates the ticket's author to close the gap between what they *meant* and what they *wrote*, then emits a fully-specified ticket.

It is the ticket-facing counterpart to reviewing a design: instead of interrogating the person about their plan, it interrogates the ticket about what the work actually is.

## The bar

Keep going until this is true:

> Could an engineer skilled in the relevant technology, but new to this codebase and its history, produce the intended result from this ticket alone — without asking anyone?

If not, find the exact unwritten thing and get it written. Unwritten decisions and history are unavailable to whoever picks up the ticket no matter how skilled or fast they are; capturing them once removes rework for everyone and spares the next person from re-excavating it.

The bar is also the **handoff bar**: owners change (rotation, reassignment, departure), and unwritten context leaves with them. A ticket that passes the bar survives its own owner.

## Modes

- **Forward (default)** — a ticket that hasn't been executed yet. Interactive: interrogate the author, one question at a time. When the *assignee* holds the ambient context (e.g., a role-scoped ticket like a release checklist item), forward mode is self-service: get the assignee's own context written down — it protects whoever holds the role next.
- **Retro (audit)** — a completed, canceled, or stalled ticket. No questions. Each unresolved field becomes a **finding**; the output adds a **gap → outcome mapping** (built from comments, state history, and PR reviews — what each blank field actually cost) and the fully-specified rewrite is **constrained to facts the record shows someone knew at authoring time**. That constraint is what keeps the audit no-fault: every line of the rewrite is something a participant later wrote down anyway.

Retro evidence discipline: re-verify current state live before citing it (PR states and ticket states move — "currently open" rots in weeks); keep record-verifiable claims separate from recollection, and mark which is which.

## What "fully specified" means

Resolve each of these. The parenthetical is the failure mode leaving it blank produces.

1. **Baseline / starting context** *(starting-context gap)* — which branch, release line, environment, or precondition the work targets. This is the field most often left blank, and the most expensive one: "everyone knows it's the release branch" is exactly the ambient context that never reaches someone working from what's written. An acceptance check can pass trivially against the wrong baseline, so the baseline has to be stated, not assumed. Preconditions include **cross-team scheduling**: a dependency someone "has to make sure is scheduled" is not a precondition until it's a tracked blocker with an owner who has agreed. And in a sub-ticket, **"see parent" is not a baseline** — the sub-ticket states its own slice: which platform/branch, and the sub-scope's own end state.
2. **Acceptance criteria / observable end state** — what is true and testable when the work is done ("X behaves this way; Y is no longer callable; the 4.14 migration path works; suite Z passes"). Signals to test the result against — not implementation steps. The design is the implementer's to own. Three sub-checks:
   - **Name what the check runs against** — shipped/published artifact vs. working tree, which environment, and any stale-state hazard (a check against the wrong subject passes while the real thing fails).
   - **An either/or inside a criterion is an unresolved field, not a resolved one** ("backport X, *or* add Y" in a DoD checkbox is a decision deferred into review).
   - **Severability / minimum acceptable end state** — which criteria are must-have and which are desired-but-droppable-if-blocked, with the fallback stated. This turns a later descope from a goalpost-move into a pre-agreed fallback executing.
3. **Approach resolution** *(end-state gap)* — if more than one valid path exists, is one required, or is the implementer's documented choice acceptable? **Name the decider**: who adjudicates if review disagrees with a sanctioned choice — and a disagreement is recorded as a scope change, not treated as a miss. Note any known constraint or history that rules options out. This prevents a sanctioned option being implemented and then redirected as if it were a miss.
4. **Out of scope** — explicit boundaries; what this ticket does *not* include.
5. **Assumptions + validity** *(goalpost-moved)* — what the ticket assumes, and for each, whether it is confirmed or must be validated before building ("derived from &lt;source&gt;; customer usage not yet confirmed — validate before building"). This prevents shipping exactly to a spec whose own assumptions were never checked. A blanket disclaimer ("may not be 100% accurate", AI-generated notes) flags that assumptions exist but tags none of them — per-assumption tagging is the review layer machine-drafted tickets need most.
6. **Unwritten context / prior decisions** — anything the author knows that the implementer cannot derive: earlier decisions, history, owner conventions. **Decision-by-reference is unresolved**: a decision recorded as a bare link (Slack thread, doc) fails the bar — put the decision's content inline in one sentence ("removed from v5; new field targets 5.x; old-method removal deferred"), keep the link as provenance, not as content.

Cross-cutting check: **information in the wrong field counts as a gap.** Baseline data filed under Acceptance Criteria (or scope under Notes) means the next reader checks the field, sees content, and moves on — the fields fail differently, so placement matters, not just presence.

## How to ask

- Use the **AskUserQuestion** tool for every question (in a plain chat interface, use its single-choice question equivalent). Never pose questions as plain prose — use the popup so the author can pick fast or type a custom answer.
- **One question at a time.** Wait for the answer before the next. Provide 2–4 concrete, realistic options plus the always-available custom field; skip generic Yes/No unless the question is genuinely binary.
- After each answer, acknowledge the decision in 1–2 sentences, then ask the next.
- **Resolve in dependency order** — settle the target release before asking about environment-specific behavior, settle the approach before asking about approach-specific acceptance criteria, and so on.
- **Explore before asking.** If a question can be answered from the codebase, the ticket's links, git history, or existing docs, find the answer yourself and present it for confirmation ("Looks like this targets `releases/stable/sdk-4.14` — correct?"). Only ask the author for what genuinely lives in their head.
- In retro mode, do not ask — convert each would-be question into a finding, and note the one question that would have caught it at authoring time.

## Flow

1. Read the ticket and everything it links — PRs, related tickets, referenced docs. Identify which of the six fields are missing, vague, or contradictory. Treat an "N/A" in a field that plausibly needs content as missing, not resolved.
2. Self-answer whatever the codebase and history can answer; mark those "proposed — confirm."
3. For each remaining gap, ask one AskUserQuestion, in dependency order. (Retro mode: emit findings instead.)
4. Run **The bar** against the result. If it still fails on any field, keep going.
5. Emit the filled ticket (below) plus a short list of what was surfaced that had not previously been written down. (Retro mode: also emit the gap → outcome mapping.)

## Handoffs

When a ticket changes owner — reassignment, rotation, departure — run the six fields as a **state snapshot** before the context leaves: what's decided, done, remaining, and blocked-on, written into the ticket. Departures are the forcing case: they destroy unwritten context permanently, and the incoming owner otherwise pays the full re-excavation cost (or worse, cannot disambiguate the operative scope from the record at all).

## Output

Emit the ticket in the team template with every field populated:

- **Overview / Why**
- **Baseline / starting context** — branch / release / environment / precondition (incl. cross-team scheduling agreements)
- **Acceptance criteria** — observable, testable, with the subject artifact/environment named; must-have vs. severable marked where relevant
- **Approach** — the chosen option, or "implementer's choice, with these constraints"; decider named for contested cases
- **Out of scope**
- **Assumptions** — each tagged `confirmed` or `validate-before-building`
- **Notes** — prior decisions / history surfaced during questioning, decisions summarized inline with links as provenance

Make it paste-ready. End with a one-line summary of the decisions made.

Retro mode adds:

- **Field-by-field audit table** — status of each field as written, with evidence
- **Gap → outcome mapping** — what each unresolved field actually cost, traced through comments / state history / PR reviews, plus the one authoring-time question that would have caught it
- **Fully-specified rewrite** — constrained to facts the record shows someone knew at the time

## Framing (do not skip)

This is a general engineering-quality tool: it makes any ticket executable by anyone and lowers rework for the whole team. Present it that way — collaborative and no-fault. The point is always the artifact, never the person who will implement it.

Do not moralize or imply the author did something wrong by leaving a field blank. Blanks are normal; the tool exists because the baseline-vs-end-state distinction is genuinely easy to miss, not because anyone was careless. The audit record bears this out: the same gap classes have caught new hires in week two, senior engineers on well-templated tickets, and managers posting a quick measurement — nobody is the failure mode; the written record is.

## Compounding (learned-gaps)

- **On start:** read `learned-gaps.md` (repo-local `.ticket-scope/learned-gaps.md` if in a repo; otherwise the global file next to this skill) and fold its entries into the fields you check — these are gaps that caused rework on past tickets and should now be caught up front.
- **After a miss:** if a ticket that went through this skill later needed a redirect or rework because a field was still under-specified, append the field that was missed and the one question that would have caught it.

Over time the checklist grows to match where *this* team's tickets actually go wrong, rather than staying generic. The skill works fully with no such file present.
