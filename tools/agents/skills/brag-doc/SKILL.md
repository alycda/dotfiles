---
name: brag-doc
description: >
  Extracts, structures, and drafts brag doc entries from raw input — notes, Slack threads, PR
  descriptions, calendar events, or stream-of-consciousness. Use this skill whenever the user
  wants to capture work for a promo packet, performance review, or impact record. Trigger on
  phrases like "log this", "add to my brag doc", "capture this week's work", "help me write up
  what I did", "draft my promo doc", or any time they share raw work notes and want impact
  extracted. Also trigger on "I should document this" or a wall of work notes pasted without a
  clear ask — brag doc extraction is probably wanted even when not named.
---

# Brag Doc Skill

Helps an engineer capture work with the precision and framing that makes a promo case — not a
task log. Written with a senior/staff-level engineer in mind, but the mechanics apply at any
level.

**Core principle:** The reader was never there. Write for someone who has no context on what
happened, why it mattered, or what it cost.

**Extraction filter:** Don't filter for what *feels* impressive. Filter for what had impact on
someone other than the author.

**Capture cadence:** Two working modes, both valid (per Julia Evans's brag-documents post,
which this practice descends from). Frequent: a few minutes every couple of weeks — paste raw
material as it happens; this skill exists to make that mode cheap. Marathon: a periodic bulk
session feeding PRs, tickets, threads, and design docs through extraction all at once.
Frequent capture beats complete capture — messy input is fine, that's what Step 1 is for.

---

## Step 1: Assess Input Quality

Before extracting, read the input and decide:

**High-signal input** (specific names, dates, outcomes, quotes, decisions made):
→ Extract silently. Flag gaps inline without interrupting.

**Low-signal input** (vague, no outcomes stated, no affected parties named):
→ Ask 2–3 targeted clarifying questions before extracting. Don't guess at impact.

When asking clarifying questions, be specific — "Who noticed or depended on this?" is better
than "What was the impact?"

---

## Step 2: Extract Into the Five Categories

Always use these five fixed categories. If something clearly belongs in a sixth category,
extract it anyway and flag it at the end as **Uncategorized — may not fit**.

### 1. Cross-Boundary Impact
Work that touched more than the author's immediate team or domain.
- Decisions or patterns adopted by other teams
- Anything requiring coordination outside their lane
- Entry format: What they did → who outside the team was affected → what changed for them

### 2. Technical Authority
External validation takes precedence; then internal.
- **External:** Conference acceptances, invited talks, workshop invitations, published work
- **Internal:** Architectural decisions owned, ADRs/RFCs authored, moments where their opinion
  changed a direction
- For external: note the venue and any acceptance/invitation date if known
- For deferred or descoped external work: see category 5

### 3. Mentorship & Lift
Specific engineers, what they could do after that they couldn't before.
- Doesn't need to be formal — PR reviews that taught something, being the person someone
  came to repeatedly
- Entry format: Engineer (name or role) → what they couldn't do → what changed → any
  acknowledgment

### 4. Unowned Work Claimed
Things that would have fallen through cracks otherwise.
- Cross-team or infrastructure work nobody assigned
- Test suites, tooling, docs that existed only because the author noticed the gap
- Entry format: What the gap was → who would have been affected → what they built/fixed →
  current status

### 5. Deferred / Descoped Work
Contributions stopped by prioritization or org direction, not capability. Dates matter.
- "Deferred in [month year] when priorities shifted to X" is a materially different statement
  than "not completed" — capture which one is true
- Include it even when it's uncomfortable; future-you won't remember why it stopped
- Entry format: What the work was → what stage it reached → why it stopped → date

---

## Step 3: Format Each Entry

Use this structure for every extracted entry:

```
**[Category]**
What happened: [1–2 sentences. Specific action, specific context.]
Who was affected: [Named person, team, or system — not "the team" or "users"]
Measurable outcome: [Quantified if possible. If not, scope it: "the only cross-platform test
                     suite", "unblocked X for N weeks", "adopted as standard by Y team"]
Acknowledgment: [Verbal counts. Note who said it and when. "None recorded" is also valid.]
Gaps flagged: [What's missing that would strengthen this entry, if anything]
```

