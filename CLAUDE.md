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
├── docker/                 # 2012 MBP container notes + entrypoint
├── Dockerfile              # x86_64 dev image
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

**Fonts are system-level.** Install Nerd Fonts via darwin `fonts.packages`, not
per-user home-manager — a font is a shared resource every terminal app (Warp,
etc.) must see. TUIs that render glyph icons (gh-dash) show mojibake if the font
is only in a user profile. (Lesson from PR #20.)

**Dock-pinned apps must be Homebrew casks.** `darwin/modules/homebrew.nix` sets
`onActivation.cleanup = "zap"`, which *removes* anything not in the `casks` list —
so the casks list is the authoritative app inventory. Any app referenced in
`dock.persistent-apps` that isn't a managed cask renders as a "?" icon, because
the dock config is applied before the (missing) app exists. Add the cask when you
pin the app. (Lesson from PR #13.)

**Pinning nix-darwin is not set-and-forget.** A pinned rev's `brew bundle`
invocation can be rejected by a newer Homebrew CLI (e.g. `--zap` now needing
`--force-cleanup`). Because `homebrew.onActivation.autoUpdate = true`, the host
updates brew and then self-breaks on its next rebuild against a stale pin. When
this bites, repin to a rev whose brew call matches current brew — and remember the
fixing rev may run `brew` as the configured user (`sudo --user=`), which requires
that user own the Homebrew prefix. (Lesson from PR #35.)

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
- **Also keep path-assuming out-of-store symlink modules out of `common.nix`.**
  The agent-skills module mounts skills via `mkOutOfStoreSymlink` pointing at the
  `~/dotfiles` checkout so edits land without a rebuild — but that path doesn't
  exist in the `dev` devcontainer, so the links would dangle silently. Same
  reason as the GUI rule: `common.nix` is inherited by the headless container.
  Import such modules in desktop profiles only. (PR #46.)

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
- **But don't over-modularize.** "Prefer modules" is not "build a bespoke
  per-tool module for every addition." A single trivial package belongs in a
  profile's `packages` (or `lib/core-packages.nix` if it's a universal
  lightweight CLI — see below), not a hand-written module justified by a
  speculative "the future swap will be one file." PR #44 built a full
  `modules/tools/taskbook.nix`; it was rightly closed in favor of a plain package
  add. Reach for the simplest placement first; promote to a module only when
  there's real config/composition to own. (Note: taskbook first landed in
  `lib/core-packages.nix`, but that list is inherited by the headless container —
  so it now lives in the desktop profiles instead. Simplest ≠ core-packages when
  the tool carries a heavy runtime closure.)

**devShell ↔ home-manager boundary:** when both a flake devShell and
home-manager can provide the same tool, let the devShell ship only the *minimal*
build it needs (e.g. helix as cheat's `$EDITOR`) and let home-manager own the
*full* config. Don't ship two divergent configs — remove the duplicate from the
default devShell, which already inherits it via `inputsFrom`. (Lesson from PR #7.)

### Shared package lists (`lib/core-packages.nix`)

`lib/core-packages.nix` is a single `pkgs: [ ... ]` list imported by **both**
the flake's devShells and home-manager. This is deliberate: the ephemeral
`nix develop` shell and the persistent home-manager environment install the
same core CLI tools, so `cheat`, `jj`, `just`, `gh`, etc. behave identically
whether you're in a throwaway shell or a switched profile. Add a
universally-needed CLI tool here rather than duplicating it in both places.

**Keep it lean.** Because `common.nix` imports this list into *every* profile —
including the headless `dev`/x86 devcontainer — and the devShells pull it too, a
heavy closure here bloats the disk-constrained 2012 MBP image for no container
benefit (same reasoning as the "no GUI in common.nix" rule). Only universal,
lightweight CLIs belong here; a heavy personal tool goes in the desktop profiles'
`packages` (e.g. `taskbook`, whose Node closure lives in `home.nix`/`work.nix`).

### Configuration Conflicts to Avoid

1. **Overlays**: Set `nixpkgs.overlays` ONLY at darwin system level, not in home-manager modules
2. **Rust-analyzer**: Don't install standalone - rustup provides it (conflicts otherwise)
3. **Shell paths**: Use system shells (e.g., `terminal.integrated.defaultProfile.osx = "zsh"`) instead of nix-managed paths
4. **Don't hand-list a package a `programs.*` module already provides.** Enabling
   `programs.direnv` installs direnv; also adding `direnv` to `systemPackages` is a
   duplicate. Let the program module own its package. (PR #11.)
5. **Enable the shell, or its hooks never get injected.** home-manager only wires a
   program's shell integration (direnv's `eval` hook, a tool's `wt`/`fzf` init) into
   shells it *manages*. `programs.direnv.enable = true` does nothing until
   `programs.zsh.enable = true` also puts the hook in `.zshrc`. A silent,
   cross-profile breakage. (PR #24.)
6. **Runtime-mutable config must stay unmanaged.** A tool that writes to its own
   config/state at runtime (taskbook's `~/.taskbook.json`, Claude's `~/.claude`
   credentials) breaks on first write if home-manager points that path at a
   read-only Nix-store symlink. Install the binary only; leave the state files
   unmanaged. (PRs #44, #10, #38.)

### Tools Nix Can't Fully Manage

Some tools resist Nix's immutable model. Recurring patterns learned the hard way:

- **SDK / version managers** (rustup, puro, asdf, nvm, rbenv) fight the store —
  they mutate `~/.rustup`, `~/.puro`, etc. at runtime. Don't wrap them in a
  nix-shell. Install globally or via a darwin `system.activationScripts` entry and
  put their bin dir on PATH. (PRs #3, #6; generalizes the rust-analyzer rule.)
- **Not in nixpkgs yet?** Reach for Homebrew before hand-rolling a
  `buildRustPackage` from source, and **never commit a `lib.fakeHash` placeholder**
  — the derivation can't build. PR #19 tried to package `envelope` from source with
  fakeHash and was abandoned; it now installs via a Homebrew cask.
- **Installer-script tools under home-manager activation** (the lazydiff pattern,
  see `home-manager/profiles/work.nix`). Five things bite, all non-obvious:
  1. Run the installer in `lib.hm.dag.entryAfter [ "writeBoundary" ]`, guarded so it
     only runs when missing, with a TODO to replace with a real derivation.
  2. Activation runs with a **sanitized PATH** (no `/usr/bin`) — installers can't
     find `tar`/`curl`/`gzip`. `export PATH=${lib.makeBinPath [ ... ]}:$PATH` with
     the nixpkgs tools. Note an env prefix does **not** cross a `| /bin/sh` pipe, so
     it must be `export`ed inside the piped command, not inlined before it.
  3. Put the tool's bin dir on PATH with `home.sessionPath`, **not** an rc-file
     export — home-manager regenerates `.zshrc`, so the installer's own PATH append
     is discarded.
  4. Guard on the **binary path** (`[ -x "$HOME/.tool/bin/tool" ]`), not
     `command -v tool` — the sanitized activation PATH can't see the tool, so a
     `command -v` guard always fails and reinstalls on every switch.
  5. **Pin the installer version** (`--version x.y.z`); `releases/latest` hits the
     unauthenticated GitHub API (rate-limited, non-reproducible).
  (PRs #32 → #37. #32 merged green but delivered no working binary — see Testing.)
- **Activation ordering for generated imports:** if an activation entry appends an
  `@import` line pointing at a *linked* file, gate it with
  `entryAfter [ "linkGeneration" ]`, not `writeBoundary` — otherwise CLAUDE.md can
  import a rule file that hasn't been symlinked yet. (PR #38; see
  `modules/tools/claude-code.nix`.)
- **Keep a CLI version-matched to its companion extension by pinning a dedicated
  fast-updating input, not nixpkgs.** `claude-code` is pinned to
  `sadjow/claude-code-nix` (ships Anthropic's prebuilt binary, updates hourly)
  because nixpkgs lagged the VSCode extension by a full minor version. The failure
  mode is nasty: a skewed CLI surfaced only as an opaque **"Interrupted"** with no
  version message. If the extension misbehaves, suspect the pin first. (PR #26.)

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
2. Prefer the simplest home that fits: `lib/core-packages.nix` for a universal
   CLI, a profile's `packages` for a one-off, a module only when there's real
   config to own (see Module Organization). Is it in nixpkgs? If not, see "Tools
   Nix Can't Fully Manage".
3. Import the module in appropriate profiles
4. **Shell integration is a separate step from installing the binary.** If the
   tool needs a shell hook (direnv's eval, a directory-changing command like
   worktrunk's `wt switch`), add it to `interactiveShellInit` / `initExtra` and
   guard it so it only loads when the binary is on PATH. (PRs #23, #24.)
5. Document any conflicts or special considerations
6. Commit with clear reasoning

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

**Passing activation is NOT proof a tool works.** A `switch` that exits 0 only
means the config evaluated and applied — it does not mean an installer ran, a
binary landed, or that it's resolvable in a login shell. PR #32 merged green but
delivered no working `lazydiff`; three stacked bugs only surfaced under a clean
tart-VM `darwin-rebuild switch` followed by `zsh -lc 'command -v lazydiff'`.
Verify the end state (binary present *and* on the interactive PATH), ideally in a
throwaway VM, before calling an install done. (PR #37.)

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

The justfile mirrors CI — prefer the shortcuts over the raw commands:

```bash
just ci      # lint + check, the full local pre-push gate
just lint    # statix + deadnix only
```

Or the raw equivalents:

```bash
nix profile install nixpkgs#statix && statix check .
nix profile install nixpkgs#deadnix && deadnix --fail .
nix flake check --all-systems
```

**Keep `just lint` at parity with CI.** deadnix only exits non-zero with `--fail`,
so both the justfile (`lint-deadnix`) and CI must pass it — otherwise a green
`just ci` silently diverges from CI on dead code. (This drifted for a while:
the justfile ran report-only `deadnix -- .` while CI ran `--fail .`; realigned
so `just ci` is a trustworthy pre-push gate.)

Note the CI workflow pins its GitHub Actions to `@main` and historically leaned
on the now-sunset `magic-nix-cache-action`; treat floating action refs and that
cache step as maintenance landmines. (PR #1.)

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

*Last updated: 2026-07-28 - Synced Repository Structure with reality (lib/, tools/, secrets/, docker/, modules/tools/); documented the shared `lib/core-packages.nix` pattern; compounded durable lessons mined from closed PRs (#1, #3, #6, #7, #11, #13, #14, #19, #20, #23, #24, #26, #32, #35, #37, #38, #44, #46) into Config Conflicts, a new "Tools Nix Can't Fully Manage" section, System-vs-User, Module Organization, Testing, and CI Checks*
