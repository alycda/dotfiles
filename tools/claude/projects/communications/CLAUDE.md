# How to Build Your AI Persona — Step-by-Step

This is a two-tool workflow: **Granola extracts the raw patterns, Claude merges them into a usable persona prompt.** Neither tool does the other's job well, so don't skip a step.

---

## Step 1: Give Granola This Extraction Prompt

Paste the prompt below into Granola. If it offers "search older meetings" after the first run, click it — you want the broadest archive possible.

---

### GRANOLA PROMPT — PERSONA EXTRACTION

You are analyzing meeting transcripts for **[YOUR NAME]**, a seed-stage VC at True Ventures. Your goal is to extract behavioral and linguistic patterns that would make an AI persona sound like me — not just think like me. Focus on how I actually talk, decide, and operate in real conversations.

**Critical filter: Only analyze transcripts where I am the recorder/note creator.** Exclude any transcript recorded by colleagues. If you can't determine who recorded it, flag it as uncertain and weight it lower. I want my voice, not the team's voice filtered through my meetings.

**For each pattern you identify, note the date range it spans.** Flag anything that only appears in the last 60 days as "recent, needs confirmation."

Extract the following:

**1. Voice & Language Patterns**
- Exact phrases I use repeatedly across meetings (verbal tics, go-to expressions, signature framings)
- How I open meetings — by meeting type (new founder pitch, portfolio check-in, internal discussion, customer reference call, 1:1 coaching)
- How I close meetings — do I give specific next steps? Vague follow-ups? Offers of help?
- How I say no or express skepticism in real-time — exact words
- How I express genuine excitement — what does real interest sound like vs. polite interest?
- Register shifts — when am I casual vs. structured? How does my voice change across meeting types?

**2. Question Patterns**
- List every question I ask, grouped by category (pricing, tech stack, GTM, team, competitive dynamics, architecture, defensibility, etc.)
- What do I ask first? What do I always come back to?
- Do I lead with my own view and then ask, or probe first?
- When a founder gives a weak answer, what do I do — rephrase, push harder, move on, sit in silence?
- Do I chain questions or go one at a time?
- What questions do I ask that other people in the meeting don't?

**3. Evaluative Reasoning (Spoken Out Loud)**
- When I give a real-time assessment during or after a pitch, what do I say? Capture exact language.
- How do I talk about defensibility, wedges, and moats in conversation — not in theory but in actual reaction to a specific company?
- How do I talk about deal structure, ownership, and valuation? Do I use specific shorthand?
- What do I say when I'm worried about timing — too early, too late, wrong moment?
- How do I summarize a company to a colleague after a meeting?

**4. Technical Depth Patterns**
- When I probe architecture or product, what specific topics do I drill into?
- Do I name specific technologies, protocols, or companies when probing?
- How deep do I go before pulling back to business questions?

**5. Interpersonal & Meeting Dynamics**
- How do I interact with co-investors or colleagues in the same meeting?
- How do I handle disagreement — with founders? With partners?
- Do I give feedback during the pitch itself? What does that sound like?
- How do I deliver passes or bad news? In real-time or follow-up?
- How do I handle portfolio company check-ins differently from new pitches?

**6. Recurring Themes & Analogies**
- What stories, references, or analogies do I return to across multiple meetings?
- Do I have a "canonical example" I use to explain my thesis or worldview?
- What metaphors or mental models show up more than once?
- What are my interests and passions outside of work that come up naturally?

**7. Deal-Specific Language**
- How do I summarize companies to colleagues after meetings?
- What's my shorthand for pass vs. proceed vs. excited?
- How do I talk about next steps — specific or vague?

**Output format:** For every pattern, include:
- Date range (earliest and most recent appearance)
- Number of meetings where it appears
- Whether the transcript was mine (confirmed) or uncertain
- 2-3 direct quotes with enough context to understand the situation
- Whether this is stable (12+ months), emerging (last 3-6 months), or recent-only (last 60 days)

---

## Step 2: Review the Granola Output

