# Flox vs. this Nix setup: an investigation

*Branch: `claude/flox-vs-nix-exploration-5u2tjc` — July 2026*

This branch explores what [Flox](https://flox.dev/) would mean for this
repository: what it replaces, what it can't touch, and what it would add that
the current flake + home-manager + nix-darwin stack doesn't have. The concrete
experiment is `.flox/env/manifest.toml`, a hand-translation of
`devShells.default` from `flake.nix`.

> **Methodology note:** this was researched and authored in a sandboxed
> environment whose network policy blocked `downloads.flox.dev` (and
> `cache.nixos.org`), so the manifest was written from documentation and has
> not been validated by the Flox CLI — there is no `manifest.lock` committed.
> First `flox activate` on a real machine will resolve and lock it.

## 1. What Flox actually is

Flox is three things, and it's worth keeping them separate:

1. **A CLI** (`flox`) that embeds Nix as an implementation detail. You declare
   an environment in TOML (`.flox/env/manifest.toml`) or build it up
   imperatively (`flox init` / `flox install` / `flox activate`) — both paths
   maintain the *same* declarative manifest, so imperative use never forks
   from the declarative artifact. That's the core UX bet: Homebrew-shaped
   commands producing a Nix-shaped reproducible result.
2. **The Flox Catalog** — a hosted resolution service over nixpkgs history
   (~100k packages, multi-year version history). Instead of your flake pinning
   one nixpkgs rev for everything, the catalog resolves each *package group*
   to a nixpkgs revision that satisfies every package and version constraint
   in that group, then writes exact revs/derivations to `manifest.lock`.
3. **FloxHub** — a registry for *environments* (not packages): `flox push`
   an environment, teammates `flox activate -r you/env-name` to get an
   identical setup. Org-scoped sharing and private custom catalogs are the
   paid tier.

Environments are **not containers** — activation is a subshell with
`PATH`/env-var rewiring, so tools run natively on the host (macOS included,
no VM), which is the pitch against dev containers.

### Key manifest sections

| Section | Purpose | Analog in this repo |
|---|---|---|
| `[install]` | packages, with `pkg-path`, `version`, `pkg-group`, `systems`, `priority` | `lib/core-packages.nix`, `home.packages` |
| `[vars]` | static env vars | `home.sessionVariables`, `shellHook` exports |
| `[hook].on-activate` | bash run once at activation (setup, codegen) | `shellHook` in `mkShell` |
| `[profile]` | sourced per-shell (bash/zsh/fish-specific allowed) — aliases, completions | `programs.zsh` init snippets |
| `[services]` | processes started/stopped with the env (`flox activate -s`) | nothing here — closest is `docker/` by hand |
| `[include]` | **composition**: merge other environments' manifests at lock time | module `imports` in home-manager |
| `[options]` | `systems`, `allow.unfree`, etc. | `forAllSystems`, `config.allowUnfree` |

### Locking model (the part worth understanding deeply)

A flake pins **one nixpkgs rev globally**; every package comes from it, and
`nix flake update` moves everything at once. Flox inverts this: each
`pkg-group` in `[install]` is resolved (newest-first) to *some* nixpkgs
revision where all members satisfy their version constraints — different
groups may lock to different revs, and `flox upgrade` advances a group
atomically. That's how they offer "install postgres 15 and node 22" without
you hunting for a nixpkgs commit that has both. Tradeoff: resolution depends
on their hosted catalog service, not on a local evaluation of a flake input
you control. The escape hatch for arbitrary packages is [Nix expression
builds](https://flox.dev/docs/concepts/nix-expression-builds/) and
[flake installs](https://flox.dev/blog/extending-flox-with-nix-flakes/)
(`flox install github:owner/repo#pkg` works, with reduced
reproducibility guarantees).

## 2. Mapping this repository onto Flox

| This repo | Flox equivalent | Fit |
|---|---|---|
| `devShells.default` + `lib/core-packages.nix` | `.flox/env/manifest.toml` `[install]` | **Clean.** See the manifest on this branch — it's shorter and needs no `forAllSystems`, no `symlinkJoin`/`wrapProgram`. |
| `devShells.tools` (cheat + wrapped config) | `[hook].on-activate` generating config into `$FLOX_ENV_CACHE` | **Clean-ish.** No wrapper mechanism, but env-var + hook achieves the same; `tools/` plaintext philosophy actually fits Flox *better* than `pkgs.writeText`. |
| `direnv` + `nix-direnv` | `flox activate` (direnv integration exists, or just call it from `.envrc`) | Clean. |
| `homeConfigurations` per machine (`mkHome`) | The **default environment** (`~/.flox`) + named environments on FloxHub (`flox push` / `flox activate -r alycda/core`) | **Partial.** Covers the *package* half. FloxHub sync replaces "clone dotfiles, run home-manager switch" for tools — arguably nicer for the multi-machine story (ditto / home / code / devcontainers). |
| `home-manager/modules/*` (git.nix, helix.nix, gh-dash, vscode profiles…) | **Nothing.** | **Gap.** Flox manages packages + env vars + hooks, not dotfiles. `programs.git`, helix config, VS Code profiles, symlinked tool content — all stay home-manager (or go back to hand-managed dotfiles). |
| `darwin/` (system defaults, homebrew casks) | **Nothing.** | **Gap.** Flox explicitly doesn't do system config. nix-darwin stays. |
| Flake inputs as overlays (`claude-code-nix`, `nix-vscode-extensions`) | No overlay concept; nixpkgs-only catalog + flake-install escape hatch | **Gap.** Fresh-`claude-code`-via-overlay has no idiomatic Flox translation; you'd take catalog freshness or publish your own package to a private catalog (paid for org sharing). |
| `ragenix` / agenix secrets | **Nothing** built in | **Gap.** Keep `rage` + `nix run github:yaxitech/ragenix`. |
| `justfile` | Unchanged (`just` is in the manifest); `[profile]` could add aliases | Neutral. |
| CI (`nix flake check`, statix, deadnix) | `flox activate -- cmd` in CI; no eval-time type check of the manifest beyond TOML/lock validation | **Regression** in checkability: a flake eval catches config errors across all systems; a TOML manifest is much less checkable — but there's also far less to check. |

## 3. What Flox would add that this setup lacks

- **Services** (`[services]`, `flox activate -s`): declarative
  start-with-the-shell processes (postgres, redis). The current repo has no
  story for this at all.
- **Layering and composition**: `flox activate` inside an active environment
  stacks them (runtime layering); `[include]` merges manifests with conflicts
  surfaced at lock time (build-time composition, Flox ≥ 1.4). This is
  genuinely the home-manager-modules idea (`common.nix` + profile imports)
  reinvented for environments — `envs/core` + `envs/rust` + `envs/nix-lang`
  composed per project would map this repo's module tree almost 1:1.
- **FloxHub push/pull**: environments as shareable, versioned artifacts with
  generations — no repo clone + toolchain bootstrap needed on a new machine
  (`flox activate -r ...` and trust it).
- **`flox containerize`**: OCI image straight from the environment — would
  replace most of the hand-rolled `Dockerfile` + `docker/` entrypoint for the
  2012-MBP x86 image.
- **`flox build` / `flox publish`**: package your own software (or repackage
  flake-only tools like ragenix) into a private catalog, consumed by the same
  `flox install`.
- **A gentler on-ramp for collaborators**: contributors touch TOML and
  ordinary bash, never the Nix language. For a solo learning-journey repo
  that's a *loss* as much as a win — this repo exists partly to learn Nix.

## 4. Sharp edges found in community discussion

- Resolution depends on Flox's hosted catalog; cached installs mean
  [trusting their binary cache/infra](https://news.ycombinator.com/item?id=39693446),
  and some report friction installing Flox alongside an existing Nix
  ([HN thread](https://news.ycombinator.com/item?id=41943299)).
- Org features (shared private catalogs) are paid — fine for work, awkward
  for personal multi-machine sync beyond what free FloxHub covers.
- Default-environment adoption wants a line in your shell rc; home-manager
  currently owns `.zshrc` generation here, so the two must be sequenced
  deliberately (community threads:
  [home-manager integration](https://discourse.flox.dev/t/integration-of-flox-with-home-manager/888),
  [relation to home-manager](https://discourse.flox.dev/t/what-is-will-be-relation-of-flox-to-home-manager/808)).
- Remote environments require explicit trust (`flox activate -r` prompts;
  `--trust` to bypass) since hooks run arbitrary code.

## 5. Verdict

**Flox is a package/environment layer, not a configuration layer.** For this
repo it could cleanly replace: `devShells.*`, `lib/core-packages.nix`, the
`forAllSystems` boilerplate, and plausibly the whole `Dockerfile` via
`containerize` — while adding services, composition, and multi-machine
environment sync that don't exist today. It cannot replace: home-manager's
dotfile/program management, nix-darwin, overlays, or agenix. The two stacks
coexist naturally: **Flox for what's installed, home-manager for how it's
configured** — with `lib/core-packages.nix`'s job (one source of truth for
tools everywhere) moving into a composed set of Flox environments.

The philosophical difference to be able to articulate: nix flakes treat *one
pinned world* as the unit of reproducibility; Flox treats *the environment*
as the unit and lets a service resolve per-group worlds behind a lockfile.
That's a real architectural divergence, not just UX sugar over `nix develop`.

## Sources

- [Flox docs: environments](https://flox.dev/docs/concepts/environments) · [creating environments](https://flox.dev/docs/tutorials/creating-environments) · [default environment](https://flox.dev/docs/tutorials/default-environment/) · [package groups](https://flox.dev/docs/concepts/package-groups) · [catalog](https://flox.dev/docs/concepts/packages-and-catalog) · [build & publish](https://flox.dev/docs/tutorials/build-and-publish/) · [sharing](https://flox.dev/docs/tutorials/sharing-environments) · [`flox activate` reference](https://flox.dev/docs/reference/command-reference/flox-activate/)
- [Extending Flox with Nix flakes](https://flox.dev/blog/extending-flox-with-nix-flakes/) · [Flox 1.3 services](https://flox.dev/blog/flox-1.3-simplified-service-management-with-flox/) · [layering vs composition](https://flox.dev/blog/layering-and-composing-flox-environments/) · [build/publish announcement](https://flox.dev/blog/introducing-flox-build-and-publish/)
- [Composition deep-dive (Flox engineer's blog)](https://tinkering.xyz/flox-composition/) · [Flox 1.0 launch retrospective](https://tinkering.xyz/releasing-flox/)
- [The Register on Flox 1.0](https://www.theregister.com/2024/03/23/flox_1_nix/) · [HN: Flox vs plain nix develop](https://news.ycombinator.com/item?id=39693446) · [HN: Flox vs dev containers](https://news.ycombinator.com/item?id=41943299) · [Why you should flox every day](https://etorreborre.blog/why-you-should-flox-every-day)
