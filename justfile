# This repo's recipes. The HUID task recipes are global (tools/just, linked to
# ~/.config/just by mise), imported here so `just task` works without -g.
import? '~/.config/just/justfile'
import? './tools/just/justfile' # temporary, until home-manager is configured

[private]
default:
    @just --list
