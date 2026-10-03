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
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      taskbook,
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
      # taskbook's overlay replaces pkgs.taskbook with the Rust port.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
          overlays = [ taskbook.overlays.default ];
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
