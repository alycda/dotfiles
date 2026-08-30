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
│   ├── charm-nur.nix       # scoped overlay for charmbracelet/nur (crush)
│   ├── core-packages.nix   # Packages shared by devShells + home-manager
│   └── skills-sh.nix       # skills.sh agent skills pinned via nix-skills
├── tools/                  # Non-Nix tool content wired in by modules/tools/*
│   ├── agents/             # Agent-instruction overlay (AGENTS.md, #40)
│   ├── cheat/              # Cheatsheets + cheatpath config
│   ├── claude/             # Claude rules
│   ├── hackmd/             # npm pin (package.json + lock) for hackmd-cli
│   └── helix/              # Helix config
├── secrets/                # agenix/ragenix age-encrypted secrets
├── docker/                 # container notes (per-arch CLAUDE.md) + entrypoint
├── docs/solutions/         # documented solutions to past problems - bugs, practices,
│                           #   workflow patterns - by category, with YAML frontmatter
│                           #   (module, tags, problem_type). Relevant when implementing
│                           #   or debugging in an area one of them covers.
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

### Packaging an npm CLI that nixpkgs doesn't have

`home-manager/modules/tools/hackmd.nix` is the worked example. When a tool
only exists on npm, package it from a **pin-only** `tools/<tool>/package.json`
whose single dependency is the published package, plus the `package-lock.json`
generated from it — then build with `pkgs.importNpmLock.buildNodeModules` and
wrap `node <entrypoint>` in a `writeShellApplication` (which shellchecks the
wrapper for free, and leaves room for a guard — see the last paragraph here).

Use `importNpmLock`, not `buildNpmPackage`'s default `fetchNpmDeps`. The latter
needs an `npmDepsHash` over the whole dependency FOD, which you can only obtain
by running a build and copying the hash out of the mismatch error — impossible
to produce in an environment without Nix, and a second thing to keep in sync
forever. `importNpmLock` fetches each dependency by the integrity hash already
in the lockfile, so the lockfile *is* the pin.

Two consequences of "the lockfile is the pin" that bit on the first use:

- **Every entry in the lock is fetched, not just the ones for the build
  platform.** A dependency that ships per-platform binaries (typescript 7.x
  ships 20 of them) downloads all of them on every machine to install one.
  Pin such a dependency down to a pure-JS version with an npm `overrides`
  entry.
- **npm-declared runtime dependencies are often nothing of the sort.**
  hackmd-cli declares the `oclif` publisher CLI — yeoman, aws-sdk v2 — as a
  runtime dep while its shipped code only ever requires `@oclif/core`.
  Redirect the edge with an `overrides` alias to a package already in the tree
  rather than deleting it, so a surprise `require` gets a real module. (npm
  does not dedupe an alias against the real package, so the aliased target is
  installed twice — cheap next to what the override saves, but not free.)
  Between the two overrides: 770 packages / 263MB → 161 / 50MB.

Both overrides need a comment saying what they buy, because a later
`rm package-lock.json && npm install --package-lock-only` silently reverts to
the fat tree if someone drops them. Add `**/node_modules` coverage to both
`.gitignore` and `.dockerignore` while you are here: the bump procedure runs
npm inside the repo, and `tools/` is in the Docker build context.

One more thing a CLI needs before it belongs in `common.nix`: **a credential
prompt must not be reachable headlessly.** `common.nix` is inherited by the
devcontainer, so anything installed there gets called by agents on machines
where nobody ever ran `login`. A CLI that prompts for a token and re-asks on an
empty answer does not fail there — it spins until killed. Guard the
non-interactive path in the wrapper (`tools/hackmd/token-guard.sh` is the
worked example: no TTY + no token + a command that needs one = exit 1 with the
env var to set), and leave the TTY path alone.

### Packaging a Go CLI that nixpkgs doesn't have

`home-manager/modules/tools/workflowy.nix` is the worked example, and the
decision it turns on is **source build vs. vendored release binaries** - the
same fork `lib/charm-nur.nix` took the other way for crush.

`buildGoModule` needs two hashes (the `fetchFromGitHub` `hash` and the
`vendorHash`), and both are obtained the same way: set them to `lib.fakeHash`
one at a time and read the real value out of the mismatch error. Neither can be
produced without running Nix, so a bump is a machine-with-Nix operation, not a
docs edit. Prefer `tag = "v${finalAttrs.version}"` over a literal so the tag
follows the version, and name `subPackages` so the build doesn't walk a repo
that also holds libraries and assets.

