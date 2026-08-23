---
title: "The dev container ships no terminfo database, so TERM silently falls back to xterm"
date: 2026-08-23
category: runtime-errors
module: home-manager/profiles/dev.nix
problem_type: runtime_error
component: tooling
severity: medium
symptoms:
  - "Scrollback and alt-screen handling are broken: full-screen programs leave their output behind, or the shell's scrollback is clobbered"
  - "Wrong colors and mangled line-drawing characters in TUIs (helix, gh-dash, taskbook, tmux)"
  - "Modified keys - Ctrl+arrow, Shift+arrow - arrive as literal escape garbage instead of key events"
  - "`echo $TERM` prints `xterm` in a `docker exec` shell, no matter what the host terminal is"
  - "`infocmp` and `tic` are 'command not found', so the terminal description can't even be inspected"
  - "`$TERMINFO_DIRS` is empty and /usr/share/terminfo, /etc/terminfo, /lib/terminfo and ~/.nix-profile/share/terminfo all do not exist"
root_cause: config_error
resolution_type: config_change
related_components:
  - development_workflow
  - documentation
tags:
  - nix
  - home-manager
  - docker
  - devcontainer
  - ncurses
  - terminfo
  - ghostty
  - tmux
---

# The dev container ships no terminfo database, so TERM silently falls back to xterm

## Problem

Terminal rendering in the dev container was subtly wrong in a dozen unrelated-looking ways — mangled box drawing, colors that didn't match the host, scrollback that came back wrong after a full-screen program exited, Ctrl+arrow arriving as `;5C`. Each symptom looked like a bug in whichever program surfaced it, and the cluster was misattributed for a while to "tmux doesn't work under cmux".

None of it was tmux. The container had **no terminfo database on any path ncurses searches**, and `TERM` was `xterm`.

```
$ echo $TERM
xterm
$ infocmp $TERM
zsh: command not found: infocmp
$ echo $TERMINFO_DIRS
                                   # empty
$ ls /usr/share/terminfo/x/
ls: cannot access '/usr/share/terminfo/x/': No such file or directory
$ ls -d /etc/terminfo /lib/terminfo ~/.nix-profile/share/terminfo 2>/dev/null
                                   # no output
```

## Root cause

Two independent failures that produce one symptom, which is why fixing either alone changes nothing.

**1. The entries are unreachable.** ncurses *is* in the closure — twice —
and both copies have a fully populated database:

```
/nix/store/6g9cfr3q8qkkwgj3b3s29cj9bvcrkz96-ncurses-6.6/share/terminfo
/nix/store/ah5m9c4ffy0m45h68ls77xr6m4c6rmg9-ncurses-6.6/share/terminfo
```

But they're there as transitive dependencies of stdenv and the shell, and a transitive dependency's *data files* are not part of the user environment — only the libraries other packages link against. Meanwhile nixpkgs builds ncurses with `--with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo:/run/current-system/sw/share/terminfo`, deliberately, so a binary doesn't hard-depend on a store path for its terminal data. Every one of those four is an FHS or NixOS path, and the `nixos/nix` image populates none of them. The compiled-in search list is complete and every entry on it is empty.

**2. `TERM` is never sent.** `docker exec` builds the new session's environment from the image, not from the terminal you typed the command into. Nothing sets `TERM`, so ncurses uses its built-in `xterm` fallback — a description of a terminal from the 1980s, which is a proper subset of what any modern emulator does. That's the "silently degrades" part: `xterm` is a *valid* description, so nothing errors. It just describes far less than the terminal on the other end can do.

## Solution

**Install the database into the profile** (`home-manager/profiles/dev.nix`):

```nix
packages = [
  pkgs.ncurses
  (lib.hiPrio pkgs.ghostty.terminfo)
];

sessionVariables = {
  TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo";
};
```

**...and forward `TERM` on the way in** (`docker/dev.sh exec`, `just docker-exec`):

```sh
docker exec -it -e TERM="${TERM:-xterm-256color}" "$target" ...
```

Verify both halves inside the container:

```
$ echo $TERMINFO_DIRS
/root/.nix-profile/share/terminfo
$ ls ~/.nix-profile/share/terminfo/x/ | grep xterm-256color
xterm-256color
$ echo $TERM && infocmp -1 "$TERM" >/dev/null && echo ok
```

## Why these choices

**Profile, not devShell.** Terminal capability is a property of the environment, not of whichever repo happens to be mounted at `/work`. A devShell fixes rendering for one project and leaves the login shell — where you actually notice the breakage — untouched.

**Profile, not `~/.terminfo`.** ncurses searches `$HOME/.terminfo`, so dropping entries there works today. The container runs as root today too; a `~/.terminfo` fix would not follow a switch to a non-root user, and a profile-level install would.

