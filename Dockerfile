# Linux devcontainer image (x86_64 AND aarch64 - e.g. Docker Desktop on the
# 2012 MBP, or on an Apple Silicon Mac where you can't/won't install Nix,
# such as a non-admin macOS user).
#
# The home-manager closure is built INTO the image (slow, once, at build
# time - network + CPU happen here, not at container start). The profile is
# picked by CPU architecture: arm64 builds alyssa@dev (aarch64-linux), amd64
# builds alyssa@dev-x86. Activation runs at container start instead, so it
# respects a mounted /root volume (Claude/gh auth, ssh, jj state persistence)
# and the age identity key that ragenix needs to decrypt the git config.
#
# Bootstrap from nothing (no gh/ssh/Nix/git needed - Docker fetches the repo
# itself via BuildKit's remote build context):
#   docker build -t dev https://github.com/alycda/dotfiles.git
# ...or from a local clone:
#   git clone https://github.com/alycda/dotfiles && cd dotfiles && docker build -t dev .
# Run:
#   docker run -it --rm -e TERM="$TERM" -v devhome:/root -v claude-home:/root/.claude -v "$PWD":/work -w /work --network host dev
# Second (third, nth) shell into a container that is already running:
#   ./docker/dev.sh exec          # or: just docker-exec
#
# `-e TERM` is not optional garnish. Whenever docker allocates a tty it puts
# `TERM=xterm` in the environment itself - on run and on exec - so without it
# you get a valid 1980s terminal description instead of yours, and every TUI
# renders subtly wrong without erroring. Prefer ./docker/dev.sh run and
# ./docker/dev.sh exec, which pass it for you; see the TERM entry under
# Troubleshooting. Setting it on `run` also covers a later hand-written
# `docker exec`, which inherits the container's env over docker's xterm default.
#
# Optional extras for the run command (append before the image name):
#   SSH agent forwarding (Docker Desktop for Mac):
#     -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
#     -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
#
# claude-home keeps Claude's auth (~/.claude/.credentials.json) and config in
# its own volume, nested under the devhome mount. This decouples your login from
# devhome, so resetting the nix profile (or doing `docker volume rm devhome`)
# never logs you out. Note: the host's old Claude predates .credentials.json, so
# there's nothing to seed from it - you authenticate once inside the container
# and claude-home remembers it.
#
# Do NOT mount a named volume over /nix. The store is baked into the image and
# used directly. Mounting a volume there makes Docker copy the whole ~10GB
# closure into it on first run (doubling disk use on the 2012 MBP), and a stale
# volume left over from an earlier build shadows /nix with mismatched store
# paths - which breaks the /bin/sh symlink and fails at container start with:
#   exec /opt/dotfiles/docker/entrypoint.sh: no such file or directory
#
# Ragenix identity (optional): the git-config secret is decrypted at activation
# by the age key. If the key is absent, activation prints a warning and the
# shell still starts - you just won't have the decrypted git identity, which is
# fine for read-only / exploratory work. The key does NOT live on every machine;
# grab it from one that has ~/.age/personal-key.txt (e.g. scp it to this host
# first), then copy it into the running container's devhome volume:
#   docker exec <container> mkdir -p /root/.age
#   docker cp ./personal-key.txt <container>:/root/.age/personal-key.txt
# It persists in devhome across --rm; exit and re-run to re-activate with it.
#
# Flake updates: rebuild the image (docker build -t dev .) and keep the
# devhome volume. The entrypoint re-activates only when the home profile is
# missing or stale.
#
# Troubleshooting:
#   "cannot attach stdin to a TTY-enabled container because stdin is not a
#     terminal" - `docker run -it` was invoked from a process whose stdin is a
#     pipe, not a tty (classically `curl ... | sh`, where the script inherits
#     the curl pipe on fd 0). The image built fine; only the run failed. Add
#     `< /dev/tty` to the docker run command to hand it the controlling
#     terminal - docker/dev.sh does this for you (PR #86), so prefer it over a
#     hand-written docker run when bootstrapping through a pipe. Full write-up:
#     docs/solutions/runtime-errors/curl-piped-dev-sh-cannot-attach-stdin-to-tty.md
#   "no space left on device" - Docker Desktop's disk is full. Reclaim with
#     docker image prune          # drops dangling images (e.g. old dev-x86 builds)
#     docker builder prune        # drops stale build cache
#     docker volume rm nix-store  # remove any leftover /nix volume from old runs
#   activation "conflict ... git-minimal ... info/exclude" - the base image
#     ships git-minimal in root's profile and it collides with home-manager's
#     full git. The entrypoint now removes it before activating; a devhome that
#     predates that fix can be cleared with (the age key survives):
#       docker run --rm -v devhome:/root alpine \
#         sh -c 'rm -rf /root/.local/state/nix /root/.nix-profile /root/.nix-defexpr'
#     Same signature, same fix, different package: "... man-db ... bin/accessdb"
#     on newer/arm64 base images. Both are in the entrypoint's removal list.
#   activation "conflict ... bin/bash" - LOOKS like the two above, is NOT fixed
#     the same way. bash cannot be removed from the base profile: it is root's
#     login shell in /etc/passwd and what /bin/sh resolves through. The fix is
#     config-side - `programs.bash.package = null` in home-manager/profiles/
#     dev.nix takes the module's config without its binary. If you hit this on a
#     new package, decide by asking whether home-manager needs to *provide* the
#     program or only configure it. See
#     docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md
#   colors, scrollback, alt-screen, or Ctrl/Shift+arrow are mangled - TERM, not
#     tmux, and not cmux either (that misattribution is what made issue #116
#     take a while). Two independent halves, both were missing:
#     (a) the entries. `nixos/nix` populates none of the FHS paths ncurses
#         searches (/etc/terminfo, /lib/terminfo, /usr/share/terminfo), so a
#         container built before #116 has no terminfo database reachable at all
#         - ncurses is in the closure only as a transitive dep. Rebuild the
#         image to pick up the profile-level ncurses + ghostty.terminfo in
#         home-manager/profiles/dev.nix. Check:
#           echo $TERMINFO_DIRS                     # ~/.nix-profile/share/terminfo
#           ls ~/.nix-profile/share/terminfo/x/ | grep xterm-256color
#     (b) the TERM value. Docker supplies `TERM=xterm` itself whenever it
#         allocates a tty - both `docker run -it` and `docker exec -it` - so
#         this is not an unset variable you can spot, it is a wrong one that
#         looks deliberate. An explicit -e TERM overrides it. Use
#         ./docker/dev.sh run and ./docker/dev.sh exec, which pass
#         -e TERM="$TERM" on both. Check, inside the container:
#           echo $TERM && infocmp -1 "$TERM" >/dev/null && echo ok
#         If that prints `xterm` on a host running anything else, the container
#         was started without -e TERM: restart it via dev.sh (or add the flag).
#     Do NOT "fix" this by exporting a /nix/store/...-ncurses-6.6/share/terminfo
#     path: it works, and it dies at the next ncurses bump or GC.
#   container starts, prompt looks perfect, but claude/jj/rg are "command not
#     found" - this is NOT a PATH problem. It is a failed activation: file
#     linking runs before package installation, so the dotfiles land and
#     home-manager-path never installs. Scroll up to the activation output and
#     read the tail; the real error is buried above a wall of success lines.

