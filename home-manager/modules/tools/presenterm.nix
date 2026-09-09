# presenterm themes - terminal slide decks.
#
# The binary itself is installed in common.nix (every profile gets it); this
# module only delivers theme content from tools/presenterm/themes/.
#
# The trap this module exists to absorb: presenterm does NOT follow XDG on
# macOS. Its config directory is $XDG_CONFIG_HOME/presenterm when that variable
# is set, and otherwise ~/.config/presenterm on Linux but
# ~/Library/Application Support/presenterm on darwin. Every other tool module
# here reaches for xdg.configFile and is right to; presenterm would silently
# not find the theme (it fails as "theme not found", never as a path error).
# So the themes are linked into both locations on darwin: the Application
# Support path for the default case, the XDG path for a shell that exports
# XDG_CONFIG_HOME. Two symlinks to the same store file is a cheap way to be
# right either way.
#
# Themes are read-only content, so a store symlink is correct here - presenterm
# never writes to them (contrast the runtime-mutable-config rule in CLAUDE.md).
{ lib, pkgs, ... }:
let
  themeDir = ../../../tools/presenterm/themes;

  # Every theme in tools/presenterm/themes, by name. Adding one is a one-line
  # edit here plus the file itself.
  themeNames = [ "rustconf.yaml" ];

  linkThemes =
    prefix:
    lib.listToAttrs (
      map (
        name: lib.nameValuePair "${prefix}/${name}" { source = themeDir + "/${name}"; }
      ) themeNames
    );
in
{
  xdg.configFile = linkThemes "presenterm/themes";

  home.file = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
    linkThemes "Library/Application Support/presenterm/themes"
  );
}
