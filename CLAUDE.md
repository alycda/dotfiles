# Claude Code Guidelines for This Repository

This document provides guidance for Claude Code when working with this dotfiles repository. It captures conventions, preferences, and the philosophy behind this configuration.

## Repository Philosophy

**This repository documents a learning journey with Nix, not just a final configuration.**

The commit history should tell a story of exploration, problem-solving, and evolution. Favor meaningful, incremental commits over large squashes when they help illustrate the "why" behind decisions.

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
│   ├── core-packages.nix   # Packages shared by devShells + home-manager
│   └── skills-sh.nix       # skills.sh agent skills pinned via nix-skills
├── tools/                  # Non-Nix tool content wired in by modules/tools/*
│   ├── agents/             # Agent-instruction overlay (AGENTS.md, #40)
│   ├── cheat/              # Cheatsheets + cheatpath config
│   ├── claude/             # Claude rules
│   └── helix/              # Helix config
├── secrets/                # agenix/ragenix age-encrypted secrets
├── docker/                 # container notes (per-arch CLAUDE.md) + entrypoint
├── docs/                   # everything published to GitHub Pages, authored as plain
│   ├── essays/             #   markdown + YAML frontmatter
│   └── solutions/          # documented solutions to past problems - bugs, practices,
│                           #   workflow patterns - by category, with YAML frontmatter
│                           #   (module, tags, problem_type). Relevant when implementing
│                           #   or debugging in an area one of them covers.
├── site/                   # Zola static site (templates, sass, collector).
│                           #   content/ and data/ are GENERATED - never edit them
├── CONCEPTS.md             # shared domain vocabulary (entities, named processes,
│                           #   status concepts) with project-specific meaning
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

### External agent skills (`lib/skills-sh.nix`)

