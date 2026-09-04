---
title: "dotfiles — Index"
tagline: "The Messy Middle, Reproducible"
---

# dotfiles

Configuration, written for the machines that rebuild it (and the person who reads the history)

Flake-based declarative environments: nix-darwin + Home Manager, one `flake.nix` driving a work Mac, personal profiles, and a headless dev container — reproducible from zero. This repository documents a learning journey with Nix, not just a final configuration.

## Thesis

Most dotfiles show you the destination. This repo keeps the journey: every wrong turn committed, every fix documented, every state rebuildable.

### Axiom i — The commit is the unit.

The history is the artifact. Incremental, meaningful commits over squashes — a commit that explains *why* teaches more than a diff that shows *what*. Jujutsu (`jj`) makes history something you shape deliberately, not something that happens to you.

### Axiom ii — Declared beats installed.

If it isn't in the flake, it doesn't exist. One shared package list feeds both the ephemeral `nix develop` shell and the persistent home environment, so a throwaway sandbox and a switched profile behave identically. New machine, new container: same environment, from zero.

### Axiom iii — The messy middle is the content.

The axiom this repo exists to prove. Nothing is wasted when you document it: [`docs/solutions/`](https://github.com/alycda/dotfiles/tree/main/docs/solutions) holds the write-up for every package collision, lint trap, and activation failure — each hit once, documented once, never re-debugged.

## Inside

Four things, all live:

- **One flake, every machine** — nix-darwin system config plus Home Manager profiles for work, home, and code contexts, composed from small focused modules. [flake.nix](https://github.com/alycda/dotfiles/blob/main/flake.nix)
- **A multi-arch dev container** — x86_64 + arm64 image with the home-manager generation baked in; the entrypoint reconciles the baked generation against a persistent home volume on every start. [Dockerfile](https://github.com/alycda/dotfiles/blob/main/Dockerfile)
- **Declarative agent tooling** — Claude Code rules, an agent-instruction overlay, and skills.sh skills pinned through nix-skills — reading per-letter index shards instead of forcing a 48MB overlay evaluation. [lib/skills-sh.nix](https://github.com/alycda/dotfiles/blob/main/lib/skills-sh.nix)
- **A knowledge store** — [`docs/solutions/`](https://github.com/alycda/dotfiles/tree/main/docs/solutions) for documented failures with structured frontmatter, [`CONCEPTS.md`](https://github.com/alycda/dotfiles/blob/main/CONCEPTS.md) for shared domain vocabulary. The part the agents read first.

## Reading order

For humans and agents alike: [README](https://github.com/alycda/dotfiles/blob/main/README.md) for the map, [CLAUDE.md](https://github.com/alycda/dotfiles/blob/main/CLAUDE.md) for the conventions, [CONCEPTS.md](https://github.com/alycda/dotfiles/blob/main/CONCEPTS.md) for the vocabulary, [docs/solutions/](https://github.com/alycda/dotfiles/tree/main/docs/solutions) for the scars.

## Colophon

This was supposed to be a weekend of configuration. It became a curriculum. The bee shouldn't fly, and does.

— Alyssa Evans

## Contact

alyda@me.com · https://github.com/alycda/dotfiles · Los Angeles, CA