Upstream's release binaries are a real alternative, not a trap. It is tempting
to rule them out on macOS signing grounds - **that reasoning is wrong, and this
paragraph exists because it was committed here before being checked**. Go's own
linker ad-hoc code-signs every darwin/arm64 binary it links (`NeedCodeSign() =
IsDarwin() && IsARM64()` in `cmd/link/internal/ld/lib.go`, reaching
`cmd/internal/codesign`), so a GoReleaser tarball executes on Apple Silicon
with nobody running `codesign`. Verify a claim like that against the toolchain
source before it becomes a rule.

What actually decides it is duller: `buildGoModule` covers every supported
system from one pair of hashes where `fetchurl` needs one per platform, and
pins auditable source instead of someone's CI output. Against that, the Go
toolchain lands in the *build* closure - and nothing substitutes for a package
that isn't in nixpkgs, so every machine really does realise it.

**That build-closure cost is not always transient.** On a normal machine it is
collectable; inside `docker build` it is permanent, because the Dockerfile
builds the activation package in an image layer and never garbage-collects, so
~250MB of compiler is frozen into the image for an 11MB binary. That is what
keeps `workflowy.nix` out of `common.nix` and in the desktop profiles, the same
split `./ide/vscode.nix` already has and for the same disk. A from-source
package that the devcontainer has no working configuration for anyway belongs
in the profiles, not in the module every profile inherits.

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

### When nixpkgs lags: prefer the vendor's own Nix repo over NUR

nixpkgs is a *downstream* packager. For a fast-moving upstream that ships
more often than a volunteer remembers to bump it, `nix flake update` is not
a fix — it locks a newer nixpkgs that still contains the same old package.
Diagnose it that way before reaching for anything: check the pinned rev's
`pkgs/by-name/<xx>/<pkg>/package.nix`, then check nixpkgs **master**, then
check for an open bump PR. If master is stale too, no lockfile move can help.

That is exactly how `crush` ended up three releases behind (nixpkgs 0.88.1
from 2026-08-07 vs upstream 0.91.2 on 2026-08-26, no open PR). The nixpkgs
bumps land every one to three weeks and crush tags weekly, so the drift is
structural rather than a one-off.

The fix is `charmbracelet/nur` as a **direct flake input** (`lib/charm-nur.nix`
+ the `charm-nur` input in `flake.nix`). Three things to carry forward:

- **Prefer the vendor's repo to `nix-community/NUR` even when NUR is what
  surfaced it.** NUR is a meta-index: it *republishes* per-user repos behind
  its own `repos.json` pins, so consuming crush through it adds a staleness
  layer and a large lazy eval surface for one package, and the thing that
  moves the version is NUR's index refresh rather than your lockfile. Taken
  directly, the same expressions are pinned in `flake.lock` and
  `nix flake update charm-nur` is the operation that bumps them. Use NUR
  itself for *discovery* — `nur.nix-community.org/repos/<user>/` is how you
  learn the vendor repo exists and what version it carries.
- **Scope the overlay; never apply the vendor's `overlays.default`.** Charm's
  is `final: prev: import ./pkgs { pkgs = final; }` — it shadows *every*
  Charm attribute in nixpkgs (glow, vhs, gum, …) at the top level. Ours are
  already current in nixpkgs and built from source there; wanting a fresh
  crush is not a reason to silently swap them for prebuilt binaries. Bind the
  set to one attribute (`pkgs.charm-nur.<name>`) instead, and wire that overlay
  in all three places pkgs gets built: `mkHome`, `darwin/configuration.nix`,
  **and** the flake's devShells (`lib/core-packages.nix` is shared with the
  devShells, so an attribute missing there is an evaluation failure).
- **Take the package, not the vendor's home-manager module.** Charm's
  `programs.crush` writes `xdg.configFile."crush/crush.json"` — the exact
  path `home-manager/modules/tools/crush.nix` already owns. Two modules, one
  path, one activation conflict of the kind already catalogued below.