Skills from [skills.sh](https://www.skills.sh/) install declaratively through
the `nix-skills` flake input ([sudosubin/nix-skills](https://github.com/sudosubin/nix-skills),
an auto-refreshed index that pins rev+hash for every published skill repo).

**Do not apply nix-skills' overlay.** Forcing any single `pkgs.skills.*`
attribute parses all ~48MB of index JSON and materializes a 480k-entry
attrset — measured at ~65s wall / 3.6GB peak RSS per evaluation (2026-08-04).
Since agent-skills.nix is in common.nix, that cost would hit every switch and
every configuration in `nix flake check --all-systems`.

Instead, `lib/skills-sh.nix` reads only the per-first-letter data shard for
each source repo and calls upstream's `buildSkill` directly — byte-identical
derivations at ~1s eval cost. It's exposed as `pkgs.skills-sh.<name>` via an
overlay wired in both `flake.nix` (mkHome) and `darwin/configuration.nix`,
and consumed by `home-manager/modules/tools/agent-skills.nix`.

- **Add a skill**: new `mkSkill` entry in `lib/skills-sh.nix` + a
  `home.file` line in agent-skills.nix
- **Update pins**: `nix flake update nix-skills` (pins can lag upstream HEAD
  by days-to-weeks — they move when the index re-resolves the repo)
- **Plugins are not skills**: anything shipped as a Claude Code plugin
  (e.g. compound-engineering) belongs in
  `tools/agents/plugins/catalog.json`, not here — a plugin already carries
  its skills, so installing them via nix-skills too would duplicate them

### The docs site (`site/`, published to GitHub Pages)

`docs/` is authored as plain markdown with YAML frontmatter and stays readable
in the repo — agents and humans read those files directly, without a site build
in the loop. Zola wants TOML frontmatter under `+++`, its own section layout,
and taxonomies in a particular shape. Rather than reformat the sources to suit
the generator, `site/bin/collect.py` translates them on the way in.

**`site/content/` and `site/data/` are build artifacts.** They are gitignored,
wiped and regenerated on every build. Editing them is always wrong — change the
markdown in `docs/`, or `CONCEPTS.md`, and rebuild.

What the collector does, and why each piece exists:

| Behaviour | Reason |
|---|---|
| YAML frontmatter → TOML, unknown keys → `[extra]` | Zola only reads TOML; passing unknown keys through means adding a frontmatter field needs no collector change |
| `filed_under` → the `tags` taxonomy | essays borrow the phrasing from the design this site cribs; one tag index for the whole site |
| `docs/solutions/<category>/x.md` → flat, `category = [...]` | Zola would read the nested directory as a subsection needing its own `_index.md`; the nesting is replayed as a taxonomy instead |
| Body-leading `# Title` stripped when it matches the frontmatter title | in-repo a solution doc wants a visible H1; on the site the template already renders one |
| `CONCEPTS.md` → `site/data/concepts.toml` | backs the `[E01]` entity references |

**Entity references.** `{{ e(name="Base profile") }}` in an essay renders a
linked `[E04]` resolving to the glossary, and any concept named in a page's
`concepts:` frontmatter gets a definition block at the foot of the page. Both
read from `CONCEPTS.md`, so the glossary is the single source. A name with no
matching entry degrades to visible `[Name?]` rather than failing the build —
cheap to spot in review, and a renamed concept never breaks a deploy.

**Section numbering is presentation.** The `§ 01` before each heading is a CSS
counter on `.prose.counts h2`. Markdown sources stay plain `## Heading`.

**Fonts are not vendored.** `site/sass/main.scss` names Newsreader / Inter /
JetBrains Mono and falls back through faces present on most machines, so the
site is fully styled with zero webfont bytes. `just docs-fonts` documents how
to add the real ones.

```bash
just docs-serve    # live reload at 127.0.0.1:9652
just docs-build    # one-shot build into site/public
```

**Zola comes from the `docs` devShell, never from `nix shell nixpkgs#zola`.**
That second form resolves against the *machine's flake registry*, not this
repo's `flake.lock`, so two machines can build the same commit with different
Zola versions. That bit immediately: the site was authored against 0.19, whose
`[markdown]` schema (`highlight_code`, `highlight_themes_css`) 0.22 rejects
outright — CI failed on config the local build accepted. Both `just` and
`.github/workflows/pages.yml` now go through `nix develop .#docs`, so a version
bump can only arrive via `flake.lock`, where it shows up in a diff.

Zola 0.22 moved syntax highlighting to `[markdown.highlighting]` with
`style = "class"` and a `light_theme`/`dark_theme` pair, and theme names now
come from [giallo](https://github.com/getzola/giallo) (`gruvbox-light-medium`,
not `gruvbox-light`). It generates `giallo-light.css` / `giallo-dark.css` into
`site/static/`; those are artifacts and gitignored.

CI is path-filtered to `docs/`, `CONCEPTS.md`, and `site/` — a Nix-only change
never triggers a redeploy — and PRs build without publishing.

### Configuration Conflicts to Avoid

1. **Overlays**: Set `nixpkgs.overlays` ONLY at darwin system level, not in home-manager modules
2. **Rust-analyzer**: Don't install standalone - rustup provides it (conflicts otherwise)
3. **Shell paths**: Use system shells (e.g., `terminal.integrated.defaultProfile.osx = "zsh"`) instead of nix-managed paths
4. **Base-image package collisions**: The `nixos/nix` image ships its own populated `nix-env` profile in the container, so anything home-manager installs can collide with a package already there and abort activation. This has bitten three times (`git-minimal` #34, `man-db` #60, `bash` #74). Three remedies, chosen by who needs the program:
   - **Ship none** — `programs.<x>.package = null` when you only wanted the module's *config* (see `home-manager/profiles/dev.nix`)
   - **Remove the base copy** — the `nix-env -e` loop in `docker/entrypoint.sh`, when home-manager's version is genuinely required
   - **`lib.hiPrio`** — only for collisions *within* home-manager's own closure; it cannot reach across nix-env profile elements

   A green `nix build` does not catch these: the profile union is computed at activation time on the target machine. Full write-up: `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md`

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

- **`repeated_keys`**: Fires on the **third** assignment sharing a dotted prefix, not the second. Two `foo.a = …; foo.b = …;` statements sit green indefinitely; whoever appends `foo.c = …` gets the failure. That threshold is the whole trap — the breaking change looks purely additive, and the two lines that made it inevitable were already merged and passing. Nest under one attrset instead.
  ```nix
  # ❌ repeated_keys — legal Nix, but the third `age.secrets.` fails the lint job
  age.secrets.agent-instructions = { ... };
  age.secrets.linear-api-key-work = { ... };
  age.secrets.linear-api-key-personal = { ... };

  # ✅ correct
  age.secrets = {
    agent-instructions = { ... };
    linear-api-key-work = { ... };
    linear-api-key-personal = { ... };
  };
  ```
  Hit in #79 adding a third agenix secret. When a repeated prefix reaches two,
  consider collapsing it then — the next person to add one is otherwise doing
  an unrelated refactor inside their own change.

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

### Entity diff (informational, non-blocking)

`.github/workflows/entity-diff.yml` runs [Sem](https://github.com/Ataraxy-Labs/sem)'s
GitHub Action on every PR. It posts a sticky PR comment listing which
functions, classes, and methods changed (entity-level diff via tree-sitter,
not line-by-line) — useful for scanning what actually changed in a module
without reading the full diff. It's display-only: no config, no API keys,
and it never fails the build, so it doesn't gate merging alongside the
lint/check jobs above.

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

*Last updated: 2026-08-05 - Added the docs site: `docs/` authored as plain markdown, `site/bin/collect.py` translating it into a Zola content tree, and `[E01]` entity references backed by CONCEPTS.md*

*2026-08-05 - Documented statix's `repeated_keys` threshold: it fires on the third assignment sharing a dotted prefix, so a green two-key pattern makes the next additive change fail CI (#79)*

*2026-08-04 - Documented the `lib/skills-sh.nix` pattern for declarative skills.sh installs via nix-skills (and why its full overlay is avoided); surfaced the knowledge store (`docs/solutions/`) and `CONCEPTS.md` in Repository Structure; added base-image package collisions as a fourth configuration conflict after it bit a third time (#74)*
