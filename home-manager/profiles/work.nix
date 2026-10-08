# The work profile: the work Mac (ditto, user alyssaevans). What only that
# machine gets goes here: work tools and accounts.
#
# A profile is a role, not an account; see dev.nix.
{ pkgs, ... }:
{
  # helix's language servers for the work languages (the rest are in
  # home-manager/editor.nix): Java, Kotlin, and Dart, whose SDK has its own.
  home.packages = [
    # Go, with its linter's server and the debugger
    pkgs.gopls
    pkgs.golangci-lint-langserver
    pkgs.delve
    # Java
    pkgs.jdt-language-server
    pkgs.kotlin-language-server
    pkgs.dart
  ]
  # Swift's formatter; its language server comes with Xcode.
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.swift-format ];
}
