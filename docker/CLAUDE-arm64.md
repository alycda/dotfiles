# Machine: Apple Silicon Mac via Docker container

Claude Code runs inside an aarch64-linux container (image: `dev`, built with
`docker build -t dev .` from the dotfiles repo) on an Apple Silicon Mac. This
image exists so a macOS user account with NO admin rights and NO Nix install
(git clone over https, curl, and docker are the only tools) still gets the
full home-manager environment: the `alyssa@dev` closure is baked into the
image and activated at container start. Dotfiles:
https://github.com/alycda/dotfiles (its `Dockerfile` covers the build).

Unlike the x86 sibling doc (`docker/CLAUDE.md`, a frozen 2012 MacBook Pro),
there are no hardware or software ceilings here: the host is modern, the CPU
is fast, and current Linux tooling runs natively. Do not assume the 2012
MBP's constraints (OOM pressure, no AVX2, slow bind mounts) apply.

## Layout and persistence

- `/work` is a bind mount of the host directory you started from (VirtioFS -
  fast, inotify works). The repo/project you're editing lives here.
- `/root` is the `devhome` named volume: nix profile state, ssh, jj state
  survive `--rm`.
- `/root/.claude` is the `claude-home` named volume, nested inside devhome so
  Claude auth (`.credentials.json`) survives a devhome reset. Authenticate
  once inside the container (`claude` → login, `gh auth login`) and it
  persists.
- The Nix store is baked into the image; never mount a volume over `/nix`.
- This file is re-copied from `/opt/dotfiles/docker/CLAUDE-arm64.md` on every
  container start - edit it in the dotfiles repo, not here.

## Host notes

- The host macOS user may be non-admin: don't suggest `sudo`, Homebrew
  installs, or system-level changes on the host. Host-side needs go through
  Docker Desktop or the user's admin account.
- `! commands` typed in this session run INSIDE the container.
