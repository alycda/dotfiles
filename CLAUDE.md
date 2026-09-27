# CLAUDE.md

Nix dotfiles

## Repository Philosophy

**This repository documents a learning journey with Nix, not just a final configuration.**

The commit history should tell a story of exploration, problem-solving, and
evolution. Favor meaningful, incremental commits over large squashes when they
help illustrate the "why" behind decisions.

## Version Control: Prefer Jujutsu

**Prefer `jj` (Jujutsu) over `git` — but fall back to `git` when `jj` isn't installed.**

`jj` is the default in this repo: reach for it first. It is *not* universally
available, though — ephemeral sandboxes (Claude Code on the web, CI runners,
fresh containers) frequently ship only `git`. When `jj` is missing, use `git`
directly rather than failing or trying to install it, and say which you used.
This is safe: jj is git-backed, so the working tree is a normal git repository
underneath and git operations never corrupt jj state.

### Critical: Always Check Current State First

**BEFORE making any changes, ALWAYS check state first — `jj status` (or
`git status` when `jj` isn't available) — to see:**

- Which commit you're currently on (the working copy `@`)
- What files have been modified
- The parent commit

The user frequently moves between commits during work sessions. Never assume
you're on the commit you expect - always verify with `jj status` first.

### Why Jujutsu?

- Non-linear history management
- Easy to reshape and reorganize commits
- Better for iterative development and learning
- Allows experimentation without fear

## Commit Strategy: Incremental and Meaningful

### Principles

1. **Tell a story**: Commits should illustrate the learning process
2. **Keep changes focused**: One logical change per commit
3. **Document the "why"**: Commit messages should explain reasoning, not just
  what changed
4. **Avoid back-and-forth**: Don't add something in one commit only to move it
  in the next
   - Example: ❌ Add packages to `ditto.nix` → Move packages to module
   - Example: ✅ Create module and import it where needed
