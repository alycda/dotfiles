# nix(hm): what else the code account needs, from main

- STATUS: OPEN
- TAGS: nix, home-manager, code, dev, parity

## Description

`code` is the Mac account without sudo on Shesfast (uid 504, in
`nix-users`, not `admin`). It runs a standalone home-manager generation
built from alycda/dotfiles `main` on 2026-09-21: `main`'s `common.nix` and
its `code` profile. `wvxnoozx` gives it `code@aarch64-darwin` here, on the
dev profile; `ruyomxwk` brought main's code profile (docker, rustup) into
dev as `home-manager/rust.nix`.

Switching `code` to this flake drops what this repo doesn't have yet. The
audit below compares that generation against the claude workspace's
octopus `ousknuxu` (every open lane, one tree), which is what this repo
will have once the lanes land.

### Already in a lane

- `main`'s core packages: `zotxyvzx` (`lib/packages/default.nix`).
- starship, fzf, bash: `home-manager/shell.nix` in the octopus.
- television, gh-dash: `souvvuoo` (`home-manager/tuis.nix`).
- cheat, taskbook, sem, weave, inspect, claude-code, helix, jj, just, gh,
  tmux: already on `develop`.

### Gaps (each a GAP row in the parity task 20261004-222929)

| What `code` has | From `main` | Lane |
| --- | --- | --- |
| `~/.agents` (AGENTS.md, rules, rubrics, 14 skills), `~/.claude` (rules, includes, 3 agents, a hook, skills), `~/.codex/AGENTS.md` | `agents.nix`, `agent-skills.nix`, `claude-code.nix` | agents: global skills |
| crush and `~/.config/crush` | `crush.nix`, the charm-nur input | agents: crush |
| `hackmd-cli` | `hackmd.nix` | hm: hackmd-cli |
| `git-worktree-clone` | `git-worktree-clone.nix` | just: global topic recipes |
| `presenterm` | `common.nix` | none found |
| nixd | `dev/nix-lang.nix` | none; nil is in dev (`vqtknwzq`) |
| agenix's launchd agent | ragenix's module | in place: `home-manager/agenix.nix` leaves macOS to it |

### Language servers

`code` has gopls/dlv, zig/zls, harper, just-lsp, swift-format,
typescript and vscode-*-language-server, golangci-lint-langserver, from
`main`'s `helix.nix`. `souvvuoo`'s work.nix says the rest are in
`home-manager/editor.nix`, but no such file is in the octopus tree. Check
whether it was dropped in the merge.

`souvvuoo` puts jdtls, kotlin-language-server and dart in the work
profile only; `code` has them today and loses them on dev.

### Outside Nix, kept by a switch

`~/.rustup` (stable, nightly-2024-08-01, nightly-2025-08-01),
`~/.cargo/bin` (wasm-pack, wr), `~/.orbstack` (the docker engine),
`~/.age/personal-key.txt`.

## Open questions

- Does `code` keep jdtls, kotlin-language-server and dart? Assumed no
  (work profile only) until decided.
- presenterm: every profile, dev only, or not at all? (nil: dev, decided
  2026-10-07; nixd not added.)
- zig and cargo-zigbuild in `rust.nix`, for Linux builds from the Mac:
  suggested, not decided. nodejs is in `zotxyvzx`'s core list; whether it
  moves to dev only is open.
- `code` standalone (switches itself) or as `home-manager.users.code` in
  shesfast's `mkDarwin` (alyssa switches it)? Assumed standalone, as on
  `main`.

## Verification

Not run yet. `ditto` can't reach the Nix daemon (permission denied on
`/nix/var/nix/daemon-socket/socket`), so nothing was evaluated. As `code`:

```sh
nix eval .#homeConfigurations.\"code@aarch64-darwin\".activationPackage.drvPath
nix eval .#homeConfigurations.\"vscode@aarch64-linux\".activationPackage.drvPath
nix run .#home-manager -- build --flake .#code@aarch64-darwin
nix run .#home-manager -- switch -b backup --flake .#code@aarch64-darwin
cargo --version && rustup component list --installed | grep rust-analyzer
```

Watch for a buildEnv collision from `stdenv.cc` on darwin.
