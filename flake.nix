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
      mkHome = system: profile: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; };
        modules = [
          ./home-manager/modules/common.nix
          ./home-manager/profiles/${profile}.nix
        ];
      };
    in
    {
      homeConfigurations = {
        # laptop
        "alyssa@home" = mkHome "aarch64-darwin" "home";
        # devcontainer
        "alyssa@dev" = mkHome "aarch64-linux" "dev";
        # laptop
        "alyssa@work" = mkHome "aarch64-darwin" "work";
        # devcontainer / linux
        "alyssa@work-dev" = mkHome "aarch64-linux" "work";
      };
    };
}