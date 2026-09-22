# Ghost: Timescale's disposable-Postgres CLI, pointed at our own server on
# venari (tools/venari/README.md, "Ghost") now that the hosted service is
# winding down. Desktop profiles only: the server is reached over an ssh
# tunnel from this machine, and the wrapper reads an agenix secret.
#
# This owns the client side: the CLI from the alycda/ghost fork
# (pkgs.ghost-cli, lib/ghost.nix), the API key from agenix, and the settings
# that make the CLI talk to venari and to nothing else. All of it goes
# through a wrapper rather than a managed ~/.config/ghost/config.yaml. The
# CLI writes that file itself (`ghost config set`, `ghost init`), so it
# stays unmanaged - the runtime-mutable rule - and every setting here is one
# the CLI also reads from the environment as GHOST_<KEY>. A value already in
# the environment wins, so `GHOST_API_URL=... ghost list` against some other
# server still works.
#
# `ghost psql` shells out to psql, so the wrapper brings one along.
{ config, lib, pkgs, ... }:
let
  cli = pkgs.ghost-cli;
  keyFile = config.age.secrets.ghost-api-key.path;
  ghost = pkgs.writeShellApplication {
    name = "ghost";
    runtimeInputs = [ pkgs.postgresql ];
    text = ''
      # The laptop's end of `just ghost-tunnel`: API on 8787; the connection
      # strings the server hands out say 127.0.0.1:15432.
      export GHOST_API_URL="''${GHOST_API_URL:-http://127.0.0.1:8787/v0}"
      export GHOST_ANALYTICS="''${GHOST_ANALYTICS:-false}"
      export GHOST_VERSION_CHECK="''${GHOST_VERSION_CHECK:-false}"
      # No keychain: the key arrives through the environment below, and the
      # keyring would prompt for the login keychain over ssh.
      export GHOST_KEYRING="''${GHOST_KEYRING:-false}"
      # Empty turns the Timescale docs proxy inside `ghost mcp` off. Set-but-
      # empty counts as set only because the fork enables viper's
      # AllowEmptyEnv; upstream would silently fall back to the default URL.
      export GHOST_DOCS_MCP_URL="''${GHOST_DOCS_MCP_URL-}"
      if [ -z "''${GHOST_API_KEY:-}" ] && [ -r ${lib.escapeShellArg keyFile} ]; then
        GHOST_API_KEY="$(cat ${lib.escapeShellArg keyFile})"
        export GHOST_API_KEY
      fi
      exec ${cli}/bin/ghost "$@"
    '';
  };
in
{
  # The wrapper only, not pkgs.ghost-cli as well: both install bin/ghost.
  home.packages = [ ghost ];

  age.secrets.ghost-api-key.file = ../../../secrets/personal/ghost-api-key.age;
}
