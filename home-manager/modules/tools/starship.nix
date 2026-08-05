_:

# starship: the prompt (issue #15).
#
# Before this, there was no prompt config anywhere in the repo. On darwin you
# got zsh's stock `%m%#`; in the container you got a bare `bash-5.3#`, which
# says nothing - not the directory, not the branch, not whether the last
# command failed, and not even that you were inside a container.
#
# Enabled from common.nix, so every profile gets the same prompt: the `dev`
# devcontainer and the darwin desktops alike. home-manager's starship module
# wires both `programs.bash` and `programs.zsh` automatically - the
# enable*Integration options default to `home.shell.enableShellIntegration`,
# which is already true - so there is nothing to opt into here.
#
# NERD FONT REQUIRED
# The `nerd-font-symbols` preset swaps starship's plain glyphs for Nerd Font
# ones ( for a git branch, the docker whale inside a container, per-language
# icons). Glyphs are resolved by the *terminal emulator*, not by anything Nix
# installs into the shell - so:
#   - darwin: the font ships via the homebrew cask in darwin/modules/homebrew.nix,
#     but you still have to select it in the terminal's own settings (cmux).
#   - container: there is no font in here at all. The prompt is drawn by
#     whatever terminal on the HOST you opened the container from, so it's that
#     terminal's font that has to be patched.
# If you see tofu boxes (􏿽), the terminal font isn't set. Swap `presets` to
# [ "plain-text-symbols" ] or drop the option entirely for the plain default.
{
  programs.starship = {
    enable = true;

    # home-manager deep-merges the preset files first and `settings` on top of
    # them (via tomlq), so anything under `settings` wins over the preset.
    presets = [ "nerd-font-symbols" ];

    settings = {
      # starship kills a module's shell-out at 500ms and prints a warning into
      # the prompt when it does. `/work` is a bind mount of the host disk, and
      # on the x86 image that mount is grpcfuse over a 2012 MBP's SSD, where
      # `git status` on a large tree blows past 500ms as a matter of course.
      # 1s gives the slow mount room without letting a genuinely hung command
      # stall the prompt for long.
      command_timeout = 1000;
    };
  };
}
