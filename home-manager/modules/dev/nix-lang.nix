{ pkgs, ... }:

{
  # Nix language development tools
  home.packages = with pkgs; [
    nil   # Nix LSP server
    nixd  # Alternative Nix LSP with more features
  ];
}