One eval detail worth remembering: a vendor flake's `packages.<system>`
output imports nixpkgs *itself*, with no `config`, so for an unfree package
(crush is FSL-1.1-MIT) forcing it throws regardless of our `allowUnfree`.
Applying their overlay against our own `final` sidesteps that — the package
set gets built with our config. The upside of the switch is that these are
GoReleaser release binaries rather than source builds, and cache.nixos.org
never had a binary for the unfree nixpkgs build anyway, so every machine had
been compiling crush from scratch.

### Configuration Conflicts to Avoid

1. **Overlays**: Set `nixpkgs.overlays` ONLY at darwin system level, not in home-manager modules
2. **Rust-analyzer**: Don't install standalone - rustup provides it (conflicts otherwise)
3. **Shell paths**: Use system shells (e.g., `terminal.integrated.defaultProfile.osx = "zsh"`) instead of nix-managed paths
4. **Base-image package collisions**: The `nixos/nix` image ships its own populated `nix-env` profile in the container, so anything home-manager installs can collide with a package already there and abort activation. This has bitten three times (`git-minimal` #34, `man-db` #60, `bash` #74). Three remedies, chosen by who needs the program:
   - **Ship none** — `programs.<x>.package = null` when you only wanted the module's *config* (see `home-manager/profiles/dev.nix`)
   - **Remove the base copy** — the `nix-env -e` loop in `docker/entrypoint.sh`, when home-manager's version is genuinely required
   - **`lib.hiPrio`** — only for collisions *within* home-manager's own closure; it cannot reach across nix-env profile elements

   A green `nix build` does not catch these: the profile union is computed at activation time on the target machine. Full write-up: `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md`

5. **System-level shell config reaches every account**: anything under
   `programs.zsh.*` in nix-darwin is written to `/etc/zshrc` / `/etc/zshenv`,
   which every user on the machine reads - including a non-admin account with
   no Nix, no home-manager, and no way to opt out. `brew shellenv` there puts
   the admin's `/opt/homebrew` on their `FPATH`, and nix-darwin's global
   `compinit` then prompts them about it on every login. Write system-level
   shell config for the account that owns the least, not for the one running
   `darwin-rebuild`. Full write-up:
   `docs/solutions/runtime-errors/zsh-compinit-prompts-every-non-admin-login.md`

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

### Check job: `nix flake check --all-systems` + config evaluation

The flake must evaluate cleanly across all systems. This catches type errors, missing attributes, and evaluation failures.

**`nix flake check` alone does not cover the configs anyone switches to.**
It only evaluates output types it recognizes; `darwinConfigurations` and
`homeConfigurations` are skipped with an "unknown flake output" warning, so
for this flake it exercises just the devShells. The check job therefore also
runs `.github/scripts/eval-configurations.sh`, which forces each
configuration's top-level derivation path (`system.drvPath` /
`activationPackage.drvPath`) — full module evaluation with no builds, which
is what lets the aarch64-darwin configs be checked on a Linux runner.

### Running linters locally before pushing

```bash
nix profile install nixpkgs#statix && statix check .
nix profile install nixpkgs#deadnix && deadnix --fail .
nix flake check --all-systems
./.github/scripts/eval-configurations.sh
```

### Flake input updates: `update-flake-lock.yml`

`.github/workflows/update-flake-lock.yml` runs `nix flake update` — weekly
on a `schedule:` cron, or on demand via `workflow_dispatch`, where a text
field can scope the update to specific inputs — validates the result, and
opens a PR on the `automation/flake-update` branch. The manual trigger
exists so lockfile updates can be kicked off and validated from anywhere
(including the GitHub mobile app) without needing a checkout on whichever
machine happens to be current; the weekly cron exists so they happen even
when nobody thinks to ask.

The schedule is only safe because the validation below already gates PR
creation: an unattended run cannot produce a PR for a lockfile that doesn't
evaluate. Two `schedule:` mechanics worth remembering — it fires only for
the copy of the workflow on the **default branch** (editing the cron on a
feature branch changes nothing until it merges), and GitHub **disables
scheduled workflows after 60 days of repo inactivity**, emailing the owner
to re-enable them from the Actions tab.

