{ pkgs, ... }:

{
  userSettings = {

  };

  extensions = with pkgs; [
    vscode-marketplace.rust-lang.rust-analyzer
    vscode-marketplace.tamasfe.even-better-toml
    vscode-marketplace.serayuzgur.crates
    vscode-extensions.vadimcn.vscode-lldb
  ];
}