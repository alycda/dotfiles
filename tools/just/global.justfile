# Invocable cheatsheets, promoted to just's GLOBAL justfile: `just -g <recipe>`
# from anywhere (recipes run with the invocation directory as cwd). Each
# converted sheet under tools/cheat/cheatsheets keeps a pointer line to its
# recipe here; sheets that are genuinely reference material stay sheets.
# Successor to the community/nix/sh trick (`cheat <name> | sh`).
#
# Root is imports-only (same shape as getditto/ditto#21676): one .just file
# per topic group, recipes delegate to real binaries where one exists.

import 'gh.just'
import 'git.just'
import 'jj.just'
import 'nix.just'
import 'claude.just'
import 'personal.just'
import 'rust.just'
