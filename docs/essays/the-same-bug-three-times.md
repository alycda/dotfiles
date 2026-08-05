---
title: The same bug, three times
date: 2026-08-05
filed_under:
  - nix
  - home-manager
  - devcontainer
excerpt: >-
  A bug you fix once is an incident. A bug you fix three times is a category
  error about where the boundary of your configuration is.
concepts:
  - Base profile
  - User environment
  - Activation
  - Closure
further_reading:
  # `path` is a Zola-internal reference resolved at build time, so it survives
  # a change of base_url; `url` is for anything off-site.
  - text: home-manager's bash collides with the base image's bash
    path: "@/solutions/home-manager-bash-collides-with-base-image-profile.md"
    note: the third instance, written up in full
  - text: Home Manager options
    url: https://nix-community.github.io/home-manager/options.xhtml
    note: for checking whether a `programs.*` module ships a package
---

Three times now, this repo has broken in exactly the same way, and three times
I have been surprised by it. Once over `git-minimal`, once over `man-db`, once
over `bash`. Each time the container came up looking almost fine — prompt
rendered, dotfiles in place — and each time `which claude` came back empty.

The interesting thing is not the bug. The interesting thing is that fixing it
twice did not stop it from happening a third time, which means what I had was
not a bug but a wrong mental model that kept producing one.

## What I thought the boundary was

I thought of my configuration as a thing with edges. Home-manager describes a
set of packages; that set gets built; the build either succeeds or it does not.
A green `nix build` meant a working machine. The failure mode I was watching for
was *my config is wrong*.

But the container does not start from nothing. The upstream image arrives with
its own populated profile — the {{ e(name="Base profile") }} — and that profile
is not empty and not inert. Every program in it competes for the same names as
the packages home-manager installs. The thing that actually has to work is not
my closure. It is the union of my closure with somebody else's, computed on a
machine I am not looking at, at a moment I am not present for.

> A green build does not catch these: the profile union is computed at
> activation time on the target machine.

That sentence is now in CLAUDE.md, and it is the whole lesson compressed. The
{{ e(name="User environment") }} is where the collision happens, and it is
assembled during {{ e(name="Activation") }} — after the build has already
reported success.

## Why the obvious fix does not generalise

The first instinct is `lib.hiPrio`: mark my version as the winner and move on.
It does not work, and understanding why it does not work is the part that
actually transfers.

Priority resolves collisions *inside* a {{ e(name="Closure") }} as it is
assembled. But once that closure is built, it becomes one opaque element in the
user environment, sitting alongside the base profile's elements. A priority set
inside an element is invisible from outside it. Two elements providing the same
file path are a hard error, not a precedence question.

So there is no single fix. There are three, and which one is right depends on
who actually needs the program:

| If | Then |
|---|---|
| You wanted the module's *config*, not its package | `programs.<x>.package = null` |
| Home-manager's version is genuinely required | remove the base copy at the entrypoint |
| The collision is inside your own closure | `lib.hiPrio` |

The third row is the one I kept reaching for first, and it is the one that
applies least often.

## The part I keep relearning

Each fix was correct. Each fix was also local — it addressed the package that
happened to collide that week, and left the shape of the problem untouched. The
base image can add an entry on any refresh, which means the next collision
arrives without any change to this repo at all. Nothing in my config changed;
the ground moved.

What finally helped was not a better fix but a better name. Calling the base
profile "the hazard surface" in {{ e(name="Base profile") }} made it a thing I
could think about in advance rather than diagnose in retrospect. It is much
harder to be surprised three times by something you have named.
