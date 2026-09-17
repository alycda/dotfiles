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
# The API token comes from agenix, selected per profile with
# `hackmd.account = "personal" | "work"` (the option is at the bottom of this
# file). Both ciphertexts and the secrets.nix declarations were taken from
# PR #59, which this one supersedes: #59 wired the same secrets to a HackMD MCP
# server, and the secrets are the half of it worth keeping.
#
# To validate in the devcontainer, which is the profile carrying the personal
# account:
#
#   docker build -t dev .
#   docker run -it --rm -v devhome:/root -v "$PWD":/work -w /work dev
#   # if activation complains about age/agenix, the identity is missing:
#   #   docker cp ~/.age/personal-key.txt <container>:/root/.age/personal-key.txt
#   # ...and make sure that file ends in a newline - see
#   #   docs/solutions/runtime-errors/
#   #     ragenix-edit-fails-on-identity-without-trailing-newline.md
#   ls -l ~/.local/share/agenix/hackmd-api-token   # the token should be here
#   hackmd-cli whoami        # should name the account, not prompt or hang
#   hackmd-cli teams
#
# That container only decrypts anything because dev.nix also imports
# ../agenix-activation.nix, carried onto this branch for exactly this reason:
# ragenix's home-manager module installs secrets from a systemd user service and
# adds no activation step, and the container has no user systemd. Without it
# `hackmd.account` is a no-op there and the guard below reports a missing token
# while the identity is sitting in place - a misdiagnosis worth avoiding.
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
#   #  ^ --package-lock-only matters: a plain `npm install` here leaves ~50MB
#   #    of node_modules in the repo. .gitignore and .dockerignore both cover
#   #    it, but nothing reads it, so delete it rather than leave it lying.
#   # then re-vendor the skill from the matching upstream tag:
#   #   unzip -o hackmd-cli.skill -d /tmp/hmd  (from hackmdio/hackmd-cli)
#   #   cp /tmp/hmd/hackmd-cli/SKILL.md tools/agents/skills/hackmd-cli/
#   #   ...then re-apply the two `LOCAL EDIT (dotfiles)` blocks it just
#   #   overwrote - see ./agent-skills.nix for why they exist.
#
# The version is read from the lockfile (below), so there is nothing else to
# bump by hand.
#
# THE TWO OVERRIDES IN package.json ARE LOAD-BEARING, NOT GOLD-PLATING. Left
# alone, `npm install @hackmd/hackmd-cli` resolves 770 packages / 263MB:
#
#  - `oclif` (the oclif *publisher* CLI - yeoman generators, aws-sdk v2, the
#    lot) is declared as a runtime dependency upstream but nothing in the
#    shipped code requires it: bin/run requires only @oclif/core, and lib/*.js
#    requires @hackmd/api, @oclif/core, cli-ux, fs-extra, lodash.defaults and
#    tslib. Aliasing the edge to @oclif/core satisfies the dependency and drops
#    589 packages. Verified: --version, --help and command dispatch are
#    identical with it gone. An alias rather than a deletion on purpose - if
#    some path ever does `require('oclif')` it gets a real module instead of
#    MODULE_NOT_FOUND. npm does not dedupe the alias against the real
#    @oclif/core, so node_modules/oclif is a second full copy of it (with its
#    own nested fs-extra/jsonfile/universalify): ~1.1MB, paid knowingly against
#    the 213MB the override saves.
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
{ config, lib, pkgs, ... }:
let
  cfg = config.hackmd;

  # Where agenix writes the token and the wrapper reads it. `path` is left
  # unoverridden below - agenix's default is `${age.secretsDir}/${name}`, the
  # same convention the Linear key relies on in ./agents.nix - and read back
  # from the option here, so the two can never drift even if a `path` is added
  # later. Profiles with no account define no secret, so that branch spells the
  # default out; nothing decrypts there, and the guard only quotes the path to
  # say what is missing.
  tokenPath =
    if cfg.account == null then
      "${config.age.secretsDir}/hackmd-api-token"
    else
      config.age.secrets.hackmd-api-token.path;

  lock = lib.importJSON ../../../tools/hackmd/package-lock.json;

  # Read the version out of the pin rather than restating it. A second copy is
  # a copy that can disagree: the bump procedure above regenerates the lock,
  # and a hand-maintained literal here would silently label the store path with
  # whatever version was current the last time someone remembered this line.
  version = lock.packages."node_modules/@hackmd/hackmd-cli".version;

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
  #
  # A shell wrapper rather than a bare makeWrapper because there is a guard to
  # run first - see tools/hackmd/token-guard.sh for what hangs without it.
  # node is called by absolute store path so nothing on PATH can shadow it.
  hackmd-cli = pkgs.writeShellApplication {
    name = "hackmd-cli";
    meta = {
      description = "Command-line interface for HackMD notes, folders, and teams";
      homepage = "https://github.com/hackmdio/hackmd-cli";
      license = lib.licenses.mit;
      mainProgram = "hackmd-cli";
    };
    text = ''
      # hackmd-cli ${version}
      hackmd_token_file=${lib.escapeShellArg tokenPath}
      ${builtins.readFile ../../../tools/hackmd/token-guard.sh}
      exec ${pkgs.nodejs}/bin/node \
        "${nodeModules}/node_modules/@hackmd/hackmd-cli/bin/run" "$@"
    '';
  };
in
{
  # Which HackMD account this machine talks to. Null (the default) still
  # installs the CLI - `hackmd-cli login` or HMD_API_ACCESS_TOKEN then work as
  # upstream intends - it only declines to carry a token.
  #
  # An enum rather than two importable modules (which is how PR #59 shaped it):
  # the accounts are mutually exclusive because they share one secret name and
  # one decrypt path, and an enum makes picking both unrepresentable instead of
  # something a comment has to warn against.
  options.hackmd.account = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [
      "personal"
      "work"
    ]);
    default = null;
    example = "personal";
    description = ''
      Which HackMD account's API token to decrypt for `hackmd-cli`, selecting
      `secrets/<account>/hackmd-api-token.age`. When null no token is carried
      and the CLI falls back to its own `login` / `HMD_API_ACCESS_TOKEN`.
    '';
  };

  config = {
    home.packages = [ hackmd-cli ];

    # The token arrives with the generation, so a fresh container has a working
    # hackmd-cli without a paste-the-token ritual - the same reasoning that puts
    # the Linear key in ./agents.nix. It is never exported into the shell
    # environment: the wrapper reads this file at call time (see
    # tools/hackmd/token-guard.sh).
    #
    # No `mode` override (#59 set 0600): agenix's 0400 default is already
    # owner-read-only, and read is all the wrapper needs.
    #
    # This adds a secret to a decrypt step every profile already runs for
    # git.nix's git-config, so it introduces no new way for activation to fail -
    # a missing identity was already going to be reported there first.
    age.secrets = lib.mkIf (cfg.account != null) {
      hackmd-api-token.file = ../../../secrets + "/${cfg.account}/hackmd-api-token.age";
    };
  };
}
