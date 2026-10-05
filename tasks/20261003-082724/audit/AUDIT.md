# shesfast: what main gives it that effver doesn't

Made on 2026-10-04 in a Tart VM (macOS 26.6.2, Nix 2.35.2) by evaluating
[audit.nix](audit.nix) against two configurations, without building either:

- **main**: `darwinConfigurations.shesfast` at `main@origin` profile `home`
  ([main-shesfast.json](main-shesfast.json)).
- **effver**: `darwinConfigurations.tart` on the Homebrew change, user
  `admin`, profile `dev`: what effver would give shesfast now, since the
  `home` profile is still empty ([effver-tart.json](effver-tart.json)).

Re-run from a checkout in the VM:

```sh
nix eval --impure --json --expr 'import ./audit.nix { flake = "path:/path/to/checkout"; host = "shesfast"; user = "alyssa"; }'
```

Equal on both sides already: system packages (13), `programs` and `services`
in nix-darwin, launchd daemons, `nix.settings` keys, `environment.variables`,
`/etc` files (bar the user's profile link), home-manager's launchd agent
(agenix).

Each box below is checked when the item is ported, or set aside with a
reason next to it. CLI first, then GUI.

## CLI

### 1. Secrets (6)

Main's are encrypted to the same key as effver's. Each comes with the module that
reads it.

- [ ] `personal/git-config.age`: git identity (main's `git.nix`). Here,
  `just identity` sets it from gh; keep effver, drop main's approach.
- [ ] `personal/agent-instructions.age`: the private agent instructions.
- [ ] `personal/hackmd-api-token.age`: hackmd-cli.
- [ ] `personal/ghost-api-key.age`: ghost (venari).
- [ ] `personal/linear-api-key.age`, `work/linear-api-key.age`.

### 2. home-manager packages (52 only on main)

- [ ] General CLI: bat, curl, eza, file, fzf, gawk, gnused, jq, ripgrep,
  python3, nodejs, man-db, bash-interactive, git.
- [ ] Secrets CLI on PATH: rage, ragenix (here only in the dev shell).
- [ ] Charm: crush, glow, skate, vhs.
- [ ] Language servers: nil, nixd, harper, just-lsp, gopls,
  golangci-lint-langserver, delve, jdt-language-server,
  kotlin-language-server, swift-format, typescript-language-server,
  vscode-langservers-extracted, zls, zig, dart. These are what main's helix
  `languages.toml` uses (item 5).
- [ ] Tools: asciinema, clock-rs, codecrafters-cli, glab, hcloud, hunk,
  lazydiff, presenterm, supabase-cli, tart, television, starship, gh-dash,
  git-worktree-clone, hackmd-cli, ghost.

Only in effver: huid-tasks, sem (main gets `sem-cli` from Homebrew),
weave-driver.

Decided by Alyssa on 2026-10-05: `mise.toml` gets no new tools, so every
tool here goes to Nix only (a profile, or `lib/packages`). mise keeps what
it has: the Ataraxy tools stay because the jujutsu skill depends on them.
The one possible exception is fzf, for searching unfamiliar machines, once
it is habit. jj's `fix` tools are out.

### 3. Shell and its variables

- [ ] `programs.starship`, `~/.config/starship.toml`, `STARSHIP_CONFIG`.
- [ ] `programs.fzf`, `FZF_*` (5 variables).
- [ ] `programs.bash`: `.bashrc`, `.bash_profile`, `.profile`. - why?
- [x] `CHEAT_CONFIG_PATH` (here only inside the checkout, through mise):
  set aside. The cheat sheets this repo has are enough for now (Alyssa,
  2026-10-05).

### 4. git

- [ ] `programs.git`, `~/.config/git/config`, identity from the
  `git-config` secret. Here: `tools/git/config` included from
  `~/.gitconfig`, identity from `just identity`.
- [ ] `git-worktree-clone`. - maybe

### 5. Editor and TUIs

- [ ] helix: `languages.toml` (with the language servers in item 2) and
  `themes/mine.toml`. Here only `config.toml` and `ignore`.
- [ ] television: six cable channels (cheat, claude, jj-log, postgres,
  redis, sqlite).
- [ ] gh-dash: `~/.config/gh-dash/config.yml`.
- [ ] crush: `crush.json` and its hooks (allow-commands, outbound-gate).

### 6. Agents (47 files)

- [ ] `~/.agents/`: AGENTS.md, persona, constitution, company values,
  preferred tooling, rubrics, rules (outbound-comment-gate).
- [ ] Skills, in both `~/.agents/skills/` and `~/.claude/skills/`: 14,
  among them brag-doc, cf-now, commit-craft, entity-level-git, jujutsu,
  hackmd-cli, html-deck, power-of-ten, ste100, here-now,
  supabase-postgres-best-practices, asd-ste100-skill. Here, two skills live
  in the repo's `.claude/skills/`, for this repo only.
- [ ] `~/.claude/`: critic agents, the instructions-loaded hook, includes,
  rules; `~/.codex/AGENTS.md`.
- [ ] Activation: `claudeAgentsImports`, `claudeManagedSettings`.

### 7. System defaults (17 only on main)

- [ ] Keyboard: `InitialKeyRepeat`, `KeyRepeat`, autocorrect and
  auto-capitalisation off.
- [ ] Trackpad: natural scrolling (`com.apple.swipescrolldirection`).
- [ ] Finder: show all extensions, no extension-change warning, path bar,
  status bar.
- [ ] Dock: autohide, orientation, `mru-spaces`, the four hot corners.

### 8. Homebrew: taps, formulae, policy

- [ ] Taps: `charmbracelet/tap`, `withgraphite/tap`.
- [ ] Formulae: docker, envchain, kondo, llmfit, ollama, openvpn, poppler,
  sem-cli, typst, wishlist, `withgraphite/tap/graphite`.
- [ ] Policy: main has `cleanup = "zap"`, `autoUpdate`, `upgrade`. Effver's
  module defaults to none of them. On shesfast, the lists match what is
  installed, so `zap` would remove nothing on the first switch.

### 9. Smaller

- [ ] `ensureAgenixSecretsDirParent` (activation): main makes the secrets
  directory's parent before agenix runs. Effver's darwin switch worked
  without it in the VM; check on shesfast.
- [ ] `~/.config/just/justfile`: main generates it; here `tools/just` is
  linked whole. Same recipes? (just parity task).

## GUI

- [ ] Casks (19): arc, brave-browser, claude, clocker, cmux, dropbox,
  font-jetbrains-mono-nerd-font, google-drive, logseq-og, obsidian, orbstack,
  proton-drive, proton-mail, proton-pass, rustdesk, tailscale-app,
  visual-studio-code, workflowy, zoom. The same 19 as installed today.
- [ ] VS Code: `programs.vscode` with three profiles (ditto, jujutsu, rust),
  their extensions and settings, user settings; activation
  `vscodeProfiles`, `vscodeImmutableUserSettings`. VS Code itself from Nix
  on main, and also as a cask. - PROFILES TO BE RE-CREATED
- [ ] `~/Applications/Home Manager Apps` (effver has `copyApps` instead).
