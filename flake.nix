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
    # The system layer on the Macs (darwin/).
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
      # Unfree packages are allowed by name, one at a time: claude-code, and
      # tart (the home profile).
      # taskbook's overlay replaces pkgs.taskbook with the Rust port. Shared
      # by pkgsFor and the darwin module's nixpkgs, so a Mac gets the same.
      nixpkgsSettings = {
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "claude-code"
            "tart"
          ];
        overlays = [ taskbook.overlays.default ];
      };
      pkgsFor = system: import nixpkgs ({ inherit system; } // nixpkgsSettings);
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (pkgsFor system));

      # What every home-manager configuration has, standalone or in darwin,
      # plus its profile (home-manager/profiles/<name>.nix): dev, home or
      # work, which is what lets the containers and the Macs differ.
      homeModules = profile: [
        ragenix.homeManagerModules.default
        ./home-manager/common.nix
        ./home-manager/agenix.nix
        ./home-manager/shell.nix
        ./home-manager/profiles/${profile}.nix
      ];

      mkHome =
        {
          system,
          profile,
          username,
          homeDirectory,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = homeModules profile ++ [ { home = { inherit username homeDirectory; }; } ];
        };

      # A Mac: darwin/configuration.nix for the system, and home-manager as
      # its module for the primary user, with the same modules as mkHome.
      # `sudo darwin-rebuild switch --flake .#<name>` applies it.
      mkDarwin =
        {
          user,
          profile,
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
                users.${user}.imports = homeModules profile;
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
      # kind of host. The names stay as they were; the profile is dev.
      # And `code`, a Mac account without sudo, which can't run
      # darwin-rebuild, so it switches its own home, as on main:
      #   nix run .#home-manager -- switch -b backup --flake .#code@aarch64-darwin
      homeConfigurations =
        let
          dev =
            system: username: homeDirectory:
            mkHome {
              inherit system username homeDirectory;
              profile = "dev";
            };
        in
        {
          "vscode@aarch64-linux" = dev "aarch64-linux" "vscode" "/home/vscode";
          "vscode@x86_64-linux" = dev "x86_64-linux" "vscode" "/home/vscode";
          "root@aarch64-linux" = dev "aarch64-linux" "root" "/root";
          "root@x86_64-linux" = dev "x86_64-linux" "root" "/root";
          "code@aarch64-darwin" = dev "aarch64-darwin" "code" "/Users/code";
        };

      darwinConfigurations = {
        # A Tart VM cloned from Cirrus Labs' macOS base image
        # (ghcr.io/cirruslabs/macos-*-base), whose admin user is `admin`. For
        # trying a switch on a throwaway Mac before a real one.
        # Its image has Homebrew, as a real Mac would.
        tart = mkDarwin {
          user = "admin";
          profile = "dev";
          modules = [ ./darwin/homebrew.nix ];
        };

        # The personal Mac (tasks/20261003-082724).
        shesfast = mkDarwin {
          user = "alyssa";
          profile = "home";
          modules = [
            ./darwin/homebrew.nix
            ./darwin/shesfast.nix
          ];
        };
      };
    };
}
