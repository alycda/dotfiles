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

  outputs = { self, nixpkgs, darwin, home-manager, nix-vscode-extensions, ... }:
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

      # For nix-darwin + home-manager (macOS)
      mkDarwin = system: darwinProfile: homeProfile:
        let
          username = "alyssaevans";
        in
        darwin.lib.darwinSystem {
          inherit system;

          specialArgs = { inherit nix-vscode-extensions; };

          modules = [
            ./darwin/configuration.nix
            ./darwin/profiles/${darwinProfile}.nix

            # Integrate home-manager into darwin
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit nix-vscode-extensions; };
              home-manager.users.${username} = {
                imports = [
                  ./home-manager/modules/common.nix
                  ./home-manager/profiles/${homeProfile}.nix
                ];
              };
            }
          ];
        };
    in
    {
      # macOS systems (use darwin-rebuild)
      darwinConfigurations = {
        "ditto" = mkDarwin "aarch64-darwin" "ditto" "work";
      };

      # Linux/devcontainer systems (use home-manager)
      homeConfigurations = {
        # non-sudo user on macOS
        "code" = mkHome "aarch64-darwin" "code";
        # devcontainer
        "alyssa@dev" = mkHome "aarch64-linux" "dev";
        # devcontainer / linux
        "alyssa@work-dev" = mkHome "aarch64-linux" "work";
      };
    };
}