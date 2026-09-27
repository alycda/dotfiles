{
  description = "alycda's dotfiles";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      # Apple Silicon Macs, and the devcontainers on either kind of host.
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      # claude-code is the one unfree package, and the only one allowed.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
        };
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (pkgsFor system));
    in
    {
      # Every tool mise.toml installs, from one list (lib/packages.nix).
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = import ./lib/packages.nix { inherit pkgs; };
        };
      });
    };
}