Before pasting into Claude, do a quick scan:
- **Does anything look wrong?** Granola may attribute other people's words to you — flag anything that doesn't sound like you.
- **Is anything missing?** If you know you have verbal tics or go-to phrases Granola didn't catch, note them.
- **Don't worry about structure or polish** — that's Claude's job.

---

## Step 3: Give Claude Both Pieces

Start a new Claude conversation (or use the True Personas project if one exists). Paste this prompt, then paste the Granola output below it:

---

### CLAUDE PROMPT — PERSONA MERGE

I'm building an AI persona prompt for a seed-stage VC at True Ventures. Below is raw behavioral and linguistic pattern data extracted from my meeting transcripts via Granola.

**Your job:** Turn this into a structured persona prompt in markdown (.md) format that could be used as a system prompt for an AI to simulate my voice, thinking, and decision-making across different contexts.

**Structure it with these sections:**
1. **Identity** — who I am, role, firm, stage, check size, ownership target
2. **Investment thesis** — what I believe about the market, where I focus, what excites me and what makes me skeptical
3. **How I evaluate companies** — signature phrases, analytical vocabulary, deal structure language, signal language for pass/proceed/excited
4. **How I run conversations — by meeting type** — separate my voice for: first-call pitches, follow-up/diligence, portfolio check-ins, internal partner discussions, customer reference calls, 1:1 coaching. Each should have its own register description and distinctive behaviors.
5. **Question patterns** — by category, with chaining behavior and how I handle weak answers
6. **How I deliver passes and bad news** — separately for founders, portfolio companies, and partners
7. **How I express skepticism vs. excitement** — with concrete examples
8. **How I evaluate founders** — criteria and what I probe for
9. **Interpersonal dynamics** — how I work with co-investors, handle disagreement, coach founders
10. **Recurring analogies and mental models**
11. **Biases** — toward and against
12. **Voice and register** — tone, register shifts by context, private notes voice (if applicable)
13. **What I won't do** — boundaries

**Rules:**
- Use direct quotes from the Granola output as examples wherever possible — these are my actual words
- Strip all company names, founder names, and colleague names. Use "[Founder]", "[Company]", "[Colleague]" substitutions. Keep the behavioral pattern, lose the specifics.
- If something only appeared in one meeting, flag it as lower confidence
- Write it in second person ("You believe...", "You ask...")
- Keep it concise — this will be used as a system prompt, so every line should earn its place

**After generating the persona, produce two versions:**

**Internal version:** Full detail. Includes negotiation strategy, private notes voice, internal partner dynamics, raw diagnostic language, specific ownership floors or ranges.

**External version:** Strip or genericize the following:
- Negotiation tactics and strategy details
- Private notes voice / internal evaluation language
- Anything that reveals how internal discussions differ from founder-facing conversations
- Specific ownership floors (just use the target, no range or minimum)
- Anything a founder reading this could use as a "decoder ring" for your behavior
- Any language that reveals colleague dynamics or firm politics

---

## Step 4: Review and Correct

Claude will get some things wrong. When it does, tell it:
- "That's not accurate — what I actually do is [X]"
- "I wouldn't say it that way — the real phrasing is [X]"
- "Remove [X] — I don't want that in either version"
- "That's only for internal — strip from external"

This correction step is important. The AI is reconstructing you from transcripts — you're the ground truth.

---

## Step 5: Sensitivity Scrub

Before sharing either version, ask Claude:

> "Flag anything in this document that might be sensitive — references to specific companies, founders, colleagues, deals, internal team dynamics, negotiation strategy, or anything my partners might not want external. Don't remove anything yet, just flag it for my review."

Then decide what stays and what goes, version by version.

---

## Tips

- **More transcripts = better persona.** If Granola only has a few weeks, the persona will be skewed toward whatever you were doing that month. If you can extend the archive, do it.
- **You can iterate.** Run the Granola extraction again in a few months with newer transcripts, paste the new output into the same Claude conversation, and ask it to merge again. The persona gets sharper over time.
- **Different team members will have very different personas.** That's the point — the value is in having multiple authentic perspectives available for deal debates, pitch prep, and founder coaching.
- **The external version is what you'd be comfortable with a founder, LP, or journalist reading.** If you wouldn't say it on stage, it shouldn't be in external.