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

## Troubleshooting startup

The one failure worth recognising on sight, because it does not look like what
it is:

- **Prompt renders fine, but `claude` / `jj` / `rg` are "command not found".**
  This is NOT a `PATH` problem, and no amount of inspecting `PATH` will explain
  it. home-manager activation failed: file linking runs *before* package
  installation, so the dotfiles landed (hence the working prompt) while
  `home-manager-path` never installed. Scroll up to the activation output and
  read its tail - the error sits under a wall of success lines. The entrypoint
  deliberately does not abort on activation failure, which is why you get a
  shell at all.
- **The usual cause is a package collision.** The base image ships its own
  populated `nix-env` profile, and anything home-manager installs can clash
  with a package already in it (`Unable to build profile. There is a conflict
  for the following files`). Confirm with `nix-env -q` - that list is the
  hazard surface. Some are stripped at the entrypoint; `bash` deliberately is
  not, because it is root's login shell. Full decision rule:
  `docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md`
- **Recovery is a rebuild, not a repair.** Fix the config in the repo, rebuild
  the image, and start a container; the entrypoint re-activates when the baked
  generation differs from the volume's. Do not hand-patch the profile inside a
  running container - the baked generation is what every restart converges back
  to, so the patch evaporates.
- If activation instead complains about age/agenix, the ragenix identity is
  missing - the entrypoint prints the `docker cp` recovery command.

## Terminal

Terminal capability lives in the profile now, not in the image's FHS paths
(which `nixos/nix` leaves empty): `ncurses` plus `ghostty.terminfo` are in
`home.packages`, and `TERMINFO_DIRS` points at
`~/.nix-profile/share/terminfo`. `infocmp` and `tic` are on `PATH`, so a
terminal question is answerable rather than guessable.

The other half is the `TERM` *value*, and it is not a missing variable - it is
a wrong one. Whenever docker allocates a tty it puts `TERM=xterm` in the
environment itself, on `docker run -it` and `docker exec -it` alike, so you
land on a valid 1980s description and everything mis-renders quietly: wrong
colors, broken alt-screen and scrollback, Ctrl/Shift+arrow arriving as escape
garbage. An explicit `-e TERM` overrides it. Use `./docker/dev.sh run` and
`./docker/dev.sh exec` (or `just docker-run` / `just docker-exec`), which pass
it on both. If rendering still looks wrong, check `echo $TERM` and
`infocmp -1 "$TERM"` before blaming tmux - that misattribution is what made
issue #116 take a while; `xterm` there means this container was started without
the flag. Never paste a `/nix/store/...-ncurses-*/share/terminfo` path into
`TERMINFO_DIRS` as a fix; it works until the next ncurses bump or GC.

## Host notes

- The host macOS user may be non-admin: don't suggest `sudo`, Homebrew
  installs, or system-level changes on the host. Host-side needs go through
  Docker Desktop or the user's admin account.
- `! commands` typed in this session run INSIDE the container.

@includes/agents-company-values.md

@includes/agents-personal-constitution-distilled.md

@includes/agents-instructions.private.md

@rules/outbound-comment-gate.md
