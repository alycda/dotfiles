# Devcontainer CI: what it can grow into

- STATUS: OPEN
- TAGS: ci, devcontainer

## Description

`.github/workflows/devcontainer.yml` checks the Nix devcontainer in three jobs:
config (strict parse, CLI read, `outdated`), build (frozen lock file, then
`jj` and `nix` must run) and a manual-only prebuild to GHCR. Where it can go
from there, roughly in order of payoff:

- **Both containers.** Once the mise devcontainer
  (`.devcontainer/mise/devcontainer.json`) is in this line's history, make
  the build job a matrix over both configs.
- **Parity as a check.** After the Nix container switches to the
  home-manager profile on create, run the mise container's checks in the
  smoke test on both: zsh `..`, `jj config get revsets.fix`, `cheat -l`, the
  shared git config. "The two containers match" then becomes something CI
  proves, not something checked by hand.
- **Dependabot for features.** Dependabot understands devcontainer
  features: a `dependabot.yml` entry opens a PR when the Nix feature releases
  a new version, where `outdated` only prints it.
- **Codespaces prebuilds.** GitHub's native equivalent of the prebuild job,
  configured in the repository settings, not in YAML. Compare with the GHCR
  image before choosing.
- **Architectures.** The prebuild builds only for x86_64, the runner's
  architecture. The Macs are arm64, so they won't use the image without a
  multi-arch build (buildx, or an arm64 runner).
- **Automatic prebuilds.** The prebuild runs only by hand. Once the image is
  used, run it on pushes to develop, and point the config at it (`cacheFrom`
  or the image itself) so opening the container pulls instead of building.
