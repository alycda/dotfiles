# x86_64-linux devcontainer (e.g. Docker Desktop on the 2012 MBP).
#
# The home-manager closure for alyssa@dev-x86 is built INTO the image (slow,
# once, at build time - network + CPU happen here, not at container start).
# Activation runs at container start instead, so it respects a mounted /root
# volume (Claude/gh auth, ssh, jj state persistence) and the age identity key
# that ragenix needs to decrypt the git config.
#
# Build:  docker build -t dev-x86 .
# Run:
#   docker run -it --rm \
#     -v devhome:/root \
#     -v claude-home:/root/.claude \
#     -v "$PWD":/work -w /work \
#     -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
#     -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
#     dev-x86
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
# Flake updates: rebuild the image (docker build -t dev-x86 .) and keep the
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

# Build the HM generation and root it at a stable path (GC-safe).
# "path:" forces the path fetcher - the image has no git for the git fetcher.
RUN nix build "path:/opt/dotfiles#homeConfigurations.\"alyssa@dev-x86\".activationPackage" -o /opt/hm-activation

ENV PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

# Bake the container-env doc in as Claude's user-level memory, so it applies
# regardless of which project is mounted at /work. At runtime /root/.claude is a
# volume (claude-home) that shadows this baked copy, so the entrypoint re-copies
# it from /opt/dotfiles on every start to keep it current; this COPY just seeds
# a fresh volume and covers runs without the claude-home mount.
COPY docker/CLAUDE.md /root/.claude/CLAUDE.md

WORKDIR /work
ENTRYPOINT ["/opt/dotfiles/docker/entrypoint.sh"]
CMD ["bash", "-l"]
