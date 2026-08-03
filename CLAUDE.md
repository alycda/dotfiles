# Claude Code Guidelines for This Repository

This document provides guidance for Claude Code when working with this dotfiles repository. It captures conventions, preferences, and the philosophy behind this configuration.

## Repository Philosophy

**This repository documents a learning journey with Nix, not just a final configuration.**

The commit history should tell a story of exploration, problem-solving, and evolution. Favor meaningful, incremental commits over large squashes when they help illustrate the "why" behind decisions.

## Version Control: Jujutsu First

**Always use `jj` (Jujutsu) commands, not `git` commands.**

### Critical: Always Check Current State First

**BEFORE making any changes, ALWAYS run `jj status` or `jj st` to see:**
- Which commit you're currently on (the working copy `@`)
- What files have been modified
- The parent commit

The user frequently moves between commits during work sessions. Never assume you're on the commit you expect - always verify with `jj status` first.

### Why Jujutsu?

- Non-linear history management
- Easy to reshape and reorganize commits
- Better for iterative development and learning
- Allows experimentation without fear

### Common Workflows

```bash
# CHECK CURRENT STATE FIRST - DO THIS BEFORE ANY WORK
jj status  # or: jj st

# View history
jj log -r 'all()' --limit 20

# Create a new change
jj new

# Edit a specific commit (user does this often)
jj edit <change-id>

# Describe the current change
jj describe -m "Your commit message"

# View a specific commit with diff
jj log -r <change-id> -p --git

# View descendants of a commit
jj log -r '<change-id>::' --limit 10
```

## Commit Strategy: Incremental and Meaningful

### Principles

1. **Tell a story**: Commits should illustrate the learning process
2. **Keep changes focused**: One logical change per commit
3. **Document the "why"**: Commit messages should explain reasoning, not just what changed
4. **Avoid back-and-forth**: Don't add something in one commit only to move it in the next
   - Example: ❌ Add packages to `ditto.nix` → Move packages to module
   - Example: ✅ Create module and import it where needed

### When to Squash vs. Keep Incremental

**Keep incremental when:**
- Changes demonstrate problem-solving (e.g., "Fix rust-analyzer conflict")
- Evolution shows architectural decisions (e.g., "Refactor: Extract to modules")
- Mistakes and fixes teach something valuable
- The journey matters as much as the destination

**Squash when:**
- Commits are just "oops" fixes with no learning value
- The intermediate states don't add context
- You're consolidating experimental changes into a final solution

### Commit Message Format

```
Short imperative summary (50 chars or less)

Longer explanation of the change and why it was made. Focus on:
- What problem does this solve?
- What alternatives were considered?
- What did you learn?
- What tradeoffs were made?

Specific changes:
- Bullet points for key modifications
- File paths and what changed
- Configuration decisions

[Optional: Link to resources or documentation]
```

## Repository Structure

```
dotfiles/
├── darwin/                 # nix-darwin (macOS system config)
│   ├── configuration.nix   # Shared darwin config
│   ├── modules/
│   │   └── homebrew.nix    # Homebrew taps/casks/brews
│   └── profiles/           # Machine-specific configs
│       └── ditto.nix       # Work machine (the only darwinConfiguration)
├── home-manager/           # User-level configuration
│   ├── modules/
│   │   ├── common.nix      # Shared across all profiles (no GUI)
│   │   ├── git.nix
│   │   ├── dev/            # Language tooling modules
│   │   │   ├── nix-lang.nix
│   │   │   └── rust.nix
│   │   ├── ide/            # IDE configurations
│   │   │   ├── vscode.nix
│   │   │   └── vscode-profiles/  # base, jujutsu, rust
│   │   └── tools/          # cheat, helix, gh-dash, agents,
│   │       │               #   agent-skills, claude-code
│   │       └── ...
│   └── profiles/           # User profiles
│       ├── code.nix        # macOS "code" user
│       ├── dev.nix         # Devcontainer / codespaces profile
│       ├── home.nix        # Personal profile
│       └── work.nix        # Work profile
├── lib/
│   └── core-packages.nix   # Packages shared by devShells + home-manager
├── tools/                  # Non-Nix tool content wired in by modules/tools/*
│   ├── agents/             # Agent-instruction overlay (AGENTS.md, #40)
│   ├── cheat/              # Cheatsheets + cheatpath config
│   ├── claude/             # Claude rules
│   └── helix/              # Helix config
├── secrets/                # agenix/ragenix age-encrypted secrets
├── docker/                 # container notes (per-arch CLAUDE.md) + entrypoint
├── Dockerfile              # multi-arch (x86_64 + arm64) dev image
├── justfile                # Task Runner recipes
└── flake.nix               # Flake configuration
```

## Design Patterns

### System vs User Configuration

**Darwin (System-level)** - Use for:
- System services that need root access (like homebrew)
- macOS system defaults (dock, finder, etc.)
- Machine-specific hardware configurations
- Packages that need system-level installation

**Home Manager (User-level)** - Use for:
- User packages and tools
- Dotfiles and configurations
- Development environments
- IDE settings

**Rule of thumb**: If it doesn't need sudo, it probably belongs in home-manager.

### Module Organization

