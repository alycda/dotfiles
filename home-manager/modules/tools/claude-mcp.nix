# Declaratively-managed MCP servers for Claude Code.
#
# A *connector* is not a CLI wrapped in a skill (the cf-now/s3-now shape) - it
# is a remote streamable-HTTP MCP server Claude Code talks to directly. So this
# module installs no packages at all: no node, no npx, no `mcp-remote` proxy.
# That matters in the container, which has no JS runtime; the native
# `type = "http"` transport needs none.
#
# Two tiers, split by what they cost to verify:
#
#  - cloudflare-docs answers unauthenticated - the only one of the 17
#    *.mcp.cloudflare.com servers that does (verified 2026-08-05; the rest
#    return 401 with `www-authenticate: Bearer realm="OAuth"`). It proves the
#    whole declarative path - nix -> activation -> ~/.claude.json -> a live
#    remote server - with zero credentials.
#
#  - cloudflare-bindings needs a Cloudflare API token. It supersedes the
#    account-level "Cloudflare Developer Platform" connector configured at
#    claude.ai, which points at the retired /sse alias and fails HTTP 405:
#    authenticated fine, then POSTing to a transport that endpoint no longer
#    speaks. That connector reports `Scope: claude.ai config` and lives on the
#    Anthropic account, so no checkout can see it and no `claude mcp`
#    subcommand can edit it. Declaring it here moves it somewhere reviewable.
#
# Why a bearer token rather than OAuth in a container: the blocker is not the
# missing browser - Claude Code prints the URL to open on the host. It is the
# callback. The OAuth redirect targets a localhost port listening *inside* the
# container, so a host browser reaches the host's own localhost unless that
# port is published. Also worth knowing before debugging a silent failure:
# Claude Code used to answer that 401's OAuth advertisement by starting a flow
# and discarding the configured auth header, so token mode never applied at
# all (cloudflare/mcp#95, fixed in 2.1.141).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # agenix's default path for a secret named `cloudflare-api-token`. Named
  # rather than declared through `age.secrets`, deliberately: the ciphertext
  # does not exist yet, and an `age.secrets` entry pointing at a missing file
  # breaks `nix flake check` for every configuration - the exact breakage #79
  # finished undoing. The helper degrades instead, so this module is green
  # today and carrying the secret later becomes an additive commit that
  # changes nothing here.
  tokenFile = "${config.age.secretsDir}/cloudflare-api-token";

  # Emits headers at connect time so the token is read fresh from the agenix
  # runtime dir and never lands in ~/.claude.json. Contract matches the
  # `linear` headersHelper already in service: a JSON object of headers, and
  # `{}` rather than a failure when no token is present - which shows the
  # server as unauthenticated in /mcp instead of erroring at startup. Unlike
  # that one this is a store path, not a per-repo bin/ script, so it resolves
  # with no checkout at any particular location.
  cloudflareHeaders = pkgs.writeShellScript "cloudflare-mcp-headers" ''
    set -euo pipefail
    token="''${CLOUDFLARE_API_TOKEN:-}"
    tokenfile="''${CLOUDFLARE_API_TOKEN_FILE:-${tokenFile}}"
    if [ -z "$token" ] && [ -r "$tokenfile" ]; then
      token=$(tr -d '\n' < "$tokenfile")
    fi
    if [ -z "$token" ]; then
      echo '{}'
      exit 0
    fi
    printf '{"Authorization": "Bearer %s"}\n' "$token"
  '';

  managed.mcpServers = {
    cloudflare-docs = {
      type = "http";
      url = "https://docs.mcp.cloudflare.com/mcp";
    };

    # /mcp, never the /sse alias - see the 405 note above.
    cloudflare-bindings = {
      type = "http";
      url = "https://bindings.mcp.cloudflare.com/mcp";
      headersHelper = "${cloudflareHeaders}";
    };
  };

  # Generated rather than committed as a static JSON file under tools/claude/
  # (the shape settings.json and the plugin catalog use): a headersHelper value
  # must be a *store path*, which a static file cannot express.
  managedJson = pkgs.writeText "claude-mcp-servers.json" (builtins.toJSON managed);
in
{
  # ~/.claude.json is runtime state Claude Code owns and rewrites (~53KB of
  # per-project history on a working container), so home-manager must never
  # link or replace it. Deep-merge one key in instead - the same idiom
  # claudeManagedSettings in ./claude-code.nix uses for settings.json, down to
  # writing a tmp file and mv-ing only on jq success, so a failed merge leaves
  # the original intact rather than truncating it.
  home.activation.claudeManagedMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.claude.json"
    if [ ! -f "$cfg" ]; then
      run sh -c 'echo "{}" > "$1"' _ "$cfg"
    fi
    run sh -c '"$1" -s ".[0] * .[1]" "$2" "$3" > "$2.tmp" && mv "$2.tmp" "$2"' \
      _ "${pkgs.jq}/bin/jq" "$cfg" "${managedJson}"
  '';
}
