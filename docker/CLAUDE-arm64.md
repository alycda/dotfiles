# Machine: Apple Silicon Mac via Docker container

Claude Code runs inside an aarch64-linux container (image: `dev`, built with
`docker build -t dev .` from the dotfiles repo) on an Apple Silicon Mac. This
image exists so a macOS user account with NO admin rights and NO Nix install
(git clone over https, curl, and docker are the only tools) still gets the
full home-manager environment: the `alyssa@dev` closure is baked into the
image and activated at container start. Dotfiles:
https://github.com/alycda/dotfiles (its `Dockerfile` covers the build).

There are no hardware or software ceilings here: the host is modern, the CPU
is fast, and current Linux tooling runs natively. If you come across
`docker/CLAUDE.md` in the dotfiles repo (e.g. under `/opt/dotfiles`), ignore
it - it describes a different machine entirely (a frozen 2012 MacBook Pro:
OOM pressure, no AVX2, slow bind mounts, old-software ceilings) and none of
its constraints apply to this container.

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

@includes/agents-company-values.md

@includes/agents-personal-constitution-distilled.md

@includes/agents-instructions.private.md

@rules/outbound-comment-gate.md
