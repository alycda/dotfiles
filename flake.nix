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
          
          # Create a wrapped version of cheat that always has the right config
          cheatWrapped = pkgs.symlinkJoin {
            name = "cheat";
            paths = [ pkgs.cheat ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/cheat \
                --set CHEAT_CONFIG_PATH "${cheatConf}"
            '';
          };

          # Basic helix for cheat's editor (full config via home-manager)
          cheatShell = pkgs.mkShell {
            packages = [ cheatWrapped pkgs.helix ];
            shellHook = ''export CHEAT_CONFIG_PATH="${cheatConf}"'';
          };
        in
        {
          tools = cheatShell;

          default = pkgs.mkShell {
            inputsFrom = [ cheatShell ];
            # helix inherited from cheatShell, full config via home-manager
            packages = with pkgs; [
              ripgrep
              jujutsu

              # Language servers for helix
              rust-analyzer
              typescript-language-server
              vscode-langservers-extracted
              nil
              lldb_18

              # Mobile/Work languages (ditto)
              jdt-language-server
              kotlin-language-server
              dart

              # Go
              gopls
              golangci-lint-langserver
              delve

              # Zig
              zls
              zig

              # Just
              just-lsp
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              swift-format  # macOS only (sourcekit-lsp from Xcode)
            ];
          };
        }
      );
    };
}