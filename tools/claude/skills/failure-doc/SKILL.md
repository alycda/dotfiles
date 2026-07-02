---
  
  name: failure-doc  
  
  description: >  
  
    Extracts, structures, and drafts failure doc entries from raw input — post-mortems, debug  
  
    sessions, abandoned approaches, wrong assumptions, or stream-of-consciousness. Use this skill  
  
    whenever Alyssa says "task failed successfully", "well that didn't work", "here's what went  
  
    wrong", "I broke it on purpose", "log this failure", or "I learned the hard way". Also trigger  
  
    when she pastes a wall of debug notes, describes an approach she abandoned, or says "I want to  
  
    capture this" after something broke. The failure is load-bearing — it was the mechanism of  
  
    learning, not just an obstacle. This is a deliberate learning record, not a postmortem or  
  
    blame log.  
  
---
  
  ` `  
- # Failure Doc Skill
  
  ` `  
  
  Alyssa is a Staff Software Engineer. This skill helps her  
  
  capture failures as evidence of how she learns — by breaking things intentionally, stress-testing  
  
  assumptions, and updating her mental model when reality pushes back.  
  
  ` `  
  
  **Core principle:** The failure was load-bearing. It couldn't have been learned any other way.  
  
  Write for someone who needs to understand what changed in Alyssa's thinking, not just what broke.  
  
  ` `  
  
  **Extraction filter:** Only log it if it changed her mental model. "It just didn't work" goes  
  
  in the trash. "I now understand WHY it doesn't work, and here's what I do differently" goes here.  
  
  ` `  
  
---
  
  ` `  
- ## Step 1: Assess Input Quality
  
  ` `  
  
  Before extracting, read the input and decide:  
  
  ` `  
  
  **High-signal input** (specific action taken, what broke, what the new understanding is):  
  
  → Extract silently. Flag gaps inline.  
  
  ` `  
  
  **Low-signal input** (vague, no mental model shift stated, just "it didn't work"):  
  
  → Ask 2–3 targeted clarifying questions. The key question is always: "What do you know now  
  
  that you didn't know before?" If she can't answer that, it's not a failure doc entry yet.  
  
  ` `  
  
  When asking clarifying questions, be specific — "What assumption turned out to be wrong?"  
  
  is better than "What did you learn?"  
  
  ` `  
  
---
  
  ` `  
- ## Step 2: Extract Into the Four Categories
  
  ` `  
  
  Always use these four fixed categories. If something clearly belongs elsewhere, extract it  
  
  and flag it as **Uncategorized — may not fit**.  
  
  ` `  
- ### 1. Intentional Break
  
  She poked it on purpose to see what would happen. The failure was the experiment.  
- Includes: stress tests, edge case probing, "what happens if I do X wrong" explorations
- Entry format: What she did → what she expected → what actually happened → what that revealed
  
  ` `  
- ### 2. Assumption Collapse
  
  She believed X. Reality said no. She now believes Y.  
- Includes: wrong mental models, misread docs, false analogies from another language/system
- Entry format: What she assumed → what evidence contradicted it → what the correct model is
- Note: This is the highest-value category for learning records. Mark clearly.
  
  ` `  
- ### 3. Process / Coordination Failure
  
  The system broke — human or technical. Not just the code.  
- Includes: toolchain gaps, CI/CD surprises, cross-team dependency failures, missing context
  
  that should have existed  
- Entry format: What the gap was → who or what was affected → what she changed or advocated for
  
  ` `  
- ### 4. Judgment Call That Missed
  
  She made a call. She got feedback. She updated.  
- Includes: architectural decisions that got pushback, proposals that didn't land, tech bets
  
  that didn't pay off  
- Entry format: What she proposed/decided → what the feedback was → what she now weighs
  
  differently → any observable behavior change  
  
  ` `  
  
---
  
  ` `  
