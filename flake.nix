{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
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

      mkHome =
        system: username: homeDirectory:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            ./home-manager/common.nix
            { home = { inherit username homeDirectory; }; }
          ];
        };
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.jujutsu
            pkgs.just
          ];
        };
      });

      # The home-manager CLI at the version this flake pins:
      #   nix run .#home-manager -- switch --flake .#vscode@$(uname -m)-linux
      packages = forAllSystems (pkgs: {
        home-manager = home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default;
      });

      # The Nix devcontainer's user, on either kind of host.
      homeConfigurations = {
        "vscode@aarch64-linux" = mkHome "aarch64-linux" "vscode" "/home/vscode";
        "vscode@x86_64-linux" = mkHome "x86_64-linux" "vscode" "/home/vscode";
      };
    };
}
