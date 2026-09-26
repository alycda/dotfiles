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
│   ├── ghost.nix           # overlay: Ghost CLI + server from the alycda/ghost fork (flake input)
│   ├── inspect.nix         # Ataraxy inspect: release binary repointed at nix openssl
│   └── skills-sh.nix       # skills.sh agent skills pinned via nix-skills
├── tools/                  # Non-Nix tool content wired in by modules/tools/*
│   ├── agents/             # Agent-instruction overlay (AGENTS.md, #40)
│   ├── cheat/              # Cheatsheets + cheatpath config
│   ├── claude/             # Claude rules
│   ├── hackmd/             # npm pin (package.json + lock) for hackmd-cli
│   ├── helix/              # Helix config
│   ├── mise/               # Global mise config for the no-Nix, non-admin account
│                           #   (bootstrap.sh links it to ~/.config/mise; no module)
│   └── venari/             # the rented box: twins of its /srv compose files (Soft Serve,
│                           #   Ghost) and /etc drop-ins; nothing deploys them
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

**Pinning nix-darwin is not set-and-forget.** `homebrew.onActivation.autoUpdate
= true` means the host updates brew and then self-breaks on its next rebuild
against a stale pin whose `brew bundle` call the newer CLI rejects. Repin to a
rev whose brew call matches current brew; the fixing rev may run `brew` as the
configured user, which requires that user own the Homebrew prefix. (PR #35.)

**A third-party tap runs its Ruby inside your activation.** `brew bundle`
loads every formula in `brews`, so a tap that raises aborts the whole
`darwin-rebuild switch` at a time chosen by `onActivation.autoUpdate`, with no
`.nix` change. Prefer nixpkgs for anything nixpkgs actually has: a pinned input
moves when you run `nix flake update`, not when a background `brew update`
decides. Two traps on the way out: a green `nix build` of a prebuilt-binary
derivation verifies a hash, not an ABI (run the binary), and `cleanup = "zap"`
cannot remove a formula it cannot load, so uninstall by hand before the switch.
Full write-up:
`docs/solutions/build-errors/third-party-tap-formula-aborts-darwin-rebuild.md`

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

### Packaging an npm CLI that nixpkgs doesn't have

`home-manager/modules/tools/hackmd.nix` is the worked example, and its header
comment carries the full reasoning. The shape: a **pin-only**
`tools/<tool>/package.json` whose single dependency is the published package,
its `package-lock.json`, `pkgs.importNpmLock.buildNodeModules`, and a
`writeShellApplication` wrapper around `node <entrypoint>`. Use
`importNpmLock`, not `buildNpmPackage`'s `fetchNpmDeps`: the lockfile *is* the
pin, and there is no `npmDepsHash` to obtain by running a build first.

Two consequences of "the lockfile is the pin": every lock entry is fetched,
including per-platform binaries you will never run, and npm-declared runtime
deps are often nothing of the sort. Both are fixed with npm `overrides` (pin
to a pure-JS version; alias an over-declared dep to a package already in the
tree). Each override needs a comment saying what it buys, because a later
`npm install --package-lock-only` silently reverts to the fat tree if someone
drops it. `**/node_modules` is in `.gitignore` and `.dockerignore` for the
same reason: the bump procedure runs npm inside the repo.

**A credential prompt must not be reachable headlessly.** `common.nix` is
inherited by the devcontainer, so a CLI there gets called by agents on machines
where nobody ran `login`. One that prompts for a token and re-asks on empty
input spins until killed. Guard the non-interactive path in the wrapper
(`tools/hackmd/token-guard.sh`: no TTY + no token + a command that needs one =
exit 1 naming the env var) and leave the TTY path alone.

### External agent skills (`lib/skills-sh.nix`)

Skills from [skills.sh](https://www.skills.sh/) install declaratively through
the `nix-skills` flake input ([sudosubin/nix-skills](https://github.com/sudosubin/nix-skills),
an auto-refreshed index that pins rev+hash for every published skill repo).

**Do not apply nix-skills' overlay.** Forcing any `pkgs.skills.*` attribute
parses the whole index (measured at ~65s / 3.6GB per evaluation, 2026-08-04),
and agent-skills.nix is in common.nix. `lib/skills-sh.nix` instead reads one
per-first-letter data shard per source repo and calls upstream's `buildSkill`
directly: byte-identical derivations at ~1s. Exposed as `pkgs.skills-sh.<name>`
via an overlay wired in `flake.nix` (mkHome) and `darwin/configuration.nix`,
consumed by `home-manager/modules/tools/agent-skills.nix`.

- **Add a skill**: new `mkSkill` entry in `lib/skills-sh.nix` + an
  `externalSkills` line in agent-skills.nix
- **Update pins**: `nix flake update nix-skills` (pins lag upstream HEAD by
  days-to-weeks; they move when the index re-resolves the repo)
- **Plugins are not skills**: anything shipped as a Claude Code plugin
  (compound-engineering) belongs in `tools/agents/plugins/catalog.json`, not
  here; installing its skills again would duplicate them
- **Tailor by layering, not by forking.** When an indexed skill has the right
  rule set but generic triggers, pin it and write a thin repo skill that
  delegates to it and carries only what is specific to this workflow.
  `tools/agents/skills/ste100` over `asd-ste100-skill` is the worked example:
  no rule text of its own, `CONCEPTS.md` as its dictionary.
- **Write the layer against the pinned rev, not upstream HEAD.** Check every
  path the layer names against the indexed rev
  (`data/by-name/<initial>/skills.json` in the locked nix-skills) or against
  `~/.agents/skills/<name>/` after a switch, and give the layer a fallback for
  anything that can lag. The `ste100` skill once named a linter the pinned rev
  did not carry; the pinned SKILL.md was self-consistent, the layer was not.

### When nixpkgs lags: prefer the vendor's own Nix repo over NUR

nixpkgs is a *downstream* packager. For an upstream that ships faster than a
volunteer bumps it, `nix flake update` locks a newer nixpkgs with the same old
package. Diagnose it that way first: the pinned rev's
`pkgs/by-name/<xx>/<pkg>/package.nix`, then nixpkgs **master**, then open bump
PRs. If master is stale too, no lockfile move can help. That is how crush
ended up three releases behind (#128); the full account is the header of
`lib/charm-nur.nix`. Three rules to carry forward:

- **Prefer the vendor's repo to `nix-community/NUR`**, even when NUR surfaced
  it. NUR republishes per-user repos behind its own pins, so the version moves
  on NUR's refresh, not your lockfile. Use NUR for *discovery* only.
- **Scope the overlay; never apply the vendor's `overlays.default`.** Bind the
  set to one attribute (`pkgs.charm-nur.<name>`) so it cannot shadow Charm
  attributes nixpkgs already builds from source, and wire that overlay in all
  three places pkgs gets built: `mkHome`, `darwin/configuration.nix`, and the
  flake's devShells (`lib/core-packages.nix` is shared with them).
- **Take the package, not the vendor's home-manager module.** Charm's
  `programs.crush` writes the same `crush/crush.json` that
  `home-manager/modules/tools/crush.nix` owns: one path, two modules, an
  activation conflict.

A vendor flake's `packages.<system>` imports nixpkgs itself with no `config`,
so forcing an unfree package there throws regardless of our `allowUnfree`;
applying their overlay against our own `final` sidesteps it.

### Configuration Conflicts to Avoid

1. **Overlays**: Set `nixpkgs.overlays` ONLY at darwin system level, not in home-manager modules
2. **Rust-analyzer**: Don't install standalone - rustup provides it (conflicts otherwise)
3. **Shell paths**: Use system shells (e.g., `terminal.integrated.defaultProfile.osx = "zsh"`) instead of nix-managed paths
4. **Base-image package collisions**: the `nixos/nix` image ships a populated
   `nix-env` profile, so anything home-manager installs can collide with it and
   abort activation (`git-minimal` #34, `man-db` #60, `bash` #74). Three
   remedies, chosen by who needs the program: `programs.<x>.package = null`
   when you only wanted the module's config (see `profiles/dev.nix`); the
   `nix-env -e` loop in `docker/entrypoint.sh` when home-manager's version is
   required; `lib.hiPrio` only for collisions *within* home-manager's own
   closure (it cannot reach across nix-env profile elements). A green
   `nix build` does not catch these: the profile union is computed at
   activation on the target machine. Full write-up:
   `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md`

   The contrast case: `ncurses` and `ghostty.terminfo` both provide
   `share/terminfo/g/ghostty` (#116). Both are things *we* asked for, so the
   comparison happens inside home-manager's `buildEnv`, reads `meta.priority`,
   and fails at *build* time with `two given paths contain a conflicting
   subpath`. Similar-sounding errors, different layers; work out which before
   picking a remedy.
5. **System-level shell config reaches every account**: `programs.zsh.*` in
   nix-darwin lands in `/etc/zshrc`, which a non-admin account with no Nix
   reads too. Write system-level shell config for the account that owns the
   least. Full write-up:
   `docs/solutions/runtime-errors/zsh-compinit-prompts-every-non-admin-login.md`
6. **Don't hand-list a package a `programs.*` module already provides.** Enabling
   `programs.direnv` installs direnv; also adding `direnv` to `systemPackages` is a
   duplicate. Let the program module own its package. (PR #11.)
7. **Enable the shell, or its hooks never get injected.** home-manager only wires a
   program's shell integration (direnv's `eval` hook, a tool's `wt`/`fzf` init) into
   shells it *manages*. `programs.direnv.enable = true` does nothing until
   `programs.zsh.enable = true` also puts the hook in `.zshrc`. A silent,
   cross-profile breakage. (PR #24.)
8. **Runtime-mutable config must stay unmanaged.** A tool that writes to its own
   config/state at runtime (taskbook's `~/.taskbook.json`, Claude's `~/.claude`
   credentials) breaks on first write if home-manager points that path at a
   read-only Nix-store symlink. Install the binary only; leave the state files
   unmanaged. (PRs #44, #10, #38.)
9. **Terminal capability in the container**: the `nixos/nix` image populates
   none of the FHS paths ncurses searches, so the dev profile installs
   `ncurses` (+ `ghostty.terminfo`) and sets `TERMINFO_DIRS` to
   `${config.home.profileDirectory}/share/terminfo`. Point it at the profile,
   never at a `/nix/store/...-ncurses-*` path. `pkgs.ncurses.terminfo` is an
   eval error, not an output; plain `pkgs.ncurses` is what you want.
   Full write-up:
   `docs/solutions/runtime-errors/container-ships-no-terminfo-term-falls-back-to-xterm.md`

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
- **Installer-script tools under home-manager activation.** lazydiff started
  this way (PRs #32 → #37) and has since graduated to a real derivation
  (`modules/tools/lazydiff.nix`); the rules stand for the next one:
  1. Run the installer in `lib.hm.dag.entryAfter [ "writeBoundary" ]`, guarded so it
     only runs when missing, with a TODO to replace with a real derivation.
  2. Activation runs with a **sanitized PATH** (no `/usr/bin`). `export
     PATH=${lib.makeBinPath [ ... ]}:$PATH` with the nixpkgs tools, *inside*
     any `| /bin/sh` pipe, since an env prefix does not cross it.
  3. Put the tool's bin dir on PATH with `home.sessionPath`, **not** an rc-file
     export — home-manager regenerates `.zshrc`.
  4. Guard on the **binary path** (`[ -x "$HOME/.tool/bin/tool" ]`), not
     `command -v tool`: the sanitized PATH can't see the tool, so a
     `command -v` guard reinstalls on every switch.
  5. **Pin the installer version**; `releases/latest` hits the unauthenticated
     GitHub API (rate-limited, non-reproducible).
  (#32 merged green but delivered no working binary — see Testing.)
- **Activation ordering for generated imports:** if an activation entry appends an
  `@import` line pointing at a *linked* file, gate it with
  `entryAfter [ "linkGeneration" ]`, not `writeBoundary` — otherwise CLAUDE.md can
  import a rule file that hasn't been symlinked yet. (PR #38; see
  `modules/tools/claude-code.nix`.)
- **Keep a CLI version-matched to its companion extension by pinning a dedicated
  fast-updating input, not nixpkgs.** `claude-code` is pinned to
  `sadjow/claude-code-nix` (ships Anthropic's prebuilt binary, updates hourly)
  because nixpkgs lagged the VSCode extension by a full minor version. A skewed
  CLI surfaced only as an opaque **"Interrupted"** with no version message. If
  the extension misbehaves, suspect the pin first. (PR #26.)
- **An account with no Nix gets its tools from mise.** A non-admin macOS account
  can't run `darwin-rebuild` and doesn't use home-manager, so `tools/mise/config.toml`
  lists its handful of tools. `tools/mise/bootstrap.sh` (curl-able, safe to run
  again) clones the repo over https, installs mise and links the *directory*
  to `~/.config/mise`, so `mise use -g` edits the tracked file in place. Steps
  that prompt stay in mise tasks, not the script: piped from curl, stdin is
  the script itself. Keep the list short and prefer aqua (prebuilt) backends;
  mise falls back to `cargo:` for some tools (jj), which compiles from source.
  This does not replace `lib/core-packages.nix`; the containers still get
  their tools from Nix.
- **Share a tool's config with that account as a plain file, not a generator.**
  Keep the file in `tools/<tool>/`, have the Nix module read it the way the tool
  loads config anyway (`fromTOML` for helix, git's `include`), and link or
  include the same file on the mise account. Anything tied to a store path, a
  secret, or an installed package stays in the Nix module. `helix.nix` reads
  `tools/helix/*.toml` this way.
- **Prebuilt binaries installed into a persisted `$HOME` are image-scoped state.**
  nixpkgs' `rustup` patchelfs downloaded toolchains to the glibc of the image
  that installed them, and `~/.rustup` in the `devhome` volume outlives image
  rebuilds; every shim then dies with ENOENT for a *loader* that no longer
  exists. Two rules: **guard activation on whether the tool executes, not
  whether it exists** (an existence check can never repair state that went bad
  in place); and repair by removing it, because `install --force` re-downloads
  nothing when the manifest says "unchanged". (#80.) Full write-up:
  `docs/solutions/runtime-errors/stale-rustup-toolchain-after-image-rebuild.md`
- **A vendor CLI outlives its service if the contract is public.** ghost.build
  wound down, but its CLI shipped the full `openapi.yaml` and read `api_url`
  from config, so the answer was a server for that contract (`alycda/ghost`,
  run on venari per `tools/venari/README.md`), not a rewrite (#56). Before
  declaring "no client patch needed", grep the client for assumptions the
  hosted service made true, and check how its config library treats an empty
  env var (viper drops them without `AllowEmptyEnv`). Client side follows the
  hackmd pattern: an env-setting wrapper (`modules/tools/ghost.nix`), never a
  managed copy of the config file the CLI writes; packaged from the fork as a
  flake input (`lib/ghost.nix`), whose header records both assumptions.

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
3. Wire it into the profiles that need it: a module gets imported by them; a
   plain package goes in each profile's `packages`. Either way, check whether
   every consumer of that placement should get it — `common.nix`,
   `lib/core-packages.nix`, and `work.nix` all feed the headless devcontainers,
   so gate a desktop-only tool (`lib.optional
   stdenv.hostPlatform.isDarwin`) rather than shipping it into a container.
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
throwaway VM, before calling an install done. (PR #37.) A prebuilt macOS
binary that runs on *this* machine proves little either: `lib/inspect.nix`'s
first candidate linked Homebrew's openssl by absolute path, so `otool -L` is
part of verifying any fetched Mach-O.

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

**skill frontmatter** (`.github/scripts/check-skill-frontmatter.sh`, via
`nix shell nixpkgs#yq-go`) checks each `tools/agents/skills/*/SKILL.md` against
the rules Crush's skill loader enforces: the YAML must parse, `name` must match
the directory, and `description` must be at most **1024 bytes**. Crush uses Go's
`len()`, so the limit is bytes, not characters: an em-dash costs 3. Crush skips
a skill that fails with no visible error (#175).

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
./.github/scripts/eval-configurations.sh
```

**Keep `just lint` at parity with CI.** deadnix only exits non-zero with `--fail`,
so both the justfile (`lint-deadnix`) and CI must pass it — otherwise a green
`just ci` silently diverges from CI on dead code. (This drifted for a while:
the justfile ran report-only `deadnix -- .` while CI ran `--fail .`; realigned
so `just ci` is a trustworthy pre-push gate.)

Note the CI workflow pins its GitHub Actions to `@main` and historically leaned
on the now-sunset `magic-nix-cache-action`; treat floating action refs and that
cache step as maintenance landmines. (PR #1.)

### Flake input updates: `update-flake-lock.yml`

`.github/workflows/update-flake-lock.yml` runs `nix flake update` (weekly
cron, or `workflow_dispatch` with a text field to scope it to named inputs),
validates the result with the full check-job steps, pushes
`automation/flake-update`, and opens a PR. The workflow's header comment
explains its own compensations; what an editor needs to know:

- **PRs created with `GITHUB_TOKEN` never trigger `pull_request` workflows**
  (GitHub's anti-recursion rule), so validation runs *before* the PR exists
  and the workflow then dispatches nix.yml on the branch by hand
  (`workflow_dispatch` is exempt). The "two jobs must pass" rule holds for
  bot PRs too.
- **`schedule:` fires only from the default branch** (editing the cron on a
  feature branch changes nothing until it merges), and GitHub **disables
  scheduled workflows after 60 days of repo inactivity**.
- **Each run force-pushes the branch**, superseding any open update PR. That
  keeps the weekly cron from piling up review debt, and it means a narrow
  manual dispatch must be merged before the next Monday.
- **PR creation is non-fatal** because the repo setting "Allow GitHub Actions
  to create and approve pull requests" is the one thing the workflow cannot
  grant itself: a `permissions:` block only narrows `GITHUB_TOKEN`. Full
  write-up:
  `docs/solutions/ci-errors/github-actions-not-permitted-to-create-pull-requests.md`

### Entity diff (informational, non-blocking)

`.github/workflows/entity-diff.yml` runs [Sem](https://github.com/Ataraxy-Labs/sem)'s
GitHub Action on every PR and posts a sticky comment listing which functions,
classes, and methods changed. Display-only: it never fails the build. Sem,
weave, and inspect are also installed locally by three different routes
(weave from nixpkgs; sem from homebrew-core as `sem-cli`, since nixpkgs' `sem`
is an unrelated Semaphore CI tool; inspect from `lib/inspect.nix`, because the
`ataraxy-labs/tap` formula's checksum went stale). Usage lives in the
`entity-level-git` skill, not here. Since CI already posts the entity diff on
every PR, don't post duplicate entity-diff comments.

## Learning Resources

When adding new Nix patterns or configurations, include links to:
- [Zero to Nix](https://zero-to-nix.com/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)
- [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)

## Meta: Updating This Document

This file is the implementation agent's context. Every line here loads before
any code is written, in every session, whether or not the session touches the
area the line is about. That makes it the most expensive place a lesson can
live: the implementer already carries exploration, the change, and debugging,
and a reviewer gets a diff and nothing else, so a rule enforced at review
costs nothing at write time. (Matt Pocock's `retro` skill states this
directly; adopted in #90.) So a lesson does not default to "add it here."
Triage it first:

- **A check** (something a tool can catch: a lint rule, an eval failure, a
  byte limit) goes into CI or the justfile. Here, at most one line naming the
  check and what it fails on. `repeated_keys` under CI Checks is the model: the
  rule is statix's; the paragraph here says only why the third key is the trap.
- **A standard** (how code or config should be written, judged rather than
  parsed) goes where the reviewer loads it: `tools/agents/rubrics/` for the
  critics, or a repo's `CODING_STANDARDS.md` for the `review` skill. Not here.
- **A post-mortem** (what broke, how it was diagnosed, what was measured) goes
  in `docs/solutions/<category>/` with frontmatter, and here as the
  one-sentence rule plus the pointer. When the write-up already exists, a
  paragraph here retelling it is duplication, not documentation.
- **Orientation** stays: where things are, which placement feeds which
  consumer (`common.nix` feeds the container), what Nix cannot manage and the
  shape of the workaround. An implementer needs this before the first edit,
  and a reviewer cannot cheaply retrofit it.

The test for a paragraph: would an implementer make a worse *first edit*
without it? If not, it is review-side or archive-side material.

When you add, commit with a message explaining what prompted the addition,
and put one dated line in the trailer below. The trailer keeps the five most
recent entries; the full history is `jj log -- CLAUDE.md` (or `git log`).

---
*2026-09-26 - Applied the triage rule backward (#90): post-mortems that already have a `docs/solutions/` write-up or a file-header account (tart tap, base-image collisions, terminfo, rustup, crush/charm-nur, hackmd, ghost, the flake-update workflow) are now the rule plus a pointer; the trailer keeps five entries. 53KB to 40KB; what remains is orientation by the section's own test*
*2026-09-21 - Ghost (#56): ghost.build is shutting down, so venari now runs a server for its OpenAPI contract from the alycda/ghost fork, with the CLI packaged from that fork and driven by an env-setting wrapper; recorded the two client-side assumptions (`tsdb` dbname, viper's empty-env handling) that the "no CLI patch needed" plan missed*
*2026-09-21 - Added "prebuilt binaries in a persisted `$HOME` are image-scoped state" to Tools Nix Can't Fully Manage, after a rustup toolchain in the devhome volume survived an image rebuild and left `cargo` erroring ENOENT for a loader that no longer existed (#80)*
*2026-09-16 - Replaced inspect's stale-checksum tap formula with `lib/inspect.nix`; recorded that `otool -L` is part of verifying any fetched macOS binary, and that an availability claim about a package set is a checkable fact*
*2026-09-14 - Recorded the layer-not-fork pattern for tailoring an indexed skill (`ste100` over the pinned `asd-ste100-skill`) and the rule to write the layer against the rev the lock installs, not upstream HEAD*