- ## Step 3: Format Each Entry
  
  ` `  
  
  Use this structure for every extracted entry:  
  
  ` `  
  
  ```
  
  **[Category]**
  
  What I did / tried: [1–2 sentences. Specific action, specific context.]
  
  What broke / pushed back: [What the failure looked like. Be concrete.]
  
  What I believed before: [The assumption or model that didn't hold.]
  
  What I know now: [The updated mental model. This is the entry — everything else is setup.]
  
  Transferable signal: [Where else does this new understanding apply? Cross-domain if possible.]
  
  Gaps flagged: [What's missing that would strengthen this entry, if anything.]
  
  ```
  
  ` `  
  
  If the entry demonstrates a pattern of intentional learning (not accidental failure recovery),  
  
  mark it with 🔥. These are the entries that signal someone who learns by  
  
  stress-testing, not by waiting for things to break.  
  
  ` `  
  
---
  
  ` `  
- ## Step 4: Tone Guidance
  
  ` `  
  
  Default output tone: **precise and unsentimental** — factual, first-person, no self-flagellation,  
  
  no inflation. The failure is interesting. The learning is the point.  
  
  ` `  
  
  Do NOT write entries that sound like apologies or postmortems. The frame is always:  
  
  *"I broke this on purpose / it broke, and here's what I found out."*  
  
  ` `  
  
  If Alyssa asks for manager-ready framing:  
- Lead with the updated mental model, not the failure mechanics
- Name the transferable signal explicitly
- Replace "I got it wrong" with "I stress-tested X and found the edge" where accurate
  
  ` `  
  
  If Alyssa asks for exec framing:  
- One sentence on what broke, two on what changed in how she approaches the problem space
- Omit debug details entirely
  
  ` `  
  
  Alyssa will ask for narrative draft explicitly. Don't produce a narrative unless asked.  
  
  ` `  
  
---
  
  ` `  
- ## Step 5: Produce the Failure Doc Block
  
  ` `  
  
  Output a clearly labeled block per extracted entry. Group by category. Within each category,  
  
  order by mental model shift magnitude (biggest update first), not chronologically.  
  
  ` `  
  
  At the end, include:  
  
  ` `  
  
  **Summary line:** "[N] entries extracted across [X] categories. [Y] flagged 🔥 as deliberate  
  
  learning signal. Gaps noted in [Z] entries."  
  
  ` `  
  
  **Uncategorized (if any):** Flag clearly. Don't silently discard anything.  
  
  ` `  
  
---
  
  ` `  
- ## Narrative Mode (on request only)
  
  ` `  
  
  When Alyssa asks to draft a narrative section (e.g., "write up my learning velocity section"),  
  
  pull from the extracted entries and:  
  
  ` `  
  
	1. Ask which audience: manager or exec/skip-level  
	2. Write in first person, past tense for resolved failures, present for ongoing  
	3. Lead with the updated mental model, not the failure mechanics  
	4. Make the deliberate learning pattern visible — name it plainly  
	5. Keep it under one page per category unless she asks for more  
  
` `
---
  
` `

- ## Edge Cases
  
  ` `  
  
  **"I don't know what I learned yet":** Don't extract. Ask: "What would you do differently next  
  
  time?" If she still can't answer, flag it as pending and revisit.  
  
  ` `  
  
  **Repeated failure on the same thing:** Extract with a note: "Second encounter — previous entry  
  
  [date if known] did not resolve this." Pattern of same failure = different entry than first time.  
  
  ` `  
  
  **Failure that's also a brag:** Some entries belong in both docs. Extract here with full failure  
  
  framing; flag "also brag-doc eligible" with a one-line summary of the impact angle. Let Alyssa  
  
  decide whether to cross-log.  
  
  ` `  
  
  **Emotional/venting tone in input:** Extract the factual core and the mental model shift.  
  
  Don't reproduce the tone. If the frustration is evidence (she had to fight through something  
  
  that should have been documented), note it as "Required excavation — this should have been  
  
  findable."  
  
  ` `  
  
  **"It still doesn't work":** Log the assumption collapse or process failure anyway. Current  
  
  status is part of the entry. Don't wait for resolution.