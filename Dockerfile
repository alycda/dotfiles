# A Linux image with this flake's home-manager generation built in and
# activated, for `docker run` on a machine without Nix (e.g. a Mac account
# with no admin rights). arm64 and amd64: the profile is picked by the build
# container's own `uname -m`.
#
#   docker build -t dotfiles .        # or: just docker-build
#   docker run -it --rm -e TERM="$TERM" -v "$PWD":/work dotfiles
#                                     # or: just docker-run
#
# The generation is built and activated here, at build time, so the
# container starts straight into zsh. Rebuild the image to pick up a change
# to the flake. Don't mount a volume over /root or /nix: both hold the
# activated generation.
#
# This image is for `docker run`, not VS Code: the devcontainers use Debian
# (.devcontainer.json, .devcontainer/mise/). Opening this one as a
# devcontainer needs more than it has, such as an FHS loader for VS Code
# Server's node.
FROM nixos/nix:latest

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Outside /root, so the flake can't be shadowed. Every file copied here is a
# cache key for the build below; .dockerignore keeps out what the flake does
# not read.
COPY . /opt/dotfiles

# `path:` because the copy has no .git for Nix's git fetcher. The base
# image's root profile has man-db, which collides with home-manager's man
# when the generation is installed, so it goes first. git stays: jj and
# direnv's `use flake` need it. HM_PROFILE overrides the profile.
ARG HM_PROFILE
ENV USER=root
RUN profile="${HM_PROFILE:-root@$(uname -m)-linux}" \
  && nix build "path:/opt/dotfiles#homeConfigurations.\"$profile\".activationPackage" -o /opt/hm-activation \
  && nix-env -e man-db \
  && HOME_MANAGER_BACKUP_EXT=backup /opt/hm-activation/activate

ENV PATH=/root/.nix-profile/bin:$PATH
WORKDIR /work
CMD ["zsh", "-l"]
