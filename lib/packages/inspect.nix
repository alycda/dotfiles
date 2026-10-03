# inspect (Ataraxy Labs): review triage by structural risk. The release
# binary mise installs, at the same version, patched to run from the Nix
# store (lib/release-binary.nix). nixpkgs has no inspect.
{ pkgs }:
let
  release = import ../release-binary.nix { inherit pkgs; };
in
[
  (release {
    pname = "inspect";
    version = "0.1.1";
    bin = "inspect";
    assets = {
      aarch64-darwin = {
        url = "https://github.com/Ataraxy-Labs/inspect/releases/download/v0.1.1/inspect-macos-aarch64";
        hash = "sha256-5/7Vcir24U3GaCed14VBCfl3hITUixpC6tXSxxuLuQ0=";
      };
      aarch64-linux = {
        url = "https://github.com/Ataraxy-Labs/inspect/releases/download/v0.1.1/inspect-linux-aarch64";
        hash = "sha256-IyfB3hDs9A5RmcFf3ExLPBc3NWQClOd5xjX0wVdx5PY=";
      };
      x86_64-linux = {
        url = "https://github.com/Ataraxy-Labs/inspect/releases/download/v0.1.1/inspect-linux-x86_64";
        hash = "sha256-mc9OoqKhBI2Ok2mmpaEeX4TuPzxwbgveBy+bK9ROlro=";
      };
    };
  })
]
