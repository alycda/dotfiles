---
name: commit-craft
description: Craft git commits following Chris Beams' seven rules
---

# Commit Craft

Write git commit messages following Chris Beams' seven rules.

## The Seven Rules

1. **Separate subject from body with a blank line**
2. **Limit the subject line to 50 characters**
3. **Capitalize the subject line**
4. **Do not end the subject line with a period**
5. **Use the imperative mood in the subject line**
6. **Wrap the body at 72 characters**
7. **Use the body to explain what and why vs. how**

## Imperative Mood

Write as if giving a command:
- "Fix bug" not "Fixed bug"
- "Add feature" not "Added feature"
- "Update docs" not "Updated docs"

A good subject line completes: "If applied, this commit will _____"

## Body Guidelines

- Explain **what** changed and **why**, not implementation details
- Use bullet points for multiple changes
- Reference issues/PRs if relevant
- Keep it concise but complete

## Examples

### Good
```
Add user authentication via OAuth2

- Integrate Google and GitHub providers
- Store tokens securely in encrypted session
- Add logout functionality

Closes #123
```

### Bad
```
fixed the auth bug that was causing issues with the login flow when users tried to authenticate using third party providers
```

## Reference

https://cbea.ms/git-commit/
