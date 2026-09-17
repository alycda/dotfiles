#!/usr/bin/env bash
# Force full evaluation of the flake outputs `nix flake check` skips as
# unknown output types (darwinConfigurations, homeConfigurations) — without
# this, CI only exercises the devShells and a broken config surfaces at
# darwin-rebuild/home-manager switch time on a real machine. Evaluating each
# configuration's top-level derivation path catches removed options, bad
# module arguments, and eval errors; nothing is built (the aarch64-darwin
# closures couldn't be built on a Linux runner anyway). Each configuration
# gets its own nix invocation so a failure names the config and eval memory
# stays bounded per config.
set -euo pipefail

for name in $(nix eval --json .#darwinConfigurations --apply builtins.attrNames | jq -r '.[]'); do
  echo "→ darwinConfigurations.${name}"
  nix eval --raw ".#darwinConfigurations.\"${name}\".system.drvPath"
  echo
done

for name in $(nix eval --json .#homeConfigurations --apply builtins.attrNames | jq -r '.[]'); do
  echo "→ homeConfigurations.${name}"
  nix eval --raw ".#homeConfigurations.\"${name}\".activationPackage.drvPath"
  echo
done
