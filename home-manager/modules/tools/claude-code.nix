# Claude Code global rules - managed pieces of ~/.claude
# The claude-code package itself is installed in common.nix; this module manages
# config that must exist identically on every machine.
#
# ~/.claude/CLAUDE.md itself stays hand-edited (not yet canonicalized into this
# repo), so managed rules live as separate files under ~/.claude/rules/. That
# directory is user-scope: Claude Code discovers every .md in it and loads it
# into every session on this machine, with no @import line anywhere. Rules that
# should only load for matching files carry `paths:` frontmatter instead.
#
# The agent-instruction layers are a separate mechanism (@import lines in a
# managed block at the top of CLAUDE.md) - see ./agents.nix.
{ config, lib, pkgs, ... }:
{
  home = {
    file = {
      # Canonical source lives in tools/agents/rules (cross-tool, issue #40);
      # this is Claude's mount of it. crush loads the same rule via
      # global_context_paths (see tools/crush.nix).
      ".claude/rules/outbound-comment-gate.md".source =
        ../../../tools/agents/rules/outbound-comment-gate.md;

      # Audit log for which instruction files load, when, and why. Wired to the
      # InstructionsLoaded event by tools/claude/settings.json, which references
      # this path. `executable` because home.file links store copies in 0444 by
      # default and a non-executable hook fails with a shell 127 that Claude
      # Code reports as a non-blocking error - easy to miss.
      ".claude/hooks/log-instructions-loaded.sh" = {
        source = ../../../tools/claude/hooks/log-instructions-loaded.sh;
        executable = true;
      };
    };

    activation = {
      # Managed slices of ~/.claude/settings.json. The file itself is
      # runtime-mutable (Claude Code writes it), so it stays unmanaged and
      # activation deep-merges these fragments in idempotently:
      #  - tools/claude/settings.json - plain managed defaults (e.g.
      #    cleanupPeriodDays, transcript retention extended to 90 days)
      #  - tools/agents/plugins/catalog.json - the issue #40 plugin catalog:
      #    desired plugin state, never a committed ~/.claude/plugins cache.
      #    Claude Code fetches declared marketplaces and installs enabled
      #    plugins itself on next startup.
      #
      # jq's `*` merges objects recursively but *replaces* every non-object,
      # arrays included. So a hook event named in tools/claude/settings.json
      # owns that event outright: anything under the same key in the live file
      # is dropped on activation. Other events are untouched. Declaring a hook
      # here is therefore a claim of ownership, not an addition - which is the
      # behaviour we want for managed config, but means a hook added through
      # the UI under a managed event will not survive.
      claudeManagedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="$HOME/.claude/settings.json"
        run mkdir -p "$HOME/.claude"
        if [ ! -f "$settings" ]; then
          run sh -c 'echo "{}" > "$1"' _ "$settings"
        fi
        run sh -c '"$1" -s ".[0] * .[1] * .[2]" "$2" "$3" "$4" > "$2.tmp" && mv "$2.tmp" "$2"' \
          _ "${pkgs.jq}/bin/jq" "$settings" \
          "${../../../tools/claude/settings.json}" \
          "${../../../tools/agents/plugins/catalog.json}"
      '';

      # Managed slice of ~/.claude.json: user-scope MCP servers, so every
      # project's sessions get Linear without a per-machine `claude mcp add`
      # ritual. Same merge-idempotently pattern as claudeManagedSettings -
      # ~/.claude.json is runtime-mutable state and stays unmanaged as a whole;
      # only the entries named in tools/claude/mcp-servers.jq are owned (see
      # that file for the account choice). The key is read with --rawfile from
      # the agenix-decrypted file, so it never passes through argv or the store;
      # it ends up in ~/.claude.json, where Claude Code keeps MCP credentials
      # anyway. umask 077 because that file now holds a credential: the merged
      # copy is written 0600 rather than inheriting a world-readable 0644.
      #
      # Decryption is done by ragenix's launchd agent, which activation only
      # *installs* (setupLaunchAgents) - on a first-ever switch the decrypted
      # file may not exist yet, and no DAG ordering can wait for it. So: guard
      # on readability and skip with a warning rather than fail; the next
      # switch after the agent has mounted completes the merge.
      claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        claudeJson="$HOME/.claude.json"
        linearKey="${config.age.secrets.linear-api-key-personal.path}"
        if [ -r "$linearKey" ]; then
          if [ ! -f "$claudeJson" ]; then
            run sh -c 'umask 077 && echo "{}" > "$1"' _ "$claudeJson"
          fi
          run sh -c 'umask 077 && "$1" --rawfile lin "$3" -f "$4" "$2" > "$2.tmp" && mv "$2.tmp" "$2"' \
            _ "${pkgs.jq}/bin/jq" "$claudeJson" "$linearKey" \
            "${../../../tools/claude/mcp-servers.jq}"
        else
          echo "claudeMcpServers: $linearKey not decrypted yet, skipping MCP merge (rerun switch)" >&2
        fi
      '';

      # No activation entry appends "@rules/outbound-comment-gate.md" to
      # CLAUDE.md any more. User-level rules in ~/.claude/rules/ load into
      # every session on their own - Claude Code discovers the directory, no
      # import needed - so the appended line loaded the same file a second
      # time. The append predates user-level rules support.
      #
      # The stale line is removed from existing CLAUDE.md files by the sync
      # script in ./agents.nix, which strips it along with the other legacy
      # bare imports.
    };
  };
}
