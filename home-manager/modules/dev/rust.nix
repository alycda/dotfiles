{ pkgs, ... }:

{
  # Rust toolchain only. Deliberately scoped to what every Rust profile needs,
  # so container profiles can import this module without inheriting a desktop's
  # worth of closure.
  #
  # lldb used to live here and now sits in work.nix, the one profile that wants
  # a system debugger. It is a 1.6 GiB closure - against 94 MiB for rustup and
  # 63 MiB for bacon - and it is not a Rust dependency: cargo and bacon never
  # invoke it, and VS Code's CodeLLDB extension ships its own. Carrying it in
  # the shared module priced the container profiles out of importing this at
  # all, which is how `dev` ended up with no Rust.
  home.packages = with pkgs; [
    rustup
    # rust-analyzer # Don't install standalone - rustup provides rust-analyzer and installing both causes conflicts
    bacon
  ];

  # User-level zsh configuration for Rust
  # Ensures rustup is updated on shell initialization
  programs.zsh.initContent = ''
    rustup update
    # rustup toolchain install nightly
  '';
}
