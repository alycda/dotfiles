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

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned index of skills.sh agent skills; consumed selectively via
    # lib/skills-sh.nix (see that file for why we don't use its overlay)
    nix-skills = {
      url = "github:sudosubin/nix-skills";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, darwin, home-manager, nix-vscode-extensions, ragenix, claude-code-nix, nix-skills, ... }:
    let
      # Systems supported for devShells
      # x86_64-darwin dropped: nixpkgs 26.11 removed support for it, and every
      # config here targets aarch64-darwin or Linux (the 2012 MBP runs the
      # x86_64-linux devcontainer, not a native darwin shell).
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
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
            claude-code-nix.overlays.default
            (import ./lib/skills-sh.nix nix-skills)
          ];
        };

        extraSpecialArgs = { inherit nix-vscode-extensions; };

        modules = [
          ragenix.homeManagerModules.default
          ./home-manager/modules/common.nix
          ./home-manager/profiles/${profile}.nix
        ];
      };

      # For nix-darwin + home-manager (macOS)
      mkDarwin = system: username: darwinProfile: homeProfile:
        darwin.lib.darwinSystem {
          inherit system;

          specialArgs = { inherit nix-vscode-extensions claude-code-nix nix-skills; };

          modules = [
            ./darwin/configuration.nix
            ./darwin/profiles/${darwinProfile}.nix
            ragenix.darwinModules.default

            # Integrate home-manager into darwin
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # Adopt pre-existing hand-edited files (e.g. ~/.codex/AGENTS.md)
                # as *.hm-backup instead of failing activation.
                backupFileExtension = "hm-backup";
                extraSpecialArgs = { inherit nix-vscode-extensions; };
                users.${username} = {
                  imports = [
                    ragenix.homeManagerModules.default
                    ./home-manager/modules/common.nix
                    ./home-manager/profiles/${homeProfile}.nix
                  ];
                };
              };
            }
          ];
        };
    in
    {
      # macOS systems (use darwin-rebuild)
      darwinConfigurations = {
        "ditto" = mkDarwin "aarch64-darwin" "alyssaevans" "ditto" "work";
        "shesfast" = mkDarwin "aarch64-darwin" "alyssa" "shesfast" "home";
      };

      # Linux/devcontainer systems (use home-manager)
      homeConfigurations = {
        # non-sudo user on macOS
        "code" = mkHome "aarch64-darwin" "code";
        # laptop
        "alyssa@home" = mkHome "aarch64-darwin" "home";
        # devcontainer
        "alyssa@dev" = mkHome "aarch64-linux" "dev";
        # devcontainer on x86_64 hosts (e.g. Docker on the 2012 MBP)
        "alyssa@dev-x86" = mkHome "x86_64-linux" "dev";
        # devcontainer / linux
        "alyssa@work-dev" = mkHome "aarch64-linux" "work";
      };

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            # core-packages carries crush, which is unfree (FSL-1.1-MIT) -
            # without this every devShell fails evaluation, which also fails
            # `nix flake check --all-systems`. mkHome and darwin already
            # allow unfree; this brings the devShells in line.
            config.allowUnfree = true;
          };

          # Core packages shared with home-manager
          corePackages = import ./lib/core-packages.nix pkgs;

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
            shellHook = ''
              export CHEAT_CONFIG_PATH="${cheatConf}"
              export EDITOR="hx"
            '';
          };
        in
        {
          tools = cheatShell;

          default = pkgs.mkShell {
            inputsFrom = [ cheatShell ];
            # helix inherited from cheatShell (basic, for cheat's $EDITOR)
            # Full helix with LSPs requires home-manager switch
            # Core packages imported from lib/core-packages.nix (shared with home-manager)
            packages = corePackages;
          };
        }
      );
    };
}
