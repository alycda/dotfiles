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
# Bootstrap from nothing (https clone, no gh/ssh/Nix needed):
#   git clone https://github.com/alycda/dotfiles && cd dotfiles && docker build -t dev .
# Run:
#   docker run -it --rm -v devhome:/root -v claude-home:/root/.claude -v "$PWD":/work -w /work dev
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

FROM nixos/nix:latest

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Outside /root so a mounted home volume can never shadow the flake
COPY . /opt/dotfiles

# TARGETARCH is set by BuildKit (arm64/amd64). The classic builder (Docker
# 20.10 on the 2012 MBP) leaves it empty, which falls through to the x86
# profile - exactly right for that machine. Override the auto-detection with
# --build-arg HM_PROFILE=<name> if you ever need to cross a profile.
ARG TARGETARCH
ARG HM_PROFILE

# Build the HM generation and root it at a stable path (GC-safe).
# "path:" forces the path fetcher - the image has no git for the git fetcher.
# The chosen profile is recorded at /opt/hm-profile for the entrypoint, and
# the matching container-env doc is baked in as Claude's user-level memory so
# it applies regardless of which project is mounted at /work. At runtime
# /root/.claude is a volume (claude-home) that shadows the baked copy, so the
# entrypoint re-copies it on every start to keep it current; this seed covers
# a fresh volume and runs without the claude-home mount.
RUN profile="${HM_PROFILE:-$(case "$TARGETARCH" in arm64) echo 'alyssa@dev';; *) echo 'alyssa@dev-x86';; esac)}" \
 && nix build "path:/opt/dotfiles#homeConfigurations.\"$profile\".activationPackage" -o /opt/hm-activation \
 && echo "$profile" > /opt/hm-profile \
 && mkdir -p /root/.claude \
 && case "$TARGETARCH" in \
      arm64) cp /opt/dotfiles/docker/CLAUDE-arm64.md /root/.claude/CLAUDE.md ;; \
      *)     cp /opt/dotfiles/docker/CLAUDE.md       /root/.claude/CLAUDE.md ;; \
    esac

ENV PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

WORKDIR /work
ENTRYPOINT ["/opt/dotfiles/docker/entrypoint.sh"]
CMD ["bash", "-l"]
