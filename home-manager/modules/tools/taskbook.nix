# taskbook - tasks, boards & notes for the command-line habitat
# https://github.com/klaussinani/taskbook
#
# A lightweight CLI task manager. Data lives in a local JSON file under
# ~/.taskbook/storage, and config in ~/.taskbook.json - both plain files
# owned by taskbook, so we deliberately do NOT manage them declaratively
# (taskbook writes to them at runtime; a read-only nix store symlink would
# break `tb` on first use).
#
# Imported by the profiles I use as my own environment (home.nix / work.nix)
# rather than common.nix. Keeping it out of common.nix spares the throwaway
# `dev` devcontainer - and the disk-constrained x86 dev image - an extra node
# closure they'd never use (see the common.nix note on lean images), and this
# is personal state anyway, not a core CLI tool "everyone needs".
#
# Future intent: this is a stopgap. The plan is to replace taskbook with a
# roll-my-own task tracker backed by Postgres (with a few extra features) as a
# way to learn Postgres. Isolating taskbook in its own module means that swap
# is a one-file change - drop this import, add the replacement - with no churn
# in the profiles.
{ pkgs, ... }:
{
  home.packages = [ pkgs.taskbook ];
}
