{ config, pkgs, ... }:

{
  # Shell configuration shared across bash and zsh
  programs.bash = {
    enable = true;
    shellAliases = {
      cat = "bat";
    };
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      cat = "bat";
    };
  };
}
