# Claude Code global rules - managed pieces of ~/.claude
# The claude-code package itself is installed in common.nix; this module manages
# config that must exist identically on every machine.
#
# ~/.claude/CLAUDE.md itself stays hand-edited (not yet canonicalized into this
# repo), so managed rules live as separate files under ~/.claude/rules/ and are
# pulled in via CLAUDE.md's @import syntax. The activation script idempotently
# ensures the import lines exist.
{ config, lib, pkgs, ... }:
{
  home = {
    file = {
      ".claude/rules/outbound-comment-gate.md".source =
        ../../../tools/claude/rules/outbound-comment-gate.md;
      ".claude/rules/docs-to-hackmd.md".source =
        ../../../tools/claude/rules/docs-to-hackmd.md;
    };

    activation = {
      # Managed slices of ~/.claude/settings.json. The file itself is
      # runtime-mutable (Claude Code writes it), so it stays unmanaged and
      # activation deep-merges these fragments in idempotently:
      #  - tools/claude/settings.json - plain managed defaults (cleanup
      #    retention; the skillOverrides that demotes ce-proof so agent doc
      #    publishing lands in HackMD - see rules/docs-to-hackmd.md)
      #  - tools/agents/plugins/catalog.json - the issue #40 plugin catalog:
      #    desired plugin state, never a committed ~/.claude/plugins cache.
      #    Claude Code fetches declared marketplaces and installs enabled
      #    plugins itself on next startup.
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
      # project's sessions get linear + hackmd without a per-machine
      # `claude mcp add` ritual. Same merge-idempotently pattern as
      # claudeManagedSettings - ~/.claude.json is runtime-mutable state and
      # stays unmanaged as a whole; only .mcpServers.{linear,hackmd} are owned
      # (see tools/claude/mcp-servers.jq for the entries and the account
      # choice). Secrets are read from the agenix-decrypted files at
      # activation time: they end up in ~/.claude.json (local, untracked -
      # where Claude Code keeps MCP credentials anyway), never in the store.
      #
      # Decryption is done by ragenix's launchd agent, which activation only
      # *installs* (setupLaunchAgents) - on a first-ever switch the decrypted
      # files may not exist yet, and no DAG ordering can wait for them. So:
      # guard on readability and skip with a warning rather than fail; the
      # next switch (or rerun) after the agent has mounted completes the merge.
      claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        claudeJson="$HOME/.claude.json"
        linearKey="${config.age.secrets.linear-api-key-personal.path}"
        hackmdToken="${config.age.secrets.hackmd-api-token.path}"
        if [ -r "$linearKey" ] && [ -r "$hackmdToken" ]; then
          if [ ! -f "$claudeJson" ]; then
            run sh -c 'echo "{}" > "$1"' _ "$claudeJson"
          fi
          run sh -c '"$1" --arg lin "$(cat "$3")" --arg hmd "$(cat "$4")" -f "$5" "$2" > "$2.tmp" && mv "$2.tmp" "$2"' \
            _ "${pkgs.jq}/bin/jq" "$claudeJson" "$linearKey" "$hackmdToken" \
            "${../../../tools/claude/mcp-servers.jq}"
        else
          echo "claudeMcpServers: agenix secrets not decrypted yet, skipping MCP merge (rerun switch)" >&2
        fi
      '';

      # entryAfter linkGeneration (not just writeBoundary): the import lines
      # must only be appended once the rule files they point at have actually
      # been linked - otherwise a failure later in activation leaves CLAUDE.md
      # importing files that don't exist (observed on the dotfiles-ci VM,
      # 2026-07-02).
      claudeRuleImports = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        claudeMd="$HOME/.claude/CLAUDE.md"
        run mkdir -p "$HOME/.claude"
        for importLine in \
          "@rules/outbound-comment-gate.md" \
          "@rules/docs-to-hackmd.md"; do
          if [ ! -f "$claudeMd" ] || ! grep -qxF "$importLine" "$claudeMd"; then
            run sh -c 'printf "\n%s\n" "$1" >> "$2"' _ "$importLine" "$claudeMd"
          fi
        done
      '';
    };
  };

  # Token for the hackmd MCP server above. Defined next to its consumer; the
  # linear keys stay grouped in ../agents.nix with the rest of the agent
  # secrets. No `path` override: the default agenix dir is where
  # claudeMcpServers reads it via config.age.secrets.
  age.secrets.hackmd-api-token.file = ../../../secrets/personal/hackmd-api-token.age;
}
