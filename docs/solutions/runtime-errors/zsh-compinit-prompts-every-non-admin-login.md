---
title: "zsh compinit prompts on every login for the non-admin account: /etc/zshrc is machine-wide"
date: 2026-08-23
category: runtime-errors
module: darwin/configuration.nix
problem_type: config_error
component: tooling
severity: medium
symptoms:
  - "Every login on a non-admin macOS account prints 'zsh compinit: insecure directories and files, run compaudit for list.' followed by 'Ignore insecure directories and files and continue [y] or abort compinit [n]?' and waits for a keystroke"
  - "compaudit lists /opt/homebrew/share/zsh, /opt/homebrew/share/zsh/site-functions and their _brew/_docker/_orb completion files, plus /nix/var/nix/profiles/default/share/zsh{,/site-functions}"
  - "ls -ld shows the flagged Homebrew directories owned by the admin account (e.g. alyssa:admin, mode 755) - not group-writable, just someone else's"
  - "The account has never run darwin-rebuild or home-manager; it only uses the docker/dev.sh one-liner"
  - "Answering n aborts completion entirely ('compinit: initialization aborted'); answering y works but returns on the next login"
root_cause: config_error
resolution_type: config_change
related_components:
  - darwin_configuration
  - shell
  - development_workflow
tags:
  - zsh
  - compinit
  - compaudit
  - nix-darwin
  - homebrew
  - multi-user
  - macos
---

# zsh compinit prompts on every login for the non-admin account

## Problem

On a Mac where Nix and this flake are owned by the admin account, a *second,
non-admin* account - one that never runs `darwin-rebuild` or `home-manager`,
and reaches the dev environment only through the clone-free bootstrap

```sh
curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/docker/dev.sh | sh -s -- up
```

gets an interactive prompt on every single login, before any container is
involved:

```
Last login: Sat Aug 22 21:15:44 on ttys004
zsh compinit: insecure directories and files, run compaudit for list.
Ignore insecure directories and files and continue [y] or abort compinit [n]?
```

Answering `n` disables completion for the session (`compinit: initialization
aborted`); answering `y` works, and the prompt is back at the next login.

## Why it happens

Two independent facts combine, and both are easy to miss because neither is
visible from the non-admin account.

**1. `/etc/zshrc` is machine-wide, and nix-darwin owns it.**
`programs.zsh.enable = true` in `darwin/configuration.nix` makes nix-darwin
generate `/etc/zshrc`. That file is read by *every* account on the machine,
not just the one that ran `darwin-rebuild`. `programs.zsh.enableCompletion`
defaults to `true`, and `enableGlobalCompInit` defaults to `enableCompletion`,
so the generated file ends with `autoload -U compinit && compinit` for every
interactive zsh on the box. Stock macOS `/etc/zshrc` never calls `compinit` -
which is why the prompt appears the day nix-darwin takes the file over, on an
account that has nothing to do with Nix.

The ordering inside the generated file matters for the fix: nix-darwin emits
`environment.interactiveShellInit`, then `programs.zsh.interactiveShellInit`,
then `promptInit`, and only *then* the `compinit` call.

**2. compaudit rejects directories owned by another user, not just writable
ones.** An `fpath` entry fails the audit if it is group/world-writable **or**
owned by someone other than `root` or the current user - and the entry's
*parent* is checked too, which is why `/opt/homebrew/share/zsh` shows up
alongside `/opt/homebrew/share/zsh/site-functions`.

Both profiles put Homebrew on `FPATH` for everyone:

```nix
# darwin/profiles/shesfast.nix (ditto.nix is the same)
programs.zsh.interactiveShellInit = ''
  eval "$(/opt/homebrew/bin/brew shellenv)"
'';
```

`brew shellenv` prepends `/opt/homebrew/share/zsh/site-functions` to `FPATH`,
and on Apple Silicon the Homebrew prefix belongs to whoever installed it:

```
drwxr-xr-x  40 alyssa  admin  1280 Aug 22 10:28 /opt/homebrew
drwxr-xr-x   3 alyssa  admin    96 Mar 10  2025 /opt/homebrew/share/zsh
drwxr-xr-x  11 alyssa  admin   352 Aug 22 10:32 /opt/homebrew/share/zsh/site-functions
```

Nothing is world- or group-writable there, so Homebrew's usual `chmod go-w`
advice does not apply. The directories are simply owned by *another account*,
and for that account they are supposed to be. The same is true of the shared
nix default profile (`/nix/var/nix/profiles/default/share/zsh`), which
compaudit also flags and which is even less ours to chown.

So the offending directories cannot be fixed in place. Only the shell's
reaction to them can be.

## Fix

Turn off the module's `compinit` and run our own with `-i`:

```nix
# darwin/configuration.nix
programs.zsh = {
  enable = true;
  enableGlobalCompInit = false;
  interactiveShellInit = lib.mkAfter ''
    autoload -U compinit && compinit -i
  '';
};
```

- `-i` is the non-interactive form of answering `y`: insecure directories are
  dropped from `fpath` and completion loads from the rest, with no prompt.
  (`-u`, the other flag, would *trust* them - a directory writable by the
  `admin` group is not something to source functions from unprompted.)
- `enableGlobalCompInit = false` is required because nix-darwin's own
  `compinit` call takes no flags. This is the escape hatch the option
  documents ("can be disabled if the user wants to extend its `fpath` and a
  custom `compinit` call in the local config is required"). It also makes the
  module write `skip_global_compinit=1`, which is inert on macOS.
- `lib.mkAfter` matters: `interactiveShellInit` is `types.lines`, and the
  profiles contribute `brew shellenv` to the same option. Without `mkAfter`
  the merge order is the module import order, and `compinit` could read
  `FPATH` before Homebrew has been added to it.

Accounts that *do* have a home-manager profile run a second `compinit` from
their own `~/.zshrc` (`programs.zsh.enableCompletion`, on by default) - that
was already true before this change and still governs those accounts.

Apply with `darwin-rebuild switch` from the **admin** account; the non-admin
account cannot change anything here, and sees the fix on its next login.

## Alternative considered: gate `brew shellenv` on prefix ownership

The obvious narrower fix is to stop exporting a Homebrew environment the
non-admin user cannot use:

```nix
if [ -O /opt/homebrew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
```

Rejected, for two reasons:

1. It **breaks the documented workflow for exactly that account**. The
   non-admin path in the README depends on a globally-installed OrbStack or
   Docker Desktop from the admin's Homebrew; dropping `/opt/homebrew/bin` from
   `PATH` takes `docker` (and `orb`) with it, and the one-liner stops working.
   The `_docker`, `_orb` and `_orbctl` entries in the compaudit list are that
   same install.
2. It **would not silence the prompt anyway** - the nix default profile is
   flagged independently of Homebrew.

## Reproducing / verifying

From the affected account:

```sh
compaudit                                   # lists the offending dirs
ls -ld /opt/homebrew/share/zsh/site-functions   # shows the other owner
```

After a `darwin-rebuild switch` from the admin account, a fresh login should
print no prompt, and `echo $fpath` should simply not contain the flagged
directories.

## Lesson

Anything set under `programs.zsh.*` in nix-darwin lands in `/etc/zshrc` or
`/etc/zshenv` and runs for **every account on the machine**, including
accounts with no Nix, no home-manager, and no way to opt out. When a machine
has more than one user, system-level shell config has to be written for the
account that owns the least - not for the one running `darwin-rebuild`.
