# Learned gaps

Gaps that caused (or would have caused) rework on real tickets. Fold these into
the fields you check up front. Each entry names the field that was missed and the
one question that would have caught it. Append after any later miss.

---

## Baseline: premise stated as timeless fact, never anchored in time/version

**Field:** Baseline / starting context.

A ticket asserts a current-state premise ("X does not work at all") with no
date or version anchor. The premise is true at authoring and quietly goes
false as the product moves. A later reader — human or crawling bot — reads the
unanchored claim as still-current and either acts on stale truth or re-derives
whether it still holds.

**Catch it up front:** anchor every current-state claim — "as of <version /
date>, X does not …". If the claim is the whole reason for the ticket, its
version anchor is load-bearing, not decoration.

**Seen on:** a ticket asserting "X will not work at all on <platform>" with no
version anchor. By a later release the capability had shipped and the proposed
fix was already delivered, but nothing in the ticket marked the premise as
time-bound — so it read as still-current long after it went false.

---

## Closing gap: a canceled/superseded ticket with no rationale is indistinguishable from a rejected idea

**Field:** Unwritten context / prior decisions — at *close* time, not authoring time.

A ticket is Canceled with no comment. To every future reader the "Canceled"
state reads as "idea rejected," even when the outcome actually shipped
elsewhere. Cost: someone resurrects it, cites its (now-false) premise as current
truth, or burns time reconstructing what happened. This is a *closing-time*
gap — no authoring-time question prevents it.

**Catch it at close:** when canceling, record one line — *superseded by what,
or rejected why*. "Canceled — the capability shipped in <PR/ticket>, this
approach no longer needed" costs a sentence and saves the re-excavation.

**Seen on:** a ticket canceled with no rationale for the capability it asked
for had in fact been delivered elsewhere. The author had since departed, so the
context was unrecoverable from anyone.

---

## Legibility: a ticket must state why it is *not* redundant with adjacent work

**Field:** Overview / Why + Out of scope.

When several efforts occupy nearby territory (e.g. overlapping test suites or
frameworks that each cover an adjacent layer), a ticket that only describes
*what it is* — never *how it differs from the thing next to it* — gets misread
by stakeholders who hold the adjacent context. The misread has real cost: a
mislabel, a "this is just an idea" dismissal, or an earlier version of the same
proposal ignored because no one could place it.

**Catch it up front:** if adjacent/overlapping work exists, state the boundary
explicitly in the Overview ("not redundant with <X> because <X> tests <layer>;
this tests <other layer>; they stack") and list the neighbors under Out of
scope with the distinguishing reason.

**Seen on:** a ticket repositioned to make its niche legible against an
adjacent framework, after the missing distinction led to a mislabel and an
earlier proposal being ignored.
