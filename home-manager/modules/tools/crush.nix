# Crush (charmbracelet) declarative config slice.
#
# Providers/models stay in the hand-managed ~/.config/crush/crushrc (its
# api-key lines reference $VARs, never literals). This module owns the JSON
# sibling: crush merges crush.json and crushrc from the same directory
# (verified in crush 0.88.1 load.go; crushrc wins on key conflicts and crush
# warns), so the two files compose instead of fighting - as long as the
# crushrc never sets the keys owned here (options, hooks, lsp).
#
# global_context_paths is crush's key for ABSOLUTE, always-loaded context
# files (plain context_paths entries are project-relative names). Setting it
# replaces the two built-in defaults (~/.config/crush/CRUSH.md and
# ~/.config/AGENTS.md), so those are listed explicitly to keep them live.
# This loads the cross-tool outbound-comment gate from ~/.agents/rules,
# giving crush the same posture Claude Code gets via CLAUDE.md's
# @rules/outbound-comment-gate.md import.
#
# The gate is enforced mechanically too: a PreToolUse hook (tools/crush/
# outbound-gate.sh) blocks outbound-posting tool calls (exit 2) unless a
# one-shot exact-payload approval exists. Deliberateness, not enforcement:
# approve mode is agent-invocable by design; any edit to body or
# destination re-triggers the gate.
{ config, lib, pkgs, ... }:
let
  hookPath = "${config.xdg.configHome}/crush/hooks/outbound-gate.sh";

  # crush auto-configures LSPs from a bundled registry (powernap v0.1.6, 365
  # servers) whenever options.auto_lsp is on: it matches the file being
  # touched against each server's filetypes/root_markers and starts the ones
  # whose command is on PATH. So this block is deliberately NOT the helix
  # roster re-typed - it is only the gaps in that registry, because a `lsp`
  # entry REPLACES the bundled definition wholesale (internal/lsp/manager.go
  # NewManager -> AddServer) rather than layering onto it. Re-declaring, say,
  # gopls with just a `command` would silently drop its filetypes and root
  # markers and leave it claiming every file in the repo.
  #
  # Already handled by auto_lsp, hence absent here: rust_analyzer (rustup),
  # nil_ls, gopls, golangci_lint_ls, zls, just (just-lsp),
  # kotlin_language_server, sourcekit (Xcode).
  #
  # Commands are absolute store paths, not bare names. auto_lsp gates a
  # bundled server on exec.LookPath and quietly skips it when missing, but a
  # USER-configured server skips that check entirely (manager.go
  # startServer), so a name that is not on crush's PATH becomes a spawn
  # failure on every file open instead of a no-op. The packages themselves
  # are installed by ./helix.nix, which is the sibling roster to keep this in
  # step with.
  lspServers = {
    # Absent from the bundled registry entirely (it ships vtsls, which is not
    # what helix uses and is not installed): TypeScript/JavaScript.
    ts_ls = {
      command = lib.getExe' pkgs.typescript-language-server "typescript-language-server";
      args = [ "--stdio" ];
      filetypes = [ "ts" "tsx" "mts" "cts" "js" "jsx" "mjs" "cjs" ];
      root_markers = [ "tsconfig.json" "jsconfig.json" "package.json" ];
    };

    # Also absent: the three vscode-langservers-extracted servers. json
    # carries helix's file-type list (geojson included) and no root markers,
    # since a lone .json file is worth checking on its own.
    jsonls = {
      command = lib.getExe' pkgs.vscode-langservers-extracted "vscode-json-language-server";
      args = [ "--stdio" ];
      filetypes = [ "json" "jsonc" "geojson" ];
    };

    html = {
      command = lib.getExe' pkgs.vscode-langservers-extracted "vscode-html-language-server";
      args = [ "--stdio" ];
      filetypes = [ "html" ];
    };

    cssls = {
      command = lib.getExe' pkgs.vscode-langservers-extracted "vscode-css-language-server";
      args = [ "--stdio" ];
      filetypes = [ "css" "scss" "less" ];
    };

    # The registry's java entry is `java_language_server`, which wants the
    # java-language-server binary; nixpkgs ships Eclipse jdtls instead, under
    # a name the registry does not know.
    jdtls = {
      command = lib.getExe' pkgs.jdt-language-server "jdtls";
      filetypes = [ "java" ];
      root_markers = [ "pom.xml" "build.gradle" "build.gradle.kts" "settings.gradle" "settings.gradle.kts" ];
      # jdtls indexes the whole project before it answers anything, which on
      # a work-sized Java tree does not fit in the 30s default.
      timeout = 120;
    };

    # dartls IS in the registry, but its command is bare `dart`, which sits on
    # crush's skipAutoStartCommands list ("too generic to auto-start"). Naming
    # it here is what marks it user-configured and lifts that block; the
    # definition is otherwise the registry's, restated because AddServer
    # replaces rather than merges.
    dartls = {
      command = lib.getExe' pkgs.dart "dart";
      args = [ "language-server" "--protocol=lsp" ];
      filetypes = [ "dart" ];
      root_markers = [ "pubspec.yaml" ];
    };

    # harper_ls is in the registry and would auto-start - the override exists
    # to NARROW it. Upstream claims 29 filetypes (rust, go, nix, typescript,
    # ...), so left alone it hands the agent prose diagnostics on source
    # files, in the same diagnostic stream as the compiler's. helix scopes
    # harper to prose and commit messages; match that. Commit messages are
    # not a filetype crush ever opens, so this is the markdown half only.
    harper_ls = {
      command = lib.getExe' pkgs.harper "harper-ls";
      args = [ "--stdio" ];
      filetypes = [ "md" "markdown" ];
      root_markers = [ ".harper-dictionary.txt" ".git" ];
      options."harper-ls".diagnosticSeverity = "hint";
    };
  };
in
{
  xdg.configFile = {
    "crush/hooks/outbound-gate.sh" = {
      source = ../../../tools/crush/outbound-gate.sh;
      executable = true;
    };

    "crush/crush.json".text = builtins.toJSON {
      "$schema" = "https://charm.land/crush.json";
      options = {
        # Verbatim reads, no @-import expansion, missing paths skipped
        # (crush 0.88.1 processContextPath) - so the canonical layers are
        # listed directly instead of the ~/.agents/AGENTS.md entrypoint,
        # in precedence order. CRUSH.md stays as a hand-scribble hatch.
        global_context_paths = [
          "${config.xdg.configHome}/crush/CRUSH.md"
          "${config.home.homeDirectory}/.agents/company-values.md"
          "${config.home.homeDirectory}/.agents/persona-core.md"
          "${config.home.homeDirectory}/.agents/instructions.private.md"
          "${config.home.homeDirectory}/.agents/rules/outbound-comment-gate.md"
        ];

        # Already the upstream default; pinned because the `lsp` block below
        # is written as a gap-fill against the bundled registry. Turn this
        # off and the languages NOT listed there (rust, nix, go, zig, just,
        # kotlin, swift) lose their servers silently.
        auto_lsp = true;
      };
      hooks.PreToolUse = [
        {
          name = "outbound-gate";
          command = hookPath;
          timeout = 15;
        }
      ];

      lsp = lspServers;
    };
  };
}
