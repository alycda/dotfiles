# Communication Bridge

**Purpose:** Help translate between your neurodivergent communication style and neurotypical professional expectations, while preserving your authentic processing needs.

**Note:** This skill works with your existing Project Memory communication framework. Use this when you need help applying those principles, or when you need format translation beyond message reorganization (like ADRs, RFDs, technical documents).

## What This Skill Does

When invoked, I will:

1. **Understand your input style** - Accept information in whatever format works for you:
   - Bullet points and lists
   - Stream of consciousness
   - Fragmented thoughts
   - Visual/spatial descriptions
   - Mixed formats
   - Questions instead of statements

2. **Help you process** - Before translating, help you:
   - Clarify your thoughts
   - Identify what you actually want to communicate
   - Separate "thinking out loud" from "message to convey"
   - Ask clarifying questions in a non-judgmental way

3. **Translate for audience** - Convert to professional format:
   - Narrative prose when expected (like Nick's feedback)
   - Structured ADRs/RFDs
   - Executive summaries
   - Email responses
   - PR descriptions
   - Documentation

4. **Preserve both versions** - Give you:
   - The polished version for sharing
   - Notes on what changed and why
   - Your original structure if you need to reference it

## Usage

Invoke with: `/communication-bridge` or just `bridge`

Then provide:
- **What you want to communicate** (in whatever format feels natural)
- **Who it's for** (Nick, team, PR, documentation, etc.)
- **Context** (optional: what feedback you've gotten, what you're worried about)

## Examples

### Example 1: Processing Feedback

**You might say:**
```
bridge

Nick said "clear narrative not bullet points" but I think in bullet points?
The bullets ARE clear to me. How do I:
- Keep my processing style (bullets help me think)
- But also deliver what he wants (narrative prose)

Without losing my actual thoughts in the translation?
```

**I would help:**
1. Acknowledge the tension (it's real, not a flaw)
2. Show you how to keep bullets for YOUR processing
3. Help convert to narrative for THEIR consumption
4. Explain what the narrative version gains/loses

### Example 2: Translating Technical Thoughts

**You might dump:**
```
bridge - need to explain why justfile

okay so like. make is bad because:
- 62 files wtf
- cryptic syntax nobody remembers
- $(shell pwd) seriously?

justfile good:
- simple
- kotlin sdk already uses it PROOF
- actually works

but also. the publishing thing. centralized = bad. one bug breaks everything.
need per-sdk scripts but shared utils. node.js for complex stuff.

make sense? how do I write this so Nick doesn't say "needs narrative"
```

**I would:**
1. Extract the core points (you understand the problem clearly!)
2. Structure into: Problem → Why it matters → Solution → Evidence
3. Write narrative version with storytelling elements
4. Show you the mapping between your thoughts and the output

### Example 3: Mixed Input Styles

**You might give me:**
```
bridge

Context: trying to explain the timeline thing
- feature branch done in 1 day (FACT)
- but I said 14 weeks initially (oops)
- actually should be 4-6 weeks realistic
- with parallelization 3-4 weeks

Why did I overestimate? because:
1. assumed sequential
2. over-cautious
3. didn't check evidence first

How do I explain this without looking like I don't know what I'm doing?
Also the 87% claim was misleading comparing wrong things.

Need to: be honest, show evidence, not defensive
```

**I would:**
1. Validate your honesty (this is a STRENGTH)
2. Frame it positively: "revised estimates based on evidence"
3. Show how to present corrections professionally
4. Write version that's transparent without being apologetic

## Key Principles

### For Your Processing
- **No judgment** - Your thinking style is valid
- **Keep your notes** - I'll preserve your original format
- **Ask questions** - I'll clarify, not assume
- **Acknowledge uncertainty** - "I think?" is data, not weakness

### For Translation
- **Preserve meaning** - Never change your actual points
- **Add narrative structure** - Story arc, motivation, evidence
- **Remove thinking artifacts** - "like", "wtf", uncertainties (unless they matter)
- **Match audience expectations** - But tell you what changed
- **Follow your communication framework:**
  - Core request/issue/question FIRST
  - Context second (labeled as skippable for busy readers)
  - Remove apologetic framing
  - Preserve technical precision
  - Invert chronology: problem first, journey second

### For Your Confidence
- **Show the mapping** - You'll see how your thoughts → their format
- **Explain why** - Not just "do this" but "here's why this works"
- **Validate both** - Your style for processing, their style for consumption
- **Build pattern recognition** - Over time you'll internalize the translation

## What This Skill WON'T Do

- Tell you your communication style is wrong
- Force neurotypical patterns on your thinking
- Hide information from you about what changed
- Make you guess at unspoken rules

## Advanced Features

### Request specific output:
```
bridge --format=adr           # Architecture Decision Record
bridge --format=rfd           # Request for Discussion (narrative style)
bridge --format=email         # Email message
bridge --format=pr            # PR description
bridge --format=slack         # Slack message (your default framework)
bridge --format=standup       # Standup update (sync/async bits)
bridge --audience=nick        # For Nick (expects clear narrative)
bridge --audience=team        # For team
bridge --keep-technical       # Preserve all technical depth
```

### Get meta-help:
```
bridge --explain
(Shows what changes between your input and output format)

bridge --teach
(Explains the pattern so you can do it yourself next time)

bridge --validate
(Checks if your draft matches expectations before you send)
```

## Integration with Your Existing Framework

You already have a strong communication framework (in Project Memory):
- Core question FIRST
- Context second
- Remove meta-commentary
- Preserve technical depth

**This skill helps when:**
- You need to apply that framework to raw/messy input
- You're translating TO formats that aren't messages (ADRs, RFDs)
- You got feedback like "needs narrative" and aren't sure how to apply it
- You want to check if your draft matches expectations

**Example workflow:**
1. Dump thoughts in your natural format → this skill
2. I apply your communication framework
3. I translate to the target format (ADR/RFD/email/etc)
4. Show you what changed and why

## Why This Works

**For you:**
- Process in your natural style
- Don't lose clarity in translation
- Build confidence in professional communication
- Learn patterns without masking
- Aligns with your existing framework (not replacing it)

**For your audience:**
- Gets the narrative structure they expect
- Receives complete, well-reasoned arguments
- Doesn't see the processing, sees the insight
- Core question/issue comes FIRST

**For the relationship:**
- Your authentic thoughts preserved
- Their communication needs met
- No one has to change who they are
- Bridge, not assimilation

## Notes

This skill respects that:
- Different brains organize information differently
- Both styles have value
- Translation ≠ suppression
- Professional communication is a learnable pattern, not innate knowledge
- You shouldn't have to guess at unstated expectations

When you use this skill, you're not hiding who you are - you're translating to a different communication protocol while keeping your authentic perspective.

---

**Invocation:** `/communication-bridge` or `/bridge`
**Author:** Claude (for Alyssa)
**Version:** 1.0
