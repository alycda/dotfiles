---
name: zettelkasten
description: >
  Capture, process, and link notes using the zettelkasten (slip-box) method —
  turning raw reading highlights, fleeting thoughts, and source material into
  atomic, own-words, densely linked permanent notes. Use whenever Alyssa wants
  to take notes on something she's reading, process highlights or annotations,
  "capture this idea", write a literature note or permanent note, link notes
  together, or build/maintain a slip-box or knowledge base. Trigger on mentions
  of zettelkasten, slip-box, smart notes, evergreen notes, atomic notes,
  literature notes, permanent notes, or Luhmann/Ahrens — and also when she
  pastes reading notes or quotes and wants them turned into durable notes, even
  if she doesn't name the method. Not for brag-doc/impact capture (use
  brag-doc) or documenting solved repo problems (docs/solutions/).
---

# Zettelkasten (Smart Notes)

Help turn raw input — reading highlights, quotes, half-formed thoughts — into a
slip-box of atomic, own-words, linked notes. The method here is a synthesis of
Niklas Luhmann's slip-box practice and the workflow popularized by Sönke
Ahrens; see [Sources](#sources) for bibliography. This file is original
expression: it describes the method, it does not reproduce the texts.

## Core model

Three kinds of notes, in a pipeline:

1. **Fleeting notes** — quick captures of a passing thought. Disposable inbox
   items; they exist only to be processed (or discarded) soon. Never let them
   masquerade as knowledge.
2. **Literature notes** — what a source *said*, restated in your own words,
   brief, with a full bibliographic reference attached. One note per source.
   This is the **record, not the work**: the note captures your understanding
   plus a pointer back to the source — never the source's text itself.
3. **Permanent notes** — your own ideas, written as full prose, one idea per
   note (atomic), phrased so they stand alone without the original context.
   These are the only notes that accumulate value; everything else feeds them.

The slip-box's power is in the **links**: a permanent note that connects to
nothing is invisible. Every new permanent note gets filed *behind* a related
note (linked into an existing train of thought), not into a topic folder.

## Workflow

When given raw material (highlights, a quote dump, a "here's what I read"):

1. **Triage** — separate what's genuinely interesting from what was merely
   highlighted. Ask what surprised, contradicted, or connected; drop the rest.
2. **Write the literature note** — restate each keeper in own words,
   compressed. Attach the full reference (author, title, year, locator). If
   understanding can't survive rephrasing, that's a signal it isn't understood
   yet — say so rather than papering over it with the source's wording.
3. **Draft permanent notes** — for each idea worth keeping: one idea, full
   sentences, self-contained. Write it as if for a reader who can't see the
   source. Give it a clear claim-shaped title ("X because Y", not "notes on X").
4. **Connect** — for each new permanent note, find at least one existing note
   it extends, contradicts, or qualifies, and state *why* the link exists
   ("contradicts [note] because…"). A bare link without a reason decays into
   noise.
5. **Surface questions** — note what the new material makes askable. Open
   questions are the slip-box's steering mechanism for what to read next.

## Note templates

**Literature note:**

```markdown
# <Author Year> — <Title>

Ref: <Author>, *<Title>* (<Publisher>, <Year>), <chapter/page locator>.

- <own-words restatement of one point> (p. NN)
- <own-words restatement of another> (p. NN)
```

**Permanent note:**

```markdown
# <Claim-shaped title>

<The idea in full prose, self-contained, own words.>

Links: [[<related-note>]] — <why this connects>.
Source: <Author Year>, via literature note.
```

## Copyright discipline (non-negotiable)

This repo has a source-material policy (alycda/project#1): **attribution does
not grant reproduction rights.** A fully cited copy of source text is still a
copy. The literature note *is* the enforcement mechanism — it exists precisely
so the tracked record is personal synthesis with references attached, never
the work itself.

- Never paste source text, chapters, or long passages into notes. Restate.
- Quote only when the exact wording is the point; keep it short, mark it as a
  quotation, and attribute it inline.
- No license visible means all rights reserved — not "unclear, probably fine".
- Ideas and methods are not copyrightable; their expression is. Summarizing a
  method in your own words with a citation is the entire game here.

## Sources

Bibliographic references only — the works themselves are not reproduced in
this repo:

- Sönke Ahrens, *How to Take Smart Notes* (2nd ed., 2022).
- Niklas Luhmann, "Kommunikation mit Zettelkästen" ("Communicating with Slip
  Boxes"), in *Universität als Milieu* (1992).