**`$HOME/.nix-profile/...`, never a store path.** Exporting `TERMINFO_DIRS=/nix/store/...-ncurses-6.6/share/terminfo` restores rendering immediately, which makes it tempting to commit. Don't: that path changes on every ncurses bump and disappears at the next `nix-collect-garbage`. The profile symlink follows generations, so it survives both.

**`TERMINFO_DIRS` is additive, not a replacement.** ncurses searches `$TERMINFO`, then `$HOME/.terminfo`, then `$TERMINFO_DIRS`, then the compiled-in list. Setting it doesn't shadow the FHS paths — it just gets ahead of them, which matters if this image ever gains a real `/usr/share/terminfo`.

**Plain `ncurses` is enough — there is no `terminfo` output.** nixpkgs' ncurses has `outputs = [ "out" "dev" "man" ]` and the database lands in `$out/share/terminfo`. There is no `ncurses.terminfo` attribute to reach for (the original issue proposed one as a contingency); asking for it is an eval error, not a fallback.

**`ghostty.terminfo` needs `lib.hiPrio`.** ncurses 6.6 ships a `ghostty` entry, but not `xterm-ghostty` — and `xterm-ghostty` is the name Ghostty actually exports (it prefixes with `xterm-` so capability-sniffing programs stop guessing). So the `xterm-ghostty` entry has to come from Ghostty itself. Both packages then also provide `share/terminfo/g/ghostty`, and two files at one path fails the `buildEnv` outright:

```
pkgs.buildEnv error: two given paths contain a conflicting subpath:
  `/nix/store/...-ghostty-1.3.1-terminfo/share/terminfo/g/ghostty' and
  `/nix/store/...-ncurses-6.6/share/terminfo/g/ghostty'
```

This is the **one** collision shape `lib.hiPrio` actually fixes — both files are inside home-manager's own closure, so `buildEnv` is the thing comparing them and `meta.priority` is the thing it compares. It is *not* the base-image collision class that bit `git-minimal` (#34), `man-db` (#60) and `bash` (#74). Those fail one layer up, when `nix-env` unions `home-manager-path` with the base image's profile (`Unable to build profile. There is a conflict for the following files`), where nothing has a priority to compare and `hiPrio` cannot reach; they needed `nix-env -e` in the entrypoint or `package = null` in the module instead. Two similar-sounding errors, two different layers — work out which side of the profile boundary the two files are on before picking a remedy.

**`lib.hiPrio` on `ghostty.terminfo` keeps the output selection.** Worth stating because the lib code reads like it doesn't: `lib.hiPrio` → `addMetaAttrs` → `drv.overrideAttrs`, and `overrideAttrs` returns a whole package, which for a `.terminfo` would mean silently installing the full GTK/zig ghostty instead. It doesn't, because `lib.extendDerivation` gives each output its own `overrideAttrs` that re-selects that output (`f: (passthru.overrideAttrs f).${outputName}`). Verified rather than assumed — `(lib.hiPrio pkgs.ghostty.terminfo)` evaluates to `outputName = "terminfo"`, `outputSpecified = true`, `meta.priority = -10`, and the same `outPath` as the unwrapped output. The distinction matters here more than usual: the wrong answer is a multi-GB closure on a machine that can't take it.

Ghostty's entry winning the tie is also correct on the merits: ncurses' `ghostty` is a third-party description of the terminal (its own comments in `terminfo.src` document capabilities the maintainer could not verify), while `ghostty.terminfo` is generated by the terminal. And because `terminfo` is a real output of the derivation, only that output is substituted — 24 KB, two files, and the zig/GTK closure never fetched or built, which is what makes this affordable on the disk- and CPU-constrained 2012 MBP.

## Verified

Against nixpkgs-unstable, x86_64-linux, outside the container (the flake's own
`homeConfiguration` could not be evaluated here — no network access to the
home-manager input — so this exercises the mechanism, not the activation):

- `pkgs.ncurses.outputs == [ "out" "dev" "man" ]`, `pkgs.ncurses ? terminfo == false`
- `pkgs.ghostty.terminfo` substitutes on its own: 24 KB, `x/xterm-ghostty` + `g/ghostty`
- `pkgs.ncurses` ships `g/ghostty` and no `x/xterm-ghostty` — the overlap and the gap are both real
- `buildEnv [ ncurses ghostty.terminfo ]` fails with the conflicting-subpath error above
- `buildEnv [ ncurses (hiPrio ghostty.terminfo) ]` builds; `g/ghostty` resolves to ghostty's copy, `x/xterm-256color` to ncurses'
- with `TERMINFO_DIRS=<env>/share/terminfo`, `infocmp -1 xterm-ghostty` and `infocmp -1 xterm-256color` both resolve

## Related

- Issue #116
- `Dockerfile` — Troubleshooting block, "colors, scrollback, alt-screen, or Ctrl/Shift+arrow are mangled"
- `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md` — the base-image collision class this one is deliberately *not* an instance of
