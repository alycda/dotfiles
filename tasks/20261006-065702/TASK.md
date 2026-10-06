# Nix binary cache (Cachix or similar) once the flake builds from source

- STATUS: OPEN
- TAGS: nix, ci, cache, deferred

## Description

Not needed yet. At 0.1.4 the flake's only output is a dev shell with `jj`
and `just` from nixos-unstable, and every path in it is prebuilt on
cache.nixos.org, which keeps everything. CI's `nix develop` only downloads,
so a second cache would hold the same paths again. The slow parts of CI are
installing Nix and starting the devcontainer, which a binary cache doesn't
help.

Revisit when any of these happens:

- **The flake builds something from source**: a custom derivation, an
  overlay that changes a package version, or a pinned input outside
  nixpkgs. main had several, which the parity decisions would bring over:
  `envelope` (`buildRustPackage`), hackmd-cli packaging, crush from Charm's
  repo (D10), the claude-code-nix input (D11), and venari. Each would
  compile on every runner of `nix.yml`'s `shell` matrix (three systems) and
  again on each Mac.
- **CI logs show `building '/nix/store/…drv'`** instead of
  `copying path … from 'https://cache.nixos.org'`. That's the direct measure;
  check `nix.yml`'s logs once it runs on GitHub.
- **Two machines build the same closure**: shesfast and ditto both building
  a darwin or home-manager configuration with custom packages in it.

The options when it's time:

- **Cachix.** The free tier is a public cache. That's fine for builds of
  public sources, and agenix secrets stay encrypted either way, but anything
  built from private inputs would be readable; a private cache is paid.
  Pushing needs a `CACHIX_AUTH_TOKEN` repository secret: a credential for an
  outside service, to rotate.
- **`nix-community/cache-nix-action`**: the Nix store in GitHub's Actions
  cache, with no account. Per repo, and evicted after 7 days unused: enough
  for CI, no help to the Macs.
- **DeterminateSystems' magic-nix-cache**: check its current status first.
  It's unconfirmed whether its free GitHub Actions backend still works.
- For the devcontainer, publishing prebuilt images to GHCR (develop's
  `prebuild` job, left out of `devcontainer.yml`) would do more than any Nix
  cache, since the image already holds the dev shell.

## Open questions

- Public Cachix, a private cache, or CI-only caching? It depends on whether
  anything private gets built. Assumed until then: nothing, so no cache.
- Publish devcontainer images to GHCR? Undecided. It's tracked here
  because it competes with a Nix cache for the same goal.

## Verification

Nothing to verify until a cache is added. When one is:

- A `nix.yml` run after a warm-up shows `copying path … from` the new cache
  for the source-built paths, not `building`.
- The `shell` jobs' durations, before and after, on all three runners.
- On a Mac, `nix develop` (or a darwin switch) fetches those paths from the
  cache instead of building them.
