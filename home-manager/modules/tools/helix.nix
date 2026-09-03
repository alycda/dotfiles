# Helix - modal text editor
# Config files live in tools/helix/ (TOML format for easy editing)
# This module uses programs.helix for proper home-manager integration
#
# NOTE: devShell provides basic helix only (for cheat's $EDITOR).
# Full helix with LSPs and config requires home-manager switch.
{ pkgs, lib, ... }:
{
  # Language servers and tools that helix uses
  # (rust-analyzer and rustfmt provided by rustup, not here)
  home.packages = with pkgs; [
    # TypeScript/JavaScript
    typescript-language-server

    # JSON, HTML, CSS
    vscode-langservers-extracted

    # Nix
    nil

    # Mobile/Work languages (ditto)
    jdt-language-server   # Java
    kotlin-language-server
    dart                  # Dart SDK includes LSP

    # Go
    gopls
    golangci-lint-langserver
    delve                 # dlv debugger

    # Zig
    zls
    zig

    # Just
    just-lsp

    # Prose / grammar (Markdown, commit messages, comments)
    # Provides the `harper-ls` binary - a fast, offline, Rust grammar checker.
    # https://writewithharper.com/ - no desktop app, just the LSP for helix.
    harper
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    swift-format          # Swift formatter (sourcekit-lsp from Xcode)
  ];

  programs.helix = {
    enable = true;

    # Settings from tools/helix/config.toml
    settings = {
      theme = "mine";
      editor = {
        soft-wrap.enable = true;
        rulers = [ 72 80 100 120 ];
        color-modes = true;
        inline-diagnostics = {
          cursor-line = "hint";
          other-lines = "hint";
        };
      };
    };

    # Language config from tools/helix/languages.toml
    languages = {
      language = [
        {
          name = "rust";
          auto-format = true;
          formatter = { command = "rustfmt"; };
        }
        {
          name = "javascript";
          language-servers = [ "typescript-language-server" ];
        }
        {
          name = "typescript";
          indent = { tab-width = 2; unit = "  "; };
          roots = [ "deno.json" "package.json" "tsconfig.json" ];
        }
        {
          name = "json";
          language-servers = [ "vscode-json-languageserver" ];
          file-types = [ "json" "jsonc" "geojson" ];
          indent = { tab-width = 2; unit = "  "; };
        }
        # Grammar checking for prose via harper-ls.
        # No marksman/markdown-oxide installed, so harper-ls is the only
        # markdown server here - listing it replaces helix's defaults.
        {
          name = "markdown";
          language-servers = [ "harper-ls" ];
        }
        # Grammar-check commit messages too - this repo values meaningful,
        # well-written commits (see CLAUDE.md commit strategy).
        {
          name = "git-commit";
          language-servers = [ "harper-ls" ];
        }
      ];

      # rust-analyzer config (binary provided by rustup)
      language-server = {
        # harper-ls: offline grammar/spell checker (binary from pkgs.harper).
        # Surface suggestions as "hint" so they match the non-intrusive
        # inline-diagnostics style configured in editor.inline-diagnostics.
        harper-ls = {
          command = "harper-ls";
          args = [ "--stdio" ];
          config.harper-ls.diagnosticSeverity = "hint";
        };

        rust-analyzer.config = {
          check.command = "clippy";
          inlayHints = {
            bindingModeHints.enable = true;
            closingBraceHints.minLines = 10;
            closureReturnTypeHints.enable = "with_block";
            discriminantHints.enable = "fieldless";
            lifetimeElisionHints.enable = "skip_trivial";
            typeHints.hideClosureInitialization = false;
          };
        };
      };
    };

    # Custom theme
    themes = {
      mine = {
        inherits = "boo_berry";
        "ui.background" = {};
        "ui.cursor.primary.select" = { fg = "berry"; bg = "bubblegum"; };
        "ui.cursor.primary.insert" = { fg = "berry"; bg = "mint"; };
      };
    };
  };
}
