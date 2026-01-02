{ pkgs, ... }:

{
  # Rust development tools
  home.packages = with pkgs; [
    rustup
    # rust-analyzer # Don't install standalone - rustup provides rust-analyzer and installing both causes conflicts
    lldb
    bacon
  ];

  # User-level zsh configuration for Rust
  # Ensures rustup is updated on shell initialization
  programs.zsh.initExtra = ''
    rustup update
    # rustup toolchain install nightly
  '';
}