**Common modules** (`home-manager/modules/common.nix`):
- Core CLI tools everyone needs (ripgrep, helix, jj, just, gh)
- Universal configurations
- Imported by ALL profiles
- **No GUI apps here.** `common.nix` is inherited by the headless `dev`
  devcontainer too, so a heavy GUI closure (e.g. VS Code) gets built into the
  x86 image for nothing - and on the disk-constrained 2012 MBP that overflows
  Docker's disk mid-build. GUI editors belong in the desktop profiles
  (`home.nix`, `work.nix`), which import `modules/ide/vscode.nix` directly.
  In a container you use VS Code Remote: the GUI runs on the host and connects
  in, so `code` is never needed inside.

**Specialized modules** (`home-manager/modules/dev/*`):
- Language-specific tooling (rust, nix, etc.)
- Opt-in via profile imports
- Keep focused and composable

**Tool modules** (`home-manager/modules/tools/*`):
- Wire non-Nix tool *content* from the top-level `tools/` directory into the
  home (cheat cheatsheets, helix config, the agent-instruction overlay, etc.)
- Keeps editable plaintext config in `tools/` while the module handles
  installation, symlinks, and activation

**Profile-specific** (`home-manager/profiles/*.nix`):
- Machine or context-specific packages
- Import relevant modules
- Keep minimal - prefer modules

### Shared package lists (`lib/core-packages.nix`)

`lib/core-packages.nix` is a single `pkgs: [ ... ]` list imported by **both**
the flake's devShells and home-manager. This is deliberate: the ephemeral
`nix develop` shell and the persistent home-manager environment install the
same core CLI tools, so `cheat`, `jj`, `just`, `gh`, etc. behave identically
whether you're in a throwaway shell or a switched profile. Add a
universally-needed CLI tool here rather than duplicating it in both places.

### Configuration Conflicts to Avoid

1. **Overlays**: Set `nixpkgs.overlays` ONLY at darwin system level, not in home-manager modules
2. **Rust-analyzer**: Don't install standalone - rustup provides it (conflicts otherwise)
3. **Shell paths**: Use system shells (e.g., `terminal.integrated.defaultProfile.osx = "zsh"`) instead of nix-managed paths

## Migration Workflow

When migrating changes from experimental branches:

1. **Analyze thoroughly**: Understand the full change tree
   ```bash
   jj log -r '<commit>::' --limit 20
   jj log -r '<commit>' -p --git
   ```

2. **Plan the story**: Design commits that avoid wasteful back-and-forth

3. **Create incrementally**:
   ```bash
   # For each logical change:
   jj new
   # Make changes
   jj describe -m "Meaningful commit message"
   ```

4. **Document in CLAUDE.md**: Update this file with new patterns or lessons learned

## Common Tasks

### Adding a New Development Tool

1. Decide: system-level or user-level?
2. If user-level, create or update a module in `home-manager/modules/dev/`
3. Import the module in appropriate profiles
4. Document any conflicts or special considerations
5. Commit with clear reasoning

### Creating a New Machine Profile

1. Add `darwin/profiles/<machine>.nix` for system config
2. Add `home-manager/profiles/<machine>.nix` for user config
3. Update `flake.nix` to include both
4. Document machine-specific decisions
5. Consider what should be extracted to common modules

### Testing Changes

The User will decide if and when to run darwin-rebuild/home-manager switch (and darwin-rebuild requires sudo so you can't execute anyways).

```bash
# See justfile for all available commands
just --list
```

## CI Checks

CI runs on every push and pull request via `.github/workflows/nix.yml`. Two jobs must pass before merging.

### Lint job: `statix` + `deadnix`

**statix** catches Nix anti-patterns. Rules that have caused failures:

- **`empty_pattern`**: Never write `{ ... }:` when a module takes no named arguments — use `_:` instead.
  ```nix
  # ❌ statix flags this as empty_pattern
  { ... }:
  { programs.foo.enable = true; }

  # ✅ correct
  _:
  { programs.foo.enable = true; }
  ```

- **`with` expressions**: Avoid `with pkgs;` — statix flags it. Use explicit `pkgs.` prefixes.

**deadnix** finds unused bindings. Any argument listed in the function signature but never referenced in the body will fail CI:

```nix
# ❌ deadnix: lib is declared but never used
{ pkgs, lib, ... }:
{ environment.systemPackages = [ pkgs.git ]; }

# ✅ correct — only declare what you use
{ pkgs, ... }:
{ environment.systemPackages = [ pkgs.git ]; }
```

### Check job: `nix flake check --all-systems`

The flake must evaluate cleanly across all systems. This catches type errors, missing attributes, and evaluation failures.

### Running linters locally before pushing

```bash
nix profile install nixpkgs#statix && statix check .
nix profile install nixpkgs#deadnix && deadnix --fail .
nix flake check --all-systems
```

## Learning Resources

When adding new Nix patterns or configurations, include links to:
- [Zero to Nix](https://zero-to-nix.com/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)
- [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)

## Meta: Updating This Document

This document should evolve as patterns emerge. When you:
- Discover a new pattern or convention
- Solve a tricky problem
- Learn something worth documenting
- See repeated mistakes

**Add it here** and commit with a message explaining what prompted the addition.

---

*Last updated: 2026-07-28 - Synced Repository Structure with reality (lib/, tools/, secrets/, docker/, modules/tools/) and documented the shared `lib/core-packages.nix` pattern*
