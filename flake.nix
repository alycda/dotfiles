{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # taskbook's Rust port. nixpkgs' taskbook is the original Node.js CLI.
    # Its overlay fetches the release binaries. Not the v1.5.0 tag: that
    # tag's overlay has a wrong aarch64-linux hash, fixed on main afterwards.
    # flake.lock pins the commit; keep its version the one mise installs.
    taskbook = {
      url = "github:taskbook-sh/taskbook";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # agenix secrets (secrets/), in Rust: the CLI and the home-manager module.
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The system layer on the Macs (darwin/). master tracks nixpkgs-unstable,
    # as nixpkgs here does.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      taskbook,
      ragenix,
      nix-darwin,
      ...
    }:
    let
      # Apple Silicon Macs, and the devcontainers on either kind of host.
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      # claude-code is the one unfree package, and the only one allowed.
      # taskbook's overlay replaces pkgs.taskbook with the Rust port. Shared
      # by pkgsFor and the darwin module's nixpkgs, so a Mac gets the same.
      nixpkgsSettings = {
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
        overlays = [ taskbook.overlays.default ];
      };
      pkgsFor = system: import nixpkgs ({ inherit system; } // nixpkgsSettings);
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (pkgsFor system));

      # What every home-manager configuration has, standalone or in darwin.
      homeModules = [
        ragenix.homeManagerModules.default
        ./home-manager/common.nix
        ./home-manager/agenix.nix
      ];

      mkHome =
        system: username: homeDirectory:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = homeModules ++ [ { home = { inherit username homeDirectory; }; } ];
        };

      # A Mac: darwin/configuration.nix for the system, and home-manager as
      # its module for the primary user, with the same modules as mkHome.
      # `sudo darwin-rebuild switch --flake .#<name>` applies it.
      mkDarwin =
        {
          user,
          system ? "aarch64-darwin",
          modules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          modules = [
            ./darwin/configuration.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs = nixpkgsSettings // {
                hostPlatform = system;
              };
              # Who the per-user settings (system.defaults, Homebrew) are for.
              system.primaryUser = user;
              users.users.${user}.home = "/Users/${user}";
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # As `switch -b backup` does on Linux: a file home-manager
                # takes over, such as ~/.zprofile, moves to <file>.backup
                # rather than stopping the switch.
                backupFileExtension = "backup";
                users.${user}.imports = homeModules;
              };
            }
          ]
          ++ modules;
        };
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.jujutsu
            pkgs.just
            # `just edit-secret`. nixpkgs' ragenix: the ragenix flake's own
            # package builds through a rust-overlay too old for this nixpkgs.
            pkgs.rage
            pkgs.ragenix
          ];
        };
      });

      # The home-manager CLI at the version this flake pins:
      #   nix run .#home-manager -- switch --flake .#vscode@$(uname -m)-linux
      # and on a Mac, darwin-rebuild, for the first switch (afterwards it is
      # on PATH):
      #   sudo nix run .#darwin-rebuild -- switch --flake .#<name>
      packages = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          home-manager = home-manager.packages.${system}.default;
        }
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          darwin-rebuild = nix-darwin.packages.${system}.darwin-rebuild;
        }
      );

      # The Nix devcontainer's user, and the Dockerfile image's, on either
      # kind of host.
      homeConfigurations = {
        "vscode@aarch64-linux" = mkHome "aarch64-linux" "vscode" "/home/vscode";
        "vscode@x86_64-linux" = mkHome "x86_64-linux" "vscode" "/home/vscode";
        "root@aarch64-linux" = mkHome "aarch64-linux" "root" "/root";
        "root@x86_64-linux" = mkHome "x86_64-linux" "root" "/root";
      };

      darwinConfigurations = {
        # A Tart VM cloned from Cirrus Labs' macOS base image
        # (ghcr.io/cirruslabs/macos-*-base), whose admin user is `admin`. For
        # trying a switch on a throwaway Mac before a real one.
        tart = mkDarwin { user = "admin"; };
      };
    };
}
