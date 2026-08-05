# HackMD MCP server (github:yuna0x0/hackmd-mcp) wired into Claude Code.
#
# Imported by hackmd-work.nix and hackmd-personal.nix rather than by a profile
# directly, so the server exists exactly when a HackMD token does — and picks up
# whichever account that profile decrypted, since both write the same env file.
#
# The token never lands in this repo or in ~/.claude.json: the account modules
# decrypt it to ~/.config/hackmd/env (mode 0600) and the launcher below sources
# that file at spawn time. An `env` block in the MCP entry would put the token
# in world-readable plaintext, which is the thing agenix exists to prevent.
#
# Why an activation script and not home.file: Claude Code has no declarative
# user-scope MCP config. ~/.claude/settings.json has no mcpServers key and
# .mcp.json is project-scoped only, so a user-scope server has to live in
# ~/.claude.json — which Claude Code rewrites constantly (history, project
# entries, server approvals). Pointing home.file at it would symlink a
# read-only store path over mutable state and break the app. Converging the one
# key we own with jq is the same idempotent approach claude-code.nix already
# uses for the CLAUDE.md import line.
{ config, lib, pkgs, ... }:
let
  # Pinned deliberately. Bare `npx -y hackmd-mcp` resolves to whatever is newest
  # on the registry at spawn time, so the tool surface could change between two
  # sessions on an unchanged flake — the opposite of what pinning nixpkgs buys.
  version = "1.5.7";

  launcher = pkgs.writeShellApplication {
    name = "hackmd-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      envFile="${config.home.homeDirectory}/.config/hackmd/env"
      if [ ! -r "$envFile" ]; then
        echo "hackmd-mcp: no token at $envFile" >&2
        echo "hackmd-mcp: agenix did not decrypt it — check activation output." >&2
        exit 1
      fi
      # set -a exports every assignment in the env file, which is the whole
      # point: hackmd-mcp reads HACKMD_API_TOKEN from its environment.
      set -a
      # shellcheck disable=SC1090  # runtime path, not resolvable at build time
      . "$envFile"
      set +a
      exec npx -y "hackmd-mcp@${version}" "$@"
    '';
  };

  # Merges our one key into ~/.claude.json without disturbing anything else in
  # it. Written to a temp file and moved into place so an interrupted
  # activation cannot leave Claude Code with a truncated config.
  register = pkgs.writeShellScript "hackmd-mcp-register" ''
    set -eu
    claudeJson="$HOME/.claude.json"
    [ -e "$claudeJson" ] || echo '{}' > "$claudeJson"

    if ! ${pkgs.jq}/bin/jq -e . "$claudeJson" >/dev/null 2>&1; then
      echo "hackmd-mcp: $claudeJson is not valid JSON, leaving it alone." >&2
      exit 0
    fi

    tmp="$(${pkgs.coreutils}/bin/mktemp "$claudeJson.hm-hackmd.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    ${pkgs.jq}/bin/jq --arg cmd "${lib.getExe launcher}" \
      '.mcpServers.hackmd = { type: "stdio", command: $cmd, args: [] }' \
      "$claudeJson" > "$tmp"
    ${pkgs.coreutils}/bin/chmod 600 "$tmp"
    ${pkgs.coreutils}/bin/mv -f "$tmp" "$claudeJson"
    trap - EXIT
  '';
in
{
  home.packages = [ launcher ];

  # entryAfter linkGeneration for the same reason claude-code.nix uses it: only
  # touch Claude Code's config once this generation's files are actually linked.
  home.activation.hackmdMcpServer = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${register}
  '';
}