FROM nixos/nix:latest

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Outside /root so a mounted home volume can never shadow the flake. This layer
# is the cache key for the nix build below, so .dockerignore keeps everything
# the flake does not read (docs, .git/.jj, editor config) out of the context.
COPY . /opt/dotfiles

# The profile is picked by asking the build container itself (uname -m), NOT
# BuildKit's TARGETARCH: the legacy builder never sets TARGETARCH (it's still
# what a fresh non-admin macOS user gets - buildx CLI plugins live per-user in
# ~/.docker/cli-plugins - and it's all Docker 20.10 on the 2012 MBP has), and
# an empty TARGETARCH here would silently build the x86 closure on an arm64
# host. uname -m runs in the target platform's container under both builders,
# so it's always the truth. Override with --build-arg HM_PROFILE=<name> if
# you ever need to force a profile.
ARG HM_PROFILE

# Build the HM generation and root it at a stable path (GC-safe).
# "path:" forces the path fetcher - the image has no git for the git fetcher.
# The chosen profile is recorded at /opt/hm-profile for the entrypoint.
#
# The per-arch container-env doc is NOT copied here. It ships inside the
# generation as ~/.claude/rules/container-env.md (home-manager/profiles/dev.nix
# selects the arch), which Claude Code loads into every session regardless of
# which project is mounted at /work. Putting it in the generation means the
# claude-home volume can't shadow a stale copy and the entrypoint has nothing
# to re-copy - the doc updates exactly when the generation does.
RUN arch="$(uname -m)" \
 && profile="${HM_PROFILE:-$(case "$arch" in aarch64) echo 'alyssa@dev';; *) echo 'alyssa@dev-x86';; esac)}" \
 && nix build "path:/opt/dotfiles#homeConfigurations.\"$profile\".activationPackage" -o /opt/hm-activation \
 && echo "$profile" > /opt/hm-profile

ENV PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

WORKDIR /work
ENTRYPOINT ["/opt/dotfiles/docker/entrypoint.sh"]
# Land in zsh, not bash. home-manager configures zsh (starship, direnv, fzf
# widgets, the tv Ctrl+R binding) and configures bash only as a fallback - but
# this used to be `bash -l`, so none of that zsh config was ever sourced and the
# prompt was a bare `bash-5.3#` (issue #15).
#
# Guarded rather than a plain ["zsh", "-l"]: zsh comes from the home-manager
# profile, which the entrypoint activates just before exec'ing this. If that
# activation fails (the usual cause is a missing ragenix identity - the
# entrypoint prints recovery instructions for it), zsh does not exist, and an
# unguarded exec would kill the container instantly - right when you need a
# shell to fix it. Falling back to bash keeps those instructions actionable.
CMD ["sh", "-c", "if command -v zsh >/dev/null 2>&1; then exec zsh -l; else exec bash -l; fi"]
