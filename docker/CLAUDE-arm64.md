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
- This file ships inside the home-manager generation as
  `~/.claude/rules/container-env.md`, so Claude Code loads it in every session
  regardless of what is mounted at `/work`. It updates when the generation
  does - edit it in the dotfiles repo (`docker/CLAUDE-arm64.md`), not here.

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

## Host notes

- The host macOS user may be non-admin: don't suggest `sudo`, Homebrew
  installs, or system-level changes on the host. Host-side needs go through
  Docker Desktop or the user's admin account.
- `! commands` typed in this session run INSIDE the container.

@includes/agents-company-values.md

@includes/agents-personal-constitution-distilled.md

@includes/agents-instructions.private.md

@rules/outbound-comment-gate.md
