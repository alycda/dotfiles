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
#     -v nix-store:/nix \
#     -v devhome:/root \
#     -v "$PWD":/work -w /work \
#     -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
#     -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
#     dev-x86
#
# First run only: give ragenix its identity so git-config decrypts -
#   docker cp ~/.age/personal-key.txt <container>:/root/.age/personal-key.txt
# (it lands in the devhome volume, so it survives --rm)
#
# Flake updates: rebuild the image, keep the volumes. The named nix-store
# volume means rebuilt layers share /nix paths already present, and the
# entrypoint re-activates only when the home profile is missing or stale.

FROM nixos/nix:latest

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Outside /root so a mounted home volume can never shadow the flake
COPY . /opt/dotfiles

# Build the HM generation and root it at a stable path (GC-safe).
# "path:" forces the path fetcher - the image has no git for the git fetcher.
RUN nix build "path:/opt/dotfiles#homeConfigurations.\"alyssa@dev-x86\".activationPackage" -o /opt/hm-activation

ENV PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH
WORKDIR /work
ENTRYPOINT ["/opt/dotfiles/docker/entrypoint.sh"]
CMD ["bash", "-l"]
