{
  description = "Alyssa's Dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, nix-vscode-extensions, ... }:
    let
      # For standalone home-manager (Linux/devcontainers)
      mkHome = system: profile: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        extraSpecialArgs = { inherit nix-vscode-extensions; };

        modules = [
          ./home-manager/modules/common.nix
          ./home-manager/profiles/${profile}.nix
        ];
      };


    in
    {
      darwinConfigurations.basic = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          # Basic nix-darwin config
          {
            nix.settings = {
              experimental-features = [ "nix-command" "flakes" ];
              trusted-users = [ "alyssaevans" ];
            };

            nixpkgs.config.allowUnfree = true;

            users.users.alyssaevans = {
              name = "alyssaevans";
              home = "/Users/alyssaevans";
            };

            # Used for backwards compatibility, please read the changelog before changing.
            # $ darwin-rebuild changelog
            system.stateVersion = 6;
            programs.zsh.enable = true;
          }

          # Home-manager integration
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.alyssaevans = {
              home.username = "alyssaevans";
              home.homeDirectory = "/Users/alyssaevans";
              home.stateVersion = "25.05";

              home.packages = [ ];

              programs.home-manager.enable = true;
            };
          }
        ];
      };

      homeConfigurations = {
        "code" = mkHome "aarch64-darwin" "code";
        # laptop
        "alyssa@home" = mkHome "aarch64-darwin" "home";
        # devcontainer
        "alyssa@dev" = mkHome "aarch64-linux" "dev";
        # laptop
        "alyssa@work" = mkHome "aarch64-darwin" "work";
        # devcontainer / linux
        "alyssa@work-dev" = mkHome "aarch64-linux" "work";
      };
    };
}