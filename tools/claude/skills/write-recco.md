---
name: write-recco
description: Generate professional recommendations from git history
---

# Write Recommendation

Generate a professional recommendation letter based on git commit history.

## Process

1. Gather commit data:
   ```bash
   git log --author="<name>" --oneline --since="<start-date>"
   git log --author="<name>" --stat --since="<start-date>"
   ```

2. Analyze contribution patterns:
   - What areas of the codebase did they touch?
   - What types of changes (features, fixes, refactors)?
   - How did their contributions evolve over time?

3. Draft a 3-4 paragraph recommendation

4. Review for authenticity and accuracy

## Writing Guidelines

- **Vary sentence structure** - avoid formulaic patterns
- **Action-focused openings** - not "Over the time period I worked with..."
- **Be truthful and accurate** - only mention what's evidenced in commits
- **Protect confidentiality** - NO file paths, line numbers, commit hashes, or internal structure

## Structure

1. **Paragraph 1**: Context and challenge/response
2. **Paragraph 2**: Technical achievements (what they built)
3. **Paragraph 3**: Collaboration approach (how they worked)
4. **Paragraph 4**: Brief endorsement

## Quality Standards

- Each paragraph has ONE clear focus
- Don't mix technical deliverables with soft skills in the same paragraph
- Use specific examples without exposing proprietary details
