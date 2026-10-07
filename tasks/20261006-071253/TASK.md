# The Docker image runs as a non-root user

- STATUS: OPEN
- TAGS: docker, nix, home-manager, security

## Description

From the review of #208 (0.1.5), on `Dockerfile:33` (`ARG HM_PROFILE`,
`ENV USER=root`): don't run as root. Today the image builds and activates
the `root@<arch>-linux` home-manager profile, and `docker run` starts zsh as
root with the host's directory mounted at `/work`.

What the base image (`nixos/nix:latest`, checked 2026-10-06) gives to work
with:

- Single-user Nix, everything under `/nix` owned by root, and
  `build-users-group = nixbld`, `sandbox = false` in `/etc/nix/nix.conf`.
- No `useradd`, `adduser`, `su`, `sudo` or `setpriv`. A user means writing
  `/etc/passwd` and `/etc/group` by hand.

A plan (not tried):

- **Step 1.** Add `dotfiles@aarch64-linux` and `dotfiles@x86_64-linux` to
  `homeConfigurations` (`mkHome system "dotfiles" "/home/dotfiles"`).
  `root@*` are used only by the Dockerfile, so they can go.
- **Step 2.** In the Dockerfile, before `COPY . /opt/dotfiles` (so the cache
  survives edits): append the user to `/etc/passwd` and `/etc/group` (uid
  and gid 1000, shell from the store), create `/home/dotfiles`, and
  `chown -R 1000:1000 /nix /home/dotfiles`. Nix then runs single-user as
  that account, the usual no-daemon install.
- **Step 3.** `USER dotfiles`, `ENV USER=dotfiles`, then build and activate
  as that user. The `nix-env -e man-db` step goes: it only cleared root's
  profile.
- **Step 4.** `ENV PATH=/home/dotfiles/.nix-profile/bin:$PATH`, and update
  the comments that name `/root` (lines 12, 23, 29).
- **Step 5.** README and CHANGELOG: the image's user. The 0.1.5 changelog
  says nothing about root today, so this may be a new line rather than a
  change.

## Open questions

- The user's name: `dotfiles` assumed. `vscode` would reuse the existing
  `vscode@*` profiles with no flake change, but the image isn't for VS Code
  (the Dockerfile says so).
- `chown -R /nix` copies the base image's store into a new layer, roughly
  doubling it. Acceptable, or find a way around it (a multi-stage build that
  copies only the closure, or running nix-daemon during the build)?
- `/work` is the host's directory. On macOS (OrbStack, Docker Desktop) file
  sharing maps ownership, so uid 1000 can write there. On a Linux host with
  another uid it can't. Pass `--user "$(id -u):$(id -g)"` in `docker-run`, or
  accept it?
- In 0.1.5 (this PR), or a later version? Assumed later: #208's other review
  comments are done without it.

## Verification

Not started. To check when it's done:

- `just docker-build` on arm64 (OrbStack here) and, in CI or a Linux VM,
  amd64.
- In `just docker-run`: `id -u` is 1000, `$USER` and `$HOME` are the new
  user's, zsh has `tools/zsh/interactive.zsh` (`[[ -o autocd ]]`), and `jj`,
  `just`, `hx` and `tb` run.
- A file created under `/work` is writable and owned as expected on the
  host.
- `docker image ls dotfiles` before and after: the size cost of the chown.
