# The home profile. What only that machine gets goes here: personal apps and accounts.
#
# A profile is a role, not an account; see dev.nix.
{ pkgs, ... }:
{
  home.packages = [
    # Tart, macOS only, and unfree (allowed by name in flake.nix).
    pkgs.tart

    # CLI tools main had from Homebrew on shesfast, from Nix here. Only alyssa
    # gets these; the formulae other accounts need stay in Homebrew
    # (darwin/shesfast.nix).
    pkgs.kondo # removes build artifacts
    pkgs.llmfit
    # The ollama CLI and server. Homebrew's could run as a `brew services`
    # agent; this one runs when started (`ollama serve`).
    pkgs.ollama
    pkgs.openvpn
    # pkgs.poppler-utils # pdftotext and friends
    pkgs.typst
    pkgs.wishlist # an SSH directory, from Charm
  ];
}
