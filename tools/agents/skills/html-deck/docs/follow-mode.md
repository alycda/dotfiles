# Parked: distributed deck sync (follow mode)

**Status:** design note, nothing built. Parked deliberately — the presenter sync
that exists today does two windows on one laptop; this is the version where
*attendees* follow along on their own machines, which is a different problem
wearing the same clothes.

**Why it's worth building:** remote workshops. An attendee who loses the thread
currently has no way back except asking. Unusual as a feature, genuinely useful
for the format.

---

## The thing that makes it hard

Automatic advance is the whole feature and also the whole problem. Some people
want their deck to track the presenter; others find content moving under them
while they're mid-sentence actively hostile. And anyone who goes back to re-read
a slide has, by doing so, opted out of following — but they'll want back in.

So the design cannot be a switch. It has to be three states with cheap,
obvious transitions between them.

## Proposed model

| State | Behaviour |
| --- | --- |
| `following` | Deck mirrors the presenter's position. |
| `detached` | Deck is under local control. Presenter position still arrives, but is only displayed, not applied. |
| `catching up` | One action from `detached` back to `following`. |

Four rules that fall out of it:

1. **Detach is implicit.** The moment an attendee navigates, they've said what
   they want. Making them find an "unfollow" control first is backwards — the
   escape hatch has to be the obvious action, not a preference.
2. **Re-attach is explicit and always visible.** A persistent, non-modal marker:
   *"presenter is on 14 — press F to follow"*. Never snap them forward
   automatically; that's exactly the yank they were escaping.
3. **Never move someone who didn't opt in.** Follow-by-default is probably right
   for a workshop, since the alternative is a room full of lost people, but it
   should be carried in the link (`?follow=1`) rather than assumed, and it must
   be trivially escapable per rule 1.
4. **Respect `prefers-reduced-motion`.** A follower should get an instant cut
   rather than the slide transition. Auto-moving content is precisely where that
   preference means what it says.

## Open questions

- **Do step reveals sync to followers, or only slide position?** Current
  instinct: followers get the whole slide revealed. A step reveal is a
  *presenter's* pacing device — holding a conclusion back until the room has
  read the code. A remote attendee reading at their own rate shouldn't have
  content hidden from them for someone else's timing. That may be wrong, but it
  should be a decision rather than a default.
- What happens to a follower who is mid-cast-replay when the presenter advances?
- Does the presenter want to see how many people have detached? Useful signal
  ("I've lost the room") or unhelpful pressure, depending on the person.
- Is there a "jump to where the presenter is" that doesn't imply re-following —
  a peek?

## What this changes in the protocol

The current protocol is symmetric — any window may drive — which is right for
two windows the same person owns and wrong the moment strangers hold the link.
Distributed sync needs:

- **A `viewer` role with no authority.** Viewers receive position and never
  publish it. Today's roles (`stage`/`notes`) are presentation concerns; this is
  the first one that's a *permission*.
- **Presenter identity.** Otherwise anyone with the link can drive the deck.
  Needs a presenter token or a channel where write is restricted.
- **A wider message type.** Today the payload is `{slide, steps}` and everything
  else is local by construction, which is what keeps notes from leaking across.
  Follow mode wants presenter→viewer *actions* (start the recording, jump to an
  exercise), so the payload becomes a small tagged union — `{type: 'position'}`
  vs `{type: 'action'}` — and the "role state stays local" rule needs restating
  as "role state is never *implicitly* shared", or it quietly stops holding.
  The same question is already open for triggering the cast overlay from the
  notes window (see PR #141).

## What this changes in the transport

This is the case that retroactively justifies the transport abstraction, and
where the current default stops being enough:

- **The local relay is out.** It has no authentication and is bound to
  localhost. Fine for two windows the presenter owns; useless once attendees
  connect from elsewhere.
- **Supabase Realtime** can do it — private channels with RLS on
  `realtime.messages` give the presenter write and viewers read, which is
  exactly rule "viewers have no authority". Probably the shortest path from
  where we are.
- **Convex** becomes genuinely appropriate here rather than overkill. Assessed
  and rejected for two-window sync (PR #141: needs the SDK, which breaks the
  deck's single-file rule, or the HTTP API, which discards the reactivity that
  is the point). Multi-client state with real auth and queries whose results
  depend on data is the shape it's actually built for — and the backend is Rust
  and self-hostable, which fits the rest of this repo. If this thread gets
  pulled, re-evaluate it properly rather than inheriting the earlier "no".

## Adjacent ideas worth not losing

- Reverse channel: attendee "I'm stuck" / raise-hand, surfaced in the
  presenter's notes window. For a workshop with exercises this may be worth more
  than the slide sync itself.
- Deck-linked exercise state — the deck knows which exercise is live, so an
  attendee's environment could follow along.
- Recording the presenter's real timings from a live run, and replaying them as
  the pacing hints in `data-notes`.
