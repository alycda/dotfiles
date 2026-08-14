# bootstrap/ — the no-Nix, no-Docker path

`lite.sh` provisions a Linux box you SSH into where you have **no root, no
docker and no Nix**, and are not getting any of them.

```sh
curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/bootstrap/lite.sh | sh -s -- all
```

## Why this exists

The repo had three provisioning paths, and between them they left one cell of
the matrix empty:

| | admin | no admin |
|---|---|---|
| **docker** | [#29](https://github.com/alycda/dotfiles/issues/29) `install.sh` (Nix + home-manager) | `docker/dev.sh up` |
| **no docker** | [#29](https://github.com/alycda/dotfiles/issues/29) `install.sh` | **`bootstrap/lite.sh`** |

That gap was deliberate, not an oversight: #29's Aug-2026 field report narrowed
its own scope to "machines where you *are* admin" precisely because PR #60's
docker path had just covered the no-admin case. A locked-down remote with no
container runtime falls through both.

## What you get, in two tiers

| tier | size | what |
|---|---|---|
| `config` | ~700K, zero binaries | the `tools/` tree symlinked into `~/.config`, `~/.agents`, `~/.claude` |
| `bins` | ~12 static binaries | `hx cheat rg jq fzf starship jj gh rage bat eza tv` into `~/.local/bin` |

`config` is the tier that carries the actual knowledge — 364K of cheatsheets and
252K of agent instructions — and it needs nothing but `curl` and `tar`. Take it
alone on a box where you only ever read and grep.

```sh
lite.sh config          # plaintext only
lite.sh bins            # all binaries
lite.sh bins hx rg jq   # just these
lite.sh all             # both
lite.sh doctor          # what's installed, what's missing
lite.sh list            # the pinned version table for this arch
lite.sh uninstall       # remove all of it
```

Then, in your shell rc:

```sh
. ~/.local/share/dotfiles-lite/env.sh
```

Overrides: `REF` (git ref, default `main`), `LITE_HOME`, `LITE_BIN`,
`LITE_SOURCE` (use a local checkout instead of fetching), and `VER_<tool>` to
bump a single pinned binary.

## Alternatives considered

Written down because the last round of this thinking was lost — searching the
issues, PRs and tree for it turned up nothing, and it had to be re-derived from
scratch. Two off-the-shelf tools were weighed before `lite.sh`; they fail in
opposite directions, which is the useful part.

### chezmoi — competes with something we already have

The obvious answer to "lightweight dotfiles", and the wrong one *here*. Its
three real value-adds — templating, per-machine variance, and age-encrypted
secrets — are all things this repo already has, via profiles, `mkHome`, and
ragenix on the same age keys. Adopting it would mean every file under `tools/`
grows a chezmoi-managed twin, or the home-manager modules start reading out of
chezmoi's source directory. Either way there are two sources of truth for the
same file, which is the exact drift `CLAUDE.md` warns about.

`lite.sh` instead consumes the **same** `tools/` tree the Nix modules do. No new
source of truth, no new tool in the chain.

### mise — competes with the weakest part of this script

Harder to dismiss than chezmoi, and worth revisiting rather than settling.

mise overlaps three things the repo already has — tool installation
(home-manager), env management (`direnv`, enabled in `common.nix`) and task
running (`just`) — so as a *whole* it is redundant here for the same reason
chezmoi is. But one slice of it is not: it is a single static binary that
installs pinned tool versions under `~/.local/share/mise` with no root, which is
precisely the `bins` tier's job. And `bins` is the part of this script with a
known defect — a hand-maintained version table that rots, listed under
Known limitations below. `mise use -g …` would delete that table outright.

Reasons it did not win *this* round, none of them decisive:

- **Supply chain.** The pinned-URL table resolves to GitHub release artifacts
  from the projects themselves. mise's registry reaches those too, but several
  of its backends do not — asdf plugins are third-party shell scripts, and the
  cargo backend builds from source, which is a bad trade on a constrained
  remote where the whole point is a prebuilt binary. Evaluating this means
  checking the backend *per tool*, which is real work, not a glance.
- **Another thing to bootstrap.** mise has to be installed before it can
  install anything, so the curl-able entry point does not go away — mise
  replaces the table, not the script.
- **It solves the tier we already got right.** `config` is the tier carrying
  the value, and mise has nothing to say about it.

Worth reopening if the pins rot faster than expected, which is the most likely
way this script gets annoying. Tracked in #99.

### The happy side effect either way

`tools/helix/*.toml` was previously decorative —
`helix.nix` re-encodes those settings in Nix by hand, and
`tools/helix/README.md` describes them as "manually translated". Nothing
actually read the TOMLs. `lite.sh` does, which makes drift between the two
something you notice instead of something you discover months later.

## What it deliberately does not do

Each of these needs Nix or a secret, and faking it would mean inventing a
second copy of something:

- **starship prompt config.** There is no plain-file starship config in the
  repo; `starship.nix` generates it from the `nerd-font-symbols` preset plus
  Nix-level settings. `env.sh` initialises *stock* starship if the binary is
  installed — you get a prompt, not *the* prompt. A checked-in TOML twin would
  be exactly the duplication this script exists to avoid.
- **git identity.** It lives in `secrets/personal/git-config.age`. `bins`
  installs `rage`, so you can decrypt it yourself once the age key is staged,
  but nothing here does it for you.
- **the private agent overlay** (`~/.agents/instructions.private.md`). Same
  reason. The five public layers do get installed.
- **the `~/.claude/settings.json` deep-merge** that `claude-code.nix` performs.
  It needs jq, it mutates a file Claude Code owns at runtime, and its plugin
  half (`tools/agents/plugins/catalog.json`) makes Claude fetch marketplaces on
  next start. Too much side effect for a bootstrap.
- **checksum pinning.** Versions are pinned and the transport is https, but a
  compromised upstream release would not be caught. Known gap.

## Known limitations

- **Linux only**, x86_64 and aarch64. macOS is not a gap — a Mac you can log
  into is a Mac where you can install Nix (#29) or run docker (`docker/dev.sh`).
- **Pinned, not resolved.** The version table is hardcoded rather than read from
  `/releases/latest`, because the GitHub API and the releases redirect are the
  first things an egress proxy blocks — and a bootstrap script that only works
  on an unfiltered network is not a bootstrap script. The cost is that the pins
  rot; `VER_<tool>=…` is the escape hatch.
- **Not a home-manager substitute.** No LSP servers, no rust toolchain, no
  declarative rollback. If you can get Nix on the box, do that instead — try
  `nix-portable` (a single static binary, no root, no `/nix`) and then
  `nix develop github:alycda/dotfiles#tools` for real parity.

## Before you reach for this

Try `nix-portable` first. If it runs on the target, the whole question
dissolves and you get the real environment instead of an approximation of it.
`lite.sh` is what you use when that fails — a hardened sandbox, no user
namespaces, or not enough disk for a Nix store.
