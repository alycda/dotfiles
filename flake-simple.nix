{
  description = "Minimal nix-darwin + home-manager test";

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
  };

  outputs = { self, nixpkgs, darwin, home-manager, ... }: {
    darwinConfigurations.simple = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        # Basic nix-darwin config
        {
          services.nix-daemon.enable = true;
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          system.stateVersion = 6; # 5
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
  };
}
