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

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darwin, home-manager, nix-vscode-extensions, agenix, ... }:
    let
      # Systems supported for devShells
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # For standalone home-manager (Linux/devcontainers/non-sudo macOS)
      # These configs create their own pkgs (not inherited from darwin)
      mkHome = system: profile: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          # Allow unfree packages (e.g., vscode-marketplace extensions)
          # Note: For darwin configs, this is set at darwin/configuration.nix and inherited via useGlobalPkgs
          config.allowUnfree = true;
          # Apply VSCode marketplace overlay
          # Note: For darwin configs, this is set at darwin/configuration.nix and inherited via useGlobalPkgs
          overlays = [
            nix-vscode-extensions.overlays.default
          ];
        };

        extraSpecialArgs = { inherit nix-vscode-extensions; };

        modules = [
          agenix.homeManagerModules.default
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
            agenix.darwinModules.default

            # Integrate home-manager into darwin
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit nix-vscode-extensions; };
              home-manager.users.${username} = {
                imports = [
                  agenix.homeManagerModules.default
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
        # laptop
        "alyssa@home" = mkHome "aarch64-darwin" "home";
        # devcontainer
        "alyssa@dev" = mkHome "aarch64-linux" "dev";
        # devcontainer / linux
        "alyssa@work-dev" = mkHome "aarch64-linux" "work";
      };

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          cheatConf = import ./tools/cheat/conf.nix {
            inherit pkgs;
            cheatsheetsPath = ./tools/cheat/cheatsheets;
          };

          cheatShell = pkgs.mkShell {
            packages = [ pkgs.cheat pkgs.helix ];
            shellHook = ''export CHEAT_CONFIG_PATH="${cheatConf}"'';
          };
        in
        {
          tools = cheatShell;

          default = pkgs.mkShell {
            inputsFrom = [ cheatShell ];
            packages = with pkgs; [
              ripgrep
              helix
              jujutsu
            ];
          };
        }
      );
    };
}