# hackmd-cli - HackMD notes/folders/teams from the command line.
#
# Replaces the hackmd MCP server in the agent roster. An MCP server spends
# context on tool schemas in every request whether or not the session touches
# HackMD; a CLI plus the skill that documents it (tools/agents/skills/hackmd-cli,
# upstream's own, wired in by ./agent-skills.nix) costs nothing until an agent
# reaches for it, and is equally usable from a plain shell. See work.just's
# chat-casper recipe for what the MCP roster's schema weight was doing to local
# models.
#
# Not in nixpkgs (searched nixos-unstable: no hackmd attribute at all), so it is
# packaged here from the published npm tarball.
#
# WHY importNpmLock RATHER THAN buildNpmPackage's usual fetchNpmDeps: the latter
# needs an `npmDepsHash` of the whole dependency FOD, which can only be obtained
# by running a build and reading the mismatch error. importNpmLock instead
# fetches every dependency by the integrity hash already recorded in
# package-lock.json, so the pin is the lockfile and there is no second hash to
# keep in sync. `nix flake update` never touches it either - the version moves
# only when tools/hackmd/package-lock.json is regenerated on purpose.
#
# tools/hackmd/ is a pin-only package: its single dependency is the published
# @hackmd/hackmd-cli, so upstream stays the source of truth for the rest of the
# tree. To bump:
#
#   cd tools/hackmd
#   $EDITOR package.json          # version + the @hackmd/hackmd-cli pin
#   rm package-lock.json && npm install --package-lock-only
#   # then re-vendor the skill from the matching upstream tag:
#   #   unzip -o hackmd-cli.skill -d /tmp/hmd  (from hackmdio/hackmd-cli)
#   #   cp /tmp/hmd/hackmd-cli/SKILL.md tools/agents/skills/hackmd-cli/
#
# THE TWO OVERRIDES IN package.json ARE LOAD-BEARING, NOT GOLD-PLATING. Left
# alone, `npm install @hackmd/hackmd-cli` resolves 770 packages / 263MB:
#
#  - `oclif` (the oclif *publisher* CLI - yeoman generators, aws-sdk v2, the
#    lot) is declared as a runtime dependency upstream but nothing in the
#    shipped code requires it: bin/run requires only @oclif/core, and lib/*.js
#    requires @hackmd/api, @oclif/core, cli-ux, fs-extra, lodash.defaults and
#    tslib. Aliasing the edge to @oclif/core (a package already in the tree, so
#    the alias costs nothing) satisfies the dependency and drops 589 packages.
#    Verified: --version, --help and command dispatch are identical with it
#    gone. An alias rather than a deletion on purpose - if some path ever does
#    `require('oclif')` it gets a real module instead of MODULE_NOT_FOUND.
#  - typescript floats to 7.x, whose native rewrite ships its compiler as 20
#    per-platform binary packages. importNpmLock fetches every entry in the
#    lock, not just the ones matching the build platform, so all 20 would be
#    downloaded on every machine to install none of them. Pinning to 5.9.3
#    keeps typescript a single pure-JS package. It is only present at all as an
#    optional peer of ts-node, which @oclif/core loads inside a try/catch for
#    `bin/dev`; the shipped `bin/run` never reaches it.
#
# Result: 161 packages / 50MB. That still rides in common.nix (and so into the
# devcontainer image), which is why the 263MB version was not acceptable - see
# CLAUDE.md on the 2012 MBP overflowing Docker's disk mid-build.
{ lib, pkgs, ... }:
let
  version = "2.5.1";

  # $out/node_modules, built by `npm install --ignore-scripts` against a
  # package-lock.json whose every `resolved` has been rewritten to a store path.
  nodeModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ../../../tools/hackmd;
    inherit (pkgs) nodejs;
  };

  # bin/run is `#!/usr/bin/env node` + `require('@oclif/core').run()`, and oclif
  # roots its command lookup at the script's own directory - so the wrapper has
  # to point node at the script *in place* under node_modules rather than copy
  # it somewhere tidier. pkgs.nodejs is nodejs_24 at the pinned nixpkgs, which
  # is what hackmd-cli's `engines: { node: ">=24.0.0" }` wants.
  hackmd-cli =
    pkgs.runCommand "hackmd-cli-${version}"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta = {
          description = "Command-line interface for HackMD notes, folders, and teams";
          homepage = "https://github.com/hackmdio/hackmd-cli";
          license = lib.licenses.mit;
          mainProgram = "hackmd-cli";
        };
      }
      ''
        makeWrapper ${pkgs.nodejs}/bin/node "$out/bin/hackmd-cli" \
          --add-flags "${nodeModules}/node_modules/@hackmd/hackmd-cli/bin/run"
      '';
in
{
  # Auth is deliberately NOT managed here. `hackmd-cli login` writes
  # ~/.hackmd/config.json, and HMD_API_ACCESS_TOKEN overrides it - either way
  # the token is a runtime credential, not a generation input. If it should
  # travel with the machine it belongs in secrets/ as an agenix secret, the way
  # the Linear key does in ./agents.nix.
  home.packages = [ hackmd-cli ];
}