If an entry is strong enough to support a narrative (for a promo doc), mark it with ⭐.

---

## Step 4: Tone Guidance

Default output tone: **manager-ready** — precise, factual, first-person where needed, no
inflation. Assumes the reader has technical context but wasn't present.

If exec/skip-level framing is requested:
- Lead with org-level impact before technical detail
- Emphasize decisions, not implementations
- Replace "I built X" with "I established X as the standard for Y" where accurate
- Surface the next-level signal explicitly: moved from "improved my domain" → "set the
  standard the org uses"

Produce a narrative draft only when explicitly asked.

---

## Step 5: Produce the Brag Doc Block

Output a clearly labeled block per extracted entry. Group by category. Within each category,
order by impact magnitude (highest first), not chronologically.

At the end, include:

**Summary line:** "[N] entries extracted across [X] categories. [Y] flagged ⭐ as promo-ready.
Gaps noted in [Z] entries."

**Uncategorized (if any):** Flag clearly. Don't silently discard anything.

---

## Aggregate Views (maintained across extractions, not per-session)

These sections live at the top of the brag doc itself and get updated whenever an
extraction touches them. They are rollups, not entry categories. The Advocates Ledger,
Open Case Gaps, and Perceived Gaps derive from Will Larson's promotion-packet guidance
(staffeng.com); Goals and the Learning Log come from Julia Evans's brag-document template
(jvns.ca). Perceived Gaps is optional.

### Advocates Ledger

Distinct from per-entry Acknowledgment: a standing roster of which teams and leaders are
familiar with and advocate for the author's work.

Per advocate: name and role → what they value about the work (verbatim quote where one
exists, with date and source) → which entries their advocacy attaches to.

- External advocates (conference organizers, community leads, people who sought the
  author out) take precedence over internal, same ordering as Technical Authority
- Quotes are also future reference material — capture them verbatim, never paraphrased

### Goals (this year / next year)

Major goals for the current year, plus a sketch of next year's once the year is closing out.
Sharing goals with whoever reads the doc helps them see how to support the author in reaching
them. Goals also define the target case, and the target case drives which entries get ⭐ and
how outcomes are scoped. Keep goals current; a stale goal misdirects extraction.

### Open Case Gaps (packet as map)

The brag doc is prospective as well as retrospective. Following the "packet as map" idea:
maintain a short list of what the target case — next level, new role, independent work —
still lacks: signals not yet demonstrated, or demonstrated but not yet documented. Review
this list when deciding what work to take on or capture next.

### Learning Log

The one section exempt from the extraction filter: skills and knowledge acquired count here
even when nobody else was affected yet. It's easy to lose track of what's being learned;
periodic reflection usually reveals more than expected, and also surfaces what's *not* being
learned that the author wishes they were. Entry format: what was learned → how (project,
experiment, reading) → where it could surface next (a talk, a tool, a future entry in the
five categories once it lands on someone).

### Perceived Gaps (optional)

Real or perceived skill or behavior gaps that might hold the case back, with a one-sentence
plan for each. Useful for steering development conversations with a manager. Keep it to
gaps the author intends to act on — this is a working list, not a confessional.

---

## Narrative Mode (on request only)

When asked to draft a narrative section (e.g., "write up my technical authority section for
the promo doc"), pull from the extracted entries and:

1. Ask which audience: manager or exec/skip-level
2. Write in first person, past tense for completed work, present for ongoing
3. Lead with the outcome, not the action
4. Make the next-level signal visible where it exists — name it plainly
5. Keep it under one page per category unless asked for more

---

## Edge Cases

**Duplicate input:** If the same work appears multiple times (e.g., mentioned in notes and
a Slack thread), merge into one entry and note the sources.

**Emotional/venting tone in input:** Extract the factual core. Don't reproduce the tone.
If getting the work landed took sustained pushing, note it factually — "shipped after three
rounds of prioritization discussion" — because effort spent unblocking is itself part of the
work.

**"I don't know if this counts":** It counts if someone other than the author was affected.
Extract it and let them decide during review.

**Work in progress:** Extract with current status. Don't wait for completion.
