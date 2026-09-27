# Devcontainer(s)

- STATUS: CLOSED
- TAGS: devcontainer, nix, mise, vscode, docker, bootstrap

## Description

Reproducibility and testing Nix (and mise) without rebuilding on the live
account while applications and services are running.

## Why multiple?

- **nix** is the default.
- **mise** is the for the account with no Nix and no admin rights.

## Layout

- `.devcontainer.json` (Nix)
- `.devcontainer/mise/devcontainer.json`,
