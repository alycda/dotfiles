# Helix - modal text editor
# Config files live in tools/helix/ and are read directly (fromTOML), so
# editing the TOML is the whole change; this module adds the LSP packages.
#
# NOTE: devShell provides basic helix only (for cheat's $EDITOR).
# Full helix with LSPs and config requires home-manager switch.
{ pkgs, lib, ... }:
let
  inherit (builtins) fromTOML readFile;
in
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
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    swift-format          # Swift formatter (sourcekit-lsp from Xcode)
  ];

  # The TOML files in tools/helix are the config, read as they are. The
  # account with no Nix links that same directory to ~/.config/helix
  # (see tools/mise/config.toml), so both setups load identical settings
  # and there is no second copy to translate by hand.
  programs.helix = {
    enable = true;
    settings = fromTOML (readFile ../../../tools/helix/config.toml);
    languages = fromTOML (readFile ../../../tools/helix/languages.toml);
    themes.mine = fromTOML (readFile ../../../tools/helix/themes/mine.toml);
  };

  # Global file-picker ignore rules. The linked directory already gives the
  # other account this file, so deploy it here too to keep them identical.
  xdg.configFile."helix/ignore".source = ../../../tools/helix/ignore;
}
