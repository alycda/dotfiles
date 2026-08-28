# Crush (charmbracelet) declarative config slice.
#
# Providers/models stay in the hand-managed ~/.config/crush/crushrc (its
# api-key lines reference $VARs, never literals). This module owns the JSON
# sibling: crush merges crush.json and crushrc from the same directory
# (verified in crush 0.88.1 load.go; crushrc wins on key conflicts and crush
# warns), so the two files compose instead of fighting - as long as the
# crushrc never sets the keys owned here (options, hooks, lsp, mcp).
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
  gwCfg = config.crush.mcp.googleWorkspace;

  # Google ships ONE remote MCP server per Workspace product rather than a
  # single "workspace" endpoint, so each one wired is its own OAuth grant,
  # its own status card, and its own pile of tool schemas in the request.
  # That last one is why the default set below is a subset: tool schemas are
  # billed context on every turn.
  googleWorkspaceEndpoints = {
    gmail = "https://gmailmcp.googleapis.com/mcp/v1";
    drive = "https://drivemcp.googleapis.com/mcp/v1";
    docs = "https://docsmcp.googleapis.com/mcp/v1";
    sheets = "https://sheetsmcp.googleapis.com/mcp/v1";
    slides = "https://slidesmcp.googleapis.com/mcp/v1";
    calendar = "https://calendarmcp.googleapis.com/mcp/v1";
    chat = "https://chatmcp.googleapis.com/mcp/v1";
  };

  googleWorkspaceMcp = lib.listToAttrs (
    map (
      svc:
      lib.nameValuePair "google-${svc}" {
        type = "http";
        url = googleWorkspaceEndpoints.${svc};
        oauth = true;
        # Google's MCP endpoints do not offer dynamic client registration, so
        # the credentials of a GCP OAuth client (Desktop app type) have to be
        # supplied. crush runs oauth_client_id/secret through the same shell
        # resolver as headers and env, so these stay $VAR/$(cmd) templates and
        # no secret material lands in the world-readable store copy of
        # crush.json. See internal/agent/tools/mcp/init.go:1034.
        oauth_client_id = gwCfg.clientId;
        oauth_client_secret = gwCfg.clientSecret;
        # Google enforces exact-match redirect URIs, so the callback port
        # cannot be the ephemeral one crush picks by default.
        oauth_callback_port = gwCfg.callbackPort;
      }
    ) gwCfg.services
  );

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
  options.crush.mcp.googleWorkspace = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Wire the Google Workspace remote MCP servers.

        Off by default because these are the only servers here that cannot
        connect on their own. Google does not offer dynamic client
        registration, so first: a GCP project, an OAuth client of type
        "Desktop app" whose registered redirect URI is
        http://127.0.0.1 on the `callbackPort` below, the per-product APIs
        enabled on its consent screen, and its credentials reachable from
        `clientId`/`clientSecret` below. Enabled without those, crush
        resolves an empty client id and the OAuth flow fails outright -
        there is no fallback to DCR.
      '';
    };

    services = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames googleWorkspaceEndpoints));
      default = [ "drive" "docs" "calendar" "gmail" ];
      description = ''
        Which Workspace products to wire. Each is a separate MCP server, a
        separate OAuth grant, and a separate block of tool schemas in every
        request - so this is a subset by default rather than all seven.
      '';
    };

    clientId = lib.mkOption {
      type = lib.types.str;
      default = "$GOOGLE_WORKSPACE_MCP_CLIENT_ID";
      description = ''
        Shell template crush resolves for the OAuth client id. A bare $VAR
        by default so that nothing secret is written to the Nix store; a
        `$(cat <path>)` reading an agenix-decrypted file works the same way
        once the value is carried in secrets/.
      '';
    };

    clientSecret = lib.mkOption {
      type = lib.types.str;
      default = "$GOOGLE_WORKSPACE_MCP_CLIENT_SECRET";
      description = "Shell template crush resolves for the OAuth client secret. See clientId.";
    };

    callbackPort = lib.mkOption {
      type = lib.types.port;
      default = 3119;
      description = ''
        Fixed localhost port for the OAuth redirect. Must match the redirect
        URI registered on the GCP OAuth client exactly. 3118 is deliberately
        avoided - that is the port Slack's client is registered against.
      '';
    };
  };

  config = {
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

        # Every server here is a hosted HTTP endpoint reached with crush's
        # OAuth 2.1 flow (crush >= 0.87) rather than an `npx mcp-remote`
        # stdio bridge or a long-lived API token. Two things follow, and both
        # are the reason to prefer this shape:
        #
        #  - No secret material in this file, so none in the Nix store. The
        #    token crush exchanges is written to
        #    ~/.local/share/crush/crush.json - the machine-writable data
        #    config, which loads AFTER this one and deep-merges into it
        #    (load.go lookupConfigs), so a read-only store symlink here is
        #    not in the way.
        #  - Nothing happens unattended. Startup never opens a browser:
        #    unauthorized servers sit in StateNeedsAuth until authorized from
        #    the TUI. A headless container therefore shows them pending
        #    rather than hanging, which is why this block is not gated on a
        #    desktop profile.
        mcp = {
          # DCR-capable, so it needs no client registration at all.
          notion = {
            type = "http";
            url = "https://mcp.notion.com/mcp";
            oauth = true;
          };

          # Slack's OAuth server rejects dynamic client registration, so a
          # pre-registered client is mandatory. This is the public client of
          # Slack's own MCP plugin (slackapi/slack-mcp-plugin .mcp.json) -
          # a public PKCE client with no secret, hence committable; port 3118
          # is the redirect URI it is registered against and is not free to
          # change.
          slack = {
            type = "http";
            url = "https://mcp.slack.com/mcp";
            oauth = true;
            oauth_client_id = "1601185624273.8899143856786";
            oauth_callback_port = 3118;
          };

          # Linear does DCR. Note this authenticates as whichever Linear
          # account authorizes it, which is NOT the same lever as the
          # linear-api-key-work/-personal agenix secrets in ./agents.nix:
          # those feed the API-key-based server in the work tree. Two paths
          # to Linear, two identities to keep straight.
          linear = {
            type = "http";
            url = "https://mcp.linear.app/mcp";
            oauth = true;
          };

          # NOT wired: github (https://api.githubcopilot.com/mcp/). It would
          # be a one-liner - `headers.Authorization = "Bearer $(gh auth
          # token)"`, no PAT to mint, since headers take $(cmd) - but it
          # cannot work on the pinned crush. GitHub's server is sessionless:
          # it issues no Mcp-Session-Id, and answers the SEP-2575
          # subscriptions/listen POST that go-sdk v1.7.0 opens for any
          # list-changed handler with a 404 the SDK treats as fatal. crush
          # gained the `sessionless` flag (and URL auto-detection for exactly
          # this endpoint) only after 0.88.1; both versions vendor the same
          # SDK, so this is crush's fix to make, not one we can configure
          # around. Add it back on the next nixpkgs bump past crush 0.91 -
          # auto-detection means the header is then the whole entry. Until
          # then GitHub goes through `gh` in bash, which the outbound gate
          # already covers.
        }
        // lib.optionalAttrs gwCfg.enable googleWorkspaceMcp;
      };
    };
  };
}
