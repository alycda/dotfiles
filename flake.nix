# first run: `USER=root nix run home-manager/master -- switch --flake .#alyssa@dev`
# subsequent runs: `USER=root home-manager switch --flake .#alyssa@dev`

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
        
        home.packages = with pkgs; [ gh helix jujutsu ];
        
        programs.home-manager.enable = true;
      })];
    };
  };
}