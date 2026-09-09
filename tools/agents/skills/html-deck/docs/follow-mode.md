# Parked: distributed deck sync (follow mode)

**Status:** partly built. `?role=viewer` now implements the client half — a
non-authoritative role, a forward gate on the presenter's high-water mark, and
implicit detach / explicit re-follow (see SKILL.md). What is still parked is
everything that makes it safe at scale: presenter authentication, viewers who
cannot forge position, and genuinely withholding unshown content.

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

Four rules that fall out of it, all now implemented:

1. **Detach is implicit.** The moment an attendee navigates, they've said what
   they want. Making them find an "unfollow" control first is backwards — the
   escape hatch has to be the obvious action, not a preference.
2. **Re-attach is explicit and always visible.** A persistent, non-modal marker:
   *"presenter is on 14 — press F to follow"*. Never snap them forward
   automatically; that's exactly the yank they were escaping.
3. **Never move someone who didn't opt in.** Opening a `?role=viewer` link *is*
   the opt-in, so following starts on — the alternative for a workshop is a room
   full of lost people — and rule 1 makes leaving free. A separate `?follow=0`
   would only be needed if viewer links ever get handed out for something other
   than following along.
4. **Respect `prefers-reduced-motion`.** A follower gets an instant cut rather
   than the slide transition. Auto-moving content is precisely where that
   preference means what it says.

## Open questions

- ~~Do step reveals sync to followers?~~ **Decided: no.** A viewer gets each
  slide fully revealed. A step reveal is the *presenter's* pacing device, and
  someone reading at their own rate should not have content hidden for another
  person's timing. Reversible if it turns out to read badly live.
- What happens to a follower who is mid-cast-replay when the presenter advances?
- Does the presenter want to see how many people have detached? Useful signal
  ("I've lost the room") or unhelpful pressure, depending on the person.
- Is there a "jump to where the presenter is" that doesn't imply re-following —
  a peek?

## Locked slides: what the current gate is, and what it is not

The shipped gate is a **navigation lock, not a secret**. Every slide is in the
file the viewer downloaded; devtools, view-source or ctrl-F reveals the ending.

That is the right amount of mechanism for the actual threat, which is worth
naming precisely: **it is not spoilers, it is exercise solutions.** In a
workshop, a slide carrying the answer to the exercise two slides back defeats
the exercise if someone drifts onto it. That is an *accident* problem. Someone
who opens devtools to find the solution is cheating themselves, and there is no
control worth building against that.

If a stronger guarantee is ever actually needed, the options in ascending cost:

1. **Progressive delivery.** Locked slides are not in the delivered HTML; the
   server releases each as the presenter reaches it. Airtight, and it destroys
   the property the whole format is built on — the attendee's copy is no longer
   self-contained, is useless offline, cannot be archived, and breaks outright
   if the connection drops mid-talk. It also forks the artifact: the presenter
   runs the full file, attendees run a shell. If this is ever built, it should
   be an attendee-only build, never the deck's default shape.
2. **Encrypted payload.** Locked slides ship in the file but AES-encrypted
   (Web Crypto is available); the presenter broadcasts each key on reaching the
   slide. Keeps one file and keeps it archivable *after* the talk, and a viewer
   genuinely cannot read ahead. Costs a build step to encrypt, which the skill
   otherwise does not have, and a viewer who logs the channel keeps every key
   they were sent — so it resists reading *ahead*, not reading *later*. That is
   the right guarantee for this problem, if the navigation lock stops being
   enough.
3. Anything DRM-shaped. No. The content is on their machine.

The honest ranking is that (1) trades the format's defining property for a
threat that is mostly self-inflicted, and (2) is the interesting one — but
neither is worth building until the navigation lock has failed in a real room.

## What this changes in the protocol

The current protocol is symmetric — any window may drive — which is right for
two windows the same person owns and wrong the moment strangers hold the link.
Distributed sync needs:

- ~~A `viewer` role with no authority.~~ **Built.** Viewers receive position and
  never publish it — the first role that is a *permission* rather than a
  presentation concern. Note this is enforced deck-side only: a viewer that
  edits its own JS can still publish. Real enforcement is the transport's job
  (below).
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
  exactly rule "viewers have no authority", and unlike the deck-side check it
  actually holds against an edited client. Probably the shortest path from
  where we are, and the natural next step now that the Supabase transport
  exists.
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
