---
name: commit-craft
description: Write high-quality git commit messages following established conventions. Use when the user asks to write, review, improve, or critique commit messages, wants to prepare commits for pushing to git from jujutsu, or needs guidance on commit message structure and content. Also use when asked about commit message best practices or the seven rules.
---

# Commit Craft

Write clear, professional commit messages that follow established conventions from Chris Beams' "How to Write a Git Commit Message."

## The Seven Rules

### 1. Separate subject from body with a blank line

If your commit needs explanation beyond the subject line, add a blank line after the subject, then write the body.

**Why:** Many git tools expect this format. `git log --oneline`, `git shortlog`, and email-based workflows all rely on this separation.

```
Add caching layer to user authentication

The previous implementation made a database call on every
request to verify user credentials. This change introduces
a Redis-backed cache with a 5-minute TTL to reduce database
load during high-traffic periods.
```

**When to skip the body:** Simple, self-explanatory changes don't need additional context.

```
Fix typo in README
```

---

### 2. Limit the subject line to 50 characters

Keep subjects concise. Aim for 50 characters; treat 72 as a hard limit.

**Why:** GitHub truncates subjects longer than 72 characters. The 50-character guideline ensures readability in all contexts.

**How to achieve this:**
- Focus on the essential action and target
- Remove unnecessary words ("this commit," "I have")
- Use abbreviations where standard (HTTP, API, DB)

**Too long:**
```
Update the user authentication module to use bcrypt instead of the old MD5 hashing algorithm
```

**Better:**
```
Replace MD5 with bcrypt for password hashing
```

---

### 3. Capitalize the subject line

Start the subject with a capital letter.

**Why:** Basic grammar convention that maintains consistency across the project.

**Wrong:**
```
fix authentication bug in login handler
```

**Right:**
```
Fix authentication bug in login handler
```

---

### 4. Do not end the subject line with a period

Omit trailing punctuation from the subject.

**Why:** Subject lines are titles, not sentences. The period wastes precious character space.

**Wrong:**
```
Add rate limiting to API endpoints.
```

**Right:**
```
Add rate limiting to API endpoints
```

---

### 5. Use the imperative mood in the subject line

Write subjects as commands: "Fix bug" not "Fixed bug" or "Fixes bug."

**Why:** Git itself uses imperative mood (e.g., "Merge branch" not "Merged branch"). This convention reads as "If applied, this commit will [your subject line]."

**Test:** Your subject should complete the sentence: "If applied, this commit will..."

**Wrong:**
```
Fixed the authentication timeout issue
Added support for OAuth2
Updating dependencies to latest versions
```

**Right:**
```
Fix authentication timeout issue
Add support for OAuth2
Update dependencies to latest versions
```

**Common imperative verbs:**
- Add, Remove, Fix, Update, Refactor
- Implement, Extract, Merge, Revert
- Optimize, Document, Deprecate

---

### 6. Wrap the body at 72 characters

Hard-wrap body text at 72 characters.

**Why:** Git never wraps text automatically. The 72-character limit ensures proper display in terminals and UI tools with padding.

**How:** Configure your editor to wrap at 72 characters, or manually add line breaks.

---

### 7. Use the body to explain what and why, not how

The body should explain:
- **What** changed (if not obvious from the diff)
- **Why** the change was necessary
- **What** problem it solves or requirement it fulfills

The body should NOT explain:
- **How** you implemented the change (the diff shows this)

**Example:**

```
Refactor user session management to use Redis

Previous implementation stored sessions in PostgreSQL, causing
performance degradation when session count exceeded 10k. Under
load testing, login response times increased from 200ms to 3s.

Redis provides O(1) lookups and automatic expiration, resolving
the performance issue. Load tests now show consistent 150ms
response times regardless of session count.

This change maintains backward compatibility by preserving the
session schema. The migration script handles existing sessions.
```

**What makes this good:**
- Explains the problem (performance degradation)
- Provides context (specific metrics)
- Justifies the solution (Redis benefits)
- Notes important details (backward compatibility)

---

## Workflow Integration

### For jujutsu users preparing to push to git

When you've completed work in jujutsu and are ready to create permanent git commits:

1. **Review your jujutsu changes:**
   ```bash
   jj log
   jj diff
   ```

2. **Craft your commit message:**
   - Write subject line (imperative, <50 chars)
   - Add body if needed (what and why)
   - Use `jj describe` to set the message:
   ```bash
   jj describe -m "Add user profile caching

   Reduces database queries by 60% during profile page
   loads. Cache TTL set to 10 minutes based on analytics
   showing most users refresh profiles within this window."
   ```

3. **Verify before pushing:**
   ```bash
   jj log  # Check your commit message
   jj bookmark set main  # Point bookmark at commit
   jj git push
   ```

---

## Quick Reference

**Subject line checklist:**
- [ ] Imperative mood ("Add feature" not "Added feature")
- [ ] Capitalized first letter
- [ ] Under 50 characters (72 hard limit)
- [ ] No period at the end
- [ ] Completes: "If applied, this commit will..."

**Body checklist (when needed):**
- [ ] Blank line after subject
- [ ] Wrapped at 72 characters
- [ ] Explains what and why, not how
- [ ] Provides context for the change
- [ ] Notes any important side effects or considerations

---

## Common Patterns

### Bug fixes
```
Fix race condition in payment processing

Under high load, concurrent requests could process the same
payment twice. Added transaction-level locking to ensure
payment atomicity.
```

### New features
```
Add export functionality to reports dashboard

Users can now export reports as CSV or PDF. Export happens
asynchronously with email notification upon completion to
handle large datasets without blocking the UI.
```

### Refactoring
```
Extract authentication logic into middleware

Authentication was duplicated across 15 route handlers.
Consolidating into middleware reduces code by 200 lines
and ensures consistent auth checks across all routes.
```

### Performance improvements
```
Optimize database queries in user listing

Replaced N+1 query pattern with eager loading. Page load
time reduced from 2.5s to 400ms for listings with 100+ users.
```

### Breaking changes
```
Remove deprecated OAuth1 support

OAuth1 has been deprecated since v2.0 (2023-06). All clients
have migrated to OAuth2. Removing legacy code reduces
maintenance burden and attack surface.

BREAKING CHANGE: OAuth1 endpoints no longer available.
```

---

## Additional Guidelines

### Atomic commits

Each commit should represent one logical change. If you're tempted to use "and" in your subject, you probably need multiple commits.

**Too broad:**
```
Add user profiles and fix login bug and update dependencies
```

**Better as separate commits:**
```
Add user profile pages
Fix login redirect after password reset
Update authentication dependencies
```

### References

Link to issue trackers, pull requests, or documentation when relevant:

```
Fix memory leak in background job processor

Jobs weren't properly releasing database connections after
completion, causing connection pool exhaustion after ~6 hours
of operation.

Fixes #1234
See: docs/architecture/background-jobs.md
```

### Conventional Commits (optional extension)

Some projects use conventional commits format:

```
<type>(<scope>): <subject>

<body>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

```
feat(auth): add two-factor authentication support

Users can now enable 2FA using TOTP apps like Google
Authenticator. Recovery codes are generated and encrypted
at rest.
```

Only use this format if the project requires it.

---

## When to Use This Skill

Use this skill when:
- Writing new commit messages
- Reviewing/improving existing commit messages
- Preparing jujutsu changes for git push
- Squashing commits and need consolidated message
- Creating pull request with clean commit history
- Getting feedback on commit message quality

The goal is professional, maintainable commit history that helps future developers (including yourself) understand the evolution of the codebase.
