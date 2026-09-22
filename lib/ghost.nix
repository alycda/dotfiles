# The Ghost CLI and server from the alycda/ghost fork, as an overlay. Ghost was
# Timescale's disposable-Postgres-for-agents service; it is winding down, so
# the fork adds a server for its OpenAPI contract and the one field the CLI
# needed to use it. venari runs the server (tools/venari/README.md, "Ghost");
# home-manager/modules/tools/ghost.nix puts the client on PATH.
#
# Why not upstream's release binary or nixpkgs: nixpkgs has no ghost, and the
# upstream binary is the hosted service's client - it connects every database
# to a Postgres database called "tsdb", which is true only when each has an
# instance to itself. The fork's `dbname` field is what makes one cluster
# work, so the CLI has to come from the fork. The fork has no releases;
# `flake.lock` is the pin and `nix flake update ghost` the bump. buildGoModule
# compiles from source, once per machine, cached like anything else.
#
# Bumping: vendorHash changes only when go.mod/go.sum do. If a bump fails on
# it, copy the "got:" hash from the error - that is the whole procedure.
#
# Bound to pkgs.ghost-cli, not `ghost`: the wrapper module owns the `ghost`
# name on PATH, and installing both would collide on bin/ghost.
ghostSrc: final: _:
let
  rev = ghostSrc.shortRev or "dirty";
in
{
  ghost-cli = final.buildGoModule {
    pname = "ghost-cli";
    version = "0.27.1-fork-${rev}";
    src = ghostSrc;
    vendorHash = "sha256-meVGmjgo75xPsXlQmyc2v7CVZruS41UH6g6aKYykKxg=";
    subPackages = [ "cmd/ghost" "cmd/ghost-server" ];
    ldflags = [
      "-s"
      "-w"
      "-X github.com/timescale/ghost/internal/config.Version=v0.27.1-fork-${rev}"
    ];
    # The fork's own CI runs the suite (CLI commands against mocks, ~15s); the
    # server's lifecycle test skips without a cluster to point it at.
    doCheck = false;
    meta = {
      description = "Ghost CLI and self-hosted server (alycda fork of timescale/ghost)";
      homepage = "https://github.com/alycda/ghost";
      license = final.lib.licenses.asl20;
      mainProgram = "ghost";
    };
  };
}
