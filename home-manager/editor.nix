# helix's language servers, for every profile. helix's config is the plain
# files in tools/helix/ (common.nix links the directory), which the mise
# account links too; the servers are Nix only. tools/helix/languages.toml
# says which server each language uses.
#
# Java, Kotlin and Dart are the work Mac's (profiles/work.nix). rust-analyzer
# and rustfmt come from rustup, which nothing here installs.
{ lib, pkgs, ... }:
{
  home.packages = [
    # Nix
    pkgs.nil
    pkgs.nixd
    # TypeScript and JavaScript; JSON, HTML and CSS
    pkgs.typescript-language-server
    pkgs.vscode-langservers-extracted
    # Zig
    pkgs.zls
    pkgs.zig
    # justfiles
    pkgs.just-lsp
    # Grammar and spelling for Markdown and commit messages (harper-ls),
    # offline.
    pkgs.harper
  ];
}
