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

By where main gets them: its core list for every profile, its `home`
profile, and its program modules. Only the first two are this item; the
rest come with their categories.

- [x] main's core list, into `lib/packages/default.nix` for every Nix
  account, containers included, as on main: asciinema, bat, clock-rs,
  codecrafters-cli, curl, eza, file, gawk, glab, glow, gnused, hcloud, hunk,
  jq, nodejs, python3, rage, ragenix, ripgrep, skate, supabase-cli, vhs. All
  free, for both Linux and macOS.
- [x] tart, in the `home` profile: macOS only, unfree, allowed by name.
- [ ] crush: unfree, and from Charm's own input on main. With its config, in
  item 5.
- [ ] Language servers (nil, nixd, harper, just-lsp, gopls,
  golangci-lint-langserver, delve, jdt-language-server,
  kotlin-language-server, swift-format, typescript-language-server,
  vscode-langservers-extracted, zls, zig, dart): with helix, item 5.
- [ ] starship, fzf: item 3. git, git-worktree-clone: item 4. television,
  gh-dash: item 5. ghost, hackmd-cli: with their secrets, item 1. lazydiff:
  with the tools (a `mise(tools)` sibling exists, but mise gets no new
  tools). vscode: GUI. bash-interactive and man-db: `programs.bash`, item 3.

Only in effver: huid-tasks, sem (main gets `sem-cli` from Homebrew),
weave-driver.

Decided by Alyssa on 2026-10-05: `mise.toml` gets no new tools, so every
tool here goes to Nix only (a profile, or `lib/packages`). mise keeps what
it has: the Ataraxy tools stay because the jujutsu skill depends on them.
The one possible exception is fzf, for searching unfamiliar machines, once
it is habit. jj's `fix` tools are out.

### 3. Shell and its variables

- [x] `programs.starship`, `~/.config/starship.toml`, `STARSHIP_CONFIG`:
  in `home-manager/shell.nix`, as on main (nerd-font-symbols, 1s timeout).
- [x] `programs.fzf`, `FZF_*` (5 variables): as on main.
- [x] `programs.bash`: `.bashrc`, `.bash_profile`, `.profile`. home-manager's
  bash 5 on the Macs; config only in the containers, whose base image has
  its own bash (as main's dev profile does).
- [x] zsh: main's `zsh.nix` (line editor, chpwd repo status, history
  options, `AUTO_CD`, `..` aliases) is already `tools/zsh/interactive.zsh`.
- [x] `CHEAT_CONFIG_PATH` (here only inside the checkout, through mise):
  set aside. The cheat sheets this repo has are enough for now (Alyssa,
  2026-10-05).

### 4. git

- [ ] `git-worktree-clone`. - maybe

### 5. Editor and TUIs

Decided on 2026-10-05: crush moves to item 6; fzf keeps Ctrl-R; language servers
split by use.

- [x] helix: main's `languages.toml` and `themes/mine.toml`, and
  `theme = "mine"`, as plain files in `tools/helix/`, which the mise
  account links too.
- [x] Language servers, Nix only: nil, nixd, typescript-language-server,
  vscode-langservers-extracted, zls, zig, just-lsp, harper for every profile,
  swift-format on the Macs; jdt-language-server, kotlin-language-server, go and
  dart in the `work` profile only, so shesfast and the containers skip a JDK.
- [x] television: main's cheat, claude and jj-log cable channels, from
  `tools/television/cable/`. Its postgres, redis and sqlite examples are
  each in a change of their own, off this one, not in the profile.
  Its shell integration is off, so it binds no key: Ctrl-R and Ctrl-T stay
  fzf's. main bound Ctrl-R to `tv shell-history`. On macOS it finds the
  channels in `~/.config/television`.
- [x] gh-dash: main's settings.
- [x] The system font: Fira Code Nerd Font, on every Mac.
- [ ] crush: moved to item 6, with the agent files its config loads.

### 6. Agents (47 files)

- [ ] crush, moved here from item 5: `crush.json` (its context paths are the
  `~/.agents` files below, its hooks the outbound-comment gate and the
  bash allowlist, its allowed tools Linear's), the hooks, and crush itself:
  unfree, from Charm's own Nix input on main.

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

- [x] Casks: 18 of main's 19, in `darwin/shesfast.nix`; not installed one
  by one, since they are what shesfast has today. clocker moves to ditto
  (Alyssa, 2026-10-05); it stays installed here until removed by hand. Cleanup stays "none" until the formulae
  are listed too (item 8). arc, brave-browser, claude, clocker, cmux, dropbox,
  font-jetbrains-mono-nerd-font, google-drive, logseq-og, obsidian, orbstack,
  proton-drive, proton-mail, proton-pass, rustdesk, tailscale-app,
  visual-studio-code, workflowy, zoom. The same 19 as installed today.
- [x] Not on main: Second Clock (Mac App Store, id 6450279539), as
  `homebrew.masApps`; there is no cask. It needs macOS 26 (Alyssa,
  2026-10-05: shesfast is moving to it).
- [ ] VS Code: `programs.vscode` with three profiles (ditto, jujutsu, rust),
  their extensions and settings, user settings; activation
  `vscodeProfiles`, `vscodeImmutableUserSettings`. VS Code itself from Nix
  on main, and also as a cask. - PROFILES TO BE RE-CREATED
- [ ] `~/Applications/Home Manager Apps` (effver has `copyApps` instead).
