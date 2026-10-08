# The prompt, the fuzzy finder, and bash, for every profile, as on main. zsh
# itself is common.nix and tools/zsh/interactive.zsh. All three are Nix only.
{ ... }:
{
  # starship, in zsh and bash. The nerd-font-symbols preset needs a Nerd Font
  # in the terminal drawing the prompt: on a Mac, the cask
  # (darwin/shesfast.nix), selected in the terminal's settings; in a
  # container, the host terminal's font. Boxes instead of icons mean it isn't
  # set; drop the preset for plain symbols.
  programs.starship = {
    enable = true;
    presets = [ "nerd-font-symbols" ];
    # A module's command is killed after 500ms by default, with a warning in
    # the prompt. `git status` on a large tree over a container's bind mount
    # can take longer.
    settings.command_timeout = 1000;
  };

  # fzf's keys in zsh: Ctrl-R history, Ctrl-T files, Alt-C directories. Files
  # come from ripgrep (.gitignore respected, hidden files shown) and preview
  # with bat; both are in lib/packages.
  programs.fzf = {
    enable = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";
    defaultOptions = [
      "--height=50%"
      "--layout=reverse"
      "--border=rounded"
      "--preview='bat --style=numbers,changes --color=always --line-range=:200 {}'"
      "--preview-window=right:55%:wrap"
    ];
    fileWidget = {
      command = "rg --files --hidden --follow --glob '!.git'";
      options = [
        "--preview 'bat --style=numbers,changes --color=always --line-range=:300 {}'"
      ];
    };
    changeDirWidget.options = [ "--preview 'ls -la {}'" ];
  };

  # bash as a fallback shell that still gets the prompt and direnv:
  # home-manager writes ~/.bashrc, ~/.bash_profile and ~/.profile. It also
  # installs bash 5, which the Macs need (macOS's bash 3.2 can't run
  # home-manager's bashrc). The containers' dev profile takes the config
  # without the binary.
  programs.bash.enable = true;
}
