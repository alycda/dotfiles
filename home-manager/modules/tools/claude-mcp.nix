# Declaratively-managed MCP servers for Claude Code.
#
# A *connector* is not a CLI wrapped in a skill (the cf-now/s3-now shape) - it
# is a remote streamable-HTTP MCP server Claude Code talks to directly. So this
# module installs no packages at all: no node, no npx, no `mcp-remote` proxy.
# That matters in the container, which has no JS runtime; the native
# `type = "http"` transport needs none.
#
# Only Cloudflare's documentation server is wired here, and deliberately so:
# it is the one Cloudflare MCP server that answers unauthenticated (verified
# 2026-08-05 - every other *.mcp.cloudflare.com/mcp returns 401 with
# `www-authenticate: Bearer realm="OAuth"`). That makes it the whole
# declarative path - nix -> activation -> ~/.claude.json -> a live remote
# server - provable end to end with zero credentials. The account-scoped
# server (https://mcp.cloudflare.com/mcp) needs a Cloudflare API token
# delivered via agenix and a headersHelper, which lands separately once there
# is a token to carry.
#
# Version floor worth knowing before adding the token tier: Claude Code used
# to answer that 401's OAuth advertisement by starting an OAuth flow and
# discarding the configured auth header, so token mode silently never applied
# (cloudflare/mcp#95, fixed in 2.1.141). OAuth is not an option in a headless
# container anyway - there is no browser to complete it - so the token header
# is the only viable path there.
{ lib, pkgs, ... }:
let
  managed.mcpServers = {
    cloudflare-docs = {
      type = "http";
      url = "https://docs.mcp.cloudflare.com/mcp";
    };
  };

  # Generated rather than committed as a static JSON file under tools/claude/
  # (the shape settings.json and the plugin catalog use): the token tier adds a
  # headersHelper whose value must be a *store path*, which a static file
  # cannot express. Generating now costs the same and spares rewriting this
  # into nix later.
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
