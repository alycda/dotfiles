# Cheat - command-line cheatsheet tool
# Config and cheatsheets live in tools/cheat/ (shared with devShell)
#
# ~/.cheat/inbox is the one writable cheatpath. It is a quarantine, not the
# library: the cheat-memory skill (and a bare `cheat -e`) drop new sheets there,
# and they are promoted into community/ or personal/ by hand after review. That
# keeps the "verified against crush 0.88.1 source" standard of the existing
# sheets from being diluted by unreviewed agent writes.
#
# Where a live checkout exists the inbox is an out-of-store symlink into
# tools/cheat/cheatsheets/inbox, so a sheet written mid-session shows up in
# `jj status` immediately and promotion is just moving the file. Without one it
# is a plain directory: still writable, just not versioned.
#
# The checkout path is read from agentSkills.liveCheckout rather than declaring
# a second option - both modules are imported by common.nix, and a machine has
# one live checkout, not one per tool. A third consumer should promote it to a
# shared option instead of copying this.
{ config, pkgs, ... }:
let
  checkout = config.agentSkills.liveCheckout;
  inboxPath = "${config.home.homeDirectory}/.cheat/inbox";

  cheatsheetsPath = ../../../tools/cheat/cheatsheets;
  cheatConf = import ../../../tools/cheat/conf.nix {
    inherit pkgs cheatsheetsPath inboxPath;
  };

  # Create a wrapped version of cheat that always has the right config
  cheatWrapped = pkgs.symlinkJoin {
    name = "cheat";
    paths = [ pkgs.cheat ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cheat \
        --set CHEAT_CONFIG_PATH "${cheatConf}"
    '';
  };
in
{
  home = {
    packages = [ cheatWrapped ];

    # Also set it in session variables for consistency
    sessionVariables.CHEAT_CONFIG_PATH = "${cheatConf}";

    # cheat errors out if a configured cheatpath does not exist, so the inbox
    # is materialised either way: a symlink into the checkout, or a real (and
    # therefore writable) directory holding a single store-linked .gitkeep.
    file =
      if checkout != null then
        {
          ".cheat/inbox".source =
            config.lib.file.mkOutOfStoreSymlink "${checkout}/tools/cheat/cheatsheets/inbox";
        }
      else
        { ".cheat/inbox/.gitkeep".text = ""; };
  };
}
