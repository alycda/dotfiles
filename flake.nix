{
  description = "Alyssa's Dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations = {
        "alyssa@home" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home-manager/profiles/home.nix ];
        };
        "alyssa@dev" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home-manager/profiles/dev.nix ];
        };
        "alyssa@work" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home-manager/profiles/work.nix ];
        };
      };
    };
}