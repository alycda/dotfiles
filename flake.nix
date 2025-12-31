{
  description = "Alyssa's Dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."alyssa@dev" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.aarch64-linux;

      modules = [({ pkgs, ... }: {
        home.username = "root";
        home.homeDirectory = "/root";
        home.stateVersion = "24.05";
        
        home.packages = with pkgs; [ gh helix jujutsu just ];
        
        programs.home-manager.enable = true;
      })];
    };
  };
}