The wrinkle it works around: **PRs created with the default `GITHUB_TOKEN`
never trigger `pull_request` workflows** (GitHub's anti-recursion rule), so
nix.yml would sit idle on the bot PR. Two compensations:

1. The workflow runs the full check-job validation *before* creating the
   PR, so a PR only ever appears for a lockfile that already evaluates.
2. `workflow_dispatch` is exempt from the anti-recursion rule, so after
   opening the PR it runs `gh workflow run nix.yml --ref
   automation/flake-update`, giving the PR real lint/check runs — the "two
   jobs must pass" rule above holds for bot PRs too.

nix.yml also triggers on pushes to `automation/flake-update`, so a manual
fixup commit on a bot PR is re-validated (bot pushes are exempt from that
trigger; human pushes fire it). Operational notes: the repo setting "Allow
GitHub Actions to create and approve pull requests" (Settings → Actions →
General → Workflow permissions) must stay enabled or PR creation fails; and
a later run force-pushes the branch, superseding any still-open update PR.
That superseding is what keeps the weekly cron from piling up review debt —
an unmerged update PR is rolled forward onto the newest lockfile instead of
a second one opening beside it — but it also means a *narrow* manual
dispatch (`nixpkgs` alone, say) must be merged before the next Monday, since
the scheduled run updates everything and will replace it.

That setting is the one thing the workflow cannot establish for itself, and
it is what the first dispatch died on: `permissions: pull-requests: write`
in a workflow only *narrows* what `GITHUB_TOKEN` may do, so a repo (or
account) setting that withholds PR creation overrides it, and `gh pr
create` is refused identically. PR creation is therefore non-fatal — the
validated lockfile is already pushed by then, so the run dispatches nix.yml
on the branch anyway and writes a compare link into the job summary before
failing. Full write-up:
`docs/solutions/ci-errors/github-actions-not-permitted-to-create-pull-requests.md`

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

*Last updated: 2026-08-30 - Corrected the Go-packaging section written earlier the same day: it justified building from source with a macOS signing claim that is false (Go's linker ad-hoc signs every darwin/arm64 binary it links), and understated the cost by calling the build closure transient - it is permanent inside a Docker layer, which is why workflowy.nix moved from common.nix to the desktop profiles*

*2026-08-30 - Documented packaging a Go CLI nixpkgs doesn't carry (`buildGoModule` + the two fake-hash lookups) and the source-vs-release-binaries decision it turns on*

*2026-08-29 - Put the flake-update workflow on a weekly cron now that its manual dispatches have proven out, and recorded the two `schedule:` mechanics that make a cron behave unlike a dispatch (default-branch-only, auto-disabled after 60 days idle) plus why branch superseding is what keeps recurring updates from piling up review debt*

*2026-08-28 - Documented preferring a vendor's own Nix repo over nix-community/NUR when nixpkgs lags upstream (crush was three releases behind with nixpkgs master equally stale, so `nix flake update` could not fix it), including why the vendor overlay must be scoped rather than applied at top level and why their home-manager module collides with ours*

*2026-08-28 - Documented the `importNpmLock` pattern for packaging an npm-only CLI (hackmd-cli), including why the lockfile-as-pin approach makes over-declared npm dependencies and per-platform binary packages a build-size problem worth overriding away, and added the rule that a CLI reaching `common.nix` must not be able to hit an interactive credential prompt headlessly*

*2026-08-23 - Added "system-level shell config reaches every account" as a fifth configuration conflict after nix-darwin's global `compinit` prompted a non-admin user on every login for directories owned by the admin account*

*2026-08-17 - Recorded why the flake-update workflow's first dispatch could not open its PR ("Allow GitHub Actions to create and approve pull requests" was off; a workflow's `permissions:` block cannot re-grant it) and made PR creation non-fatal so a validated lockfile is never discarded*

*2026-08-17 - Documented the flake-update workflow (`update-flake-lock.yml`), the `GITHUB_TOKEN` anti-recursion rule and its `workflow_dispatch` exemption, and the check job's config-evaluation step (`nix flake check` skips `darwinConfigurations`/`homeConfigurations` as unknown outputs — CI previously only exercised the devShells)*

*2026-08-05 - Documented statix's `repeated_keys` threshold: it fires on the third assignment sharing a dotted prefix, so a green two-key pattern makes the next additive change fail CI (#79)*

*2026-08-04 - Documented the `lib/skills-sh.nix` pattern for declarative skills.sh installs via nix-skills (and why its full overlay is avoided); surfaced the knowledge store (`docs/solutions/`) and `CONCEPTS.md` in Repository Structure; added base-image package collisions as a fourth configuration conflict after it bit a third time (#74)*
