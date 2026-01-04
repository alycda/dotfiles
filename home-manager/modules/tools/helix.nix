# Helix - modal text editor
# Config files live in tools/helix/ (TOML format for easy editing)
# This module uses programs.helix for proper home-manager integration
{ config, pkgs, lib, ... }:
let
  # Read TOML config files from tools/helix/
  configDir = ../../../tools/helix;
in
{
  # Language servers and tools that helix uses
  # (Nix deduplicates if also in dev modules)
  home.packages = with pkgs; [
    # Rust
    rust-analyzer

    # TypeScript/JavaScript
    typescript-language-server

    # JSON, HTML, CSS
    vscode-langservers-extracted

    # Nix
    nil

    # Debug adapter
    lldb_18

    # Mobile/Work languages (ditto)
    jdt-language-server   # Java
    kotlin-language-server
    dart                  # Dart SDK includes LSP
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
        {
          name = "brightscript";
          file-types = [ "brs" "bs" ];
          comment-tokens = [ "'" "rem" ];
          indent = { tab-width = 4; unit = "    "; };
          language-servers = [ "brighterscript-lsp" ];
        }
      ];

      language-server = {
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
        brighterscript-lsp = {
          command = "bsc";
          args = [ "--lsp" ];
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
