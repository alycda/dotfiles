# tart ships only on the desktop darwin profiles (home.nix, work.nix), pinned to
# 2.34.0 in lib/tart.nix. These recipes are parsed everywhere the global
# justfile is installed and simply fail when invoked without tart on PATH --
# same deal as the docker recipe in personal.just.

# image is the middle of macos-<image>-base: golden-gate, tahoe, sequoia
#
# clone a cirruslabs macOS base and size it for a nix-darwin validation run
[group('tart')]
tart-new name image='golden-gate' cpu='6' memory='12288' disk='90':
    tart clone ghcr.io/cirruslabs/macos-{{image}}-base:latest {{name}}
    tart set {{name}} --cpu {{cpu}} --memory {{memory}} --disk-size {{disk}}

# ssh into a running VM (cirruslabs base images: admin / admin)
[group('tart')]
tart-ssh name:
    ssh admin@$(tart ip {{name}})

# stop and delete a VM; the leading - tolerates an already-stopped VM
[group('tart')]
tart-rm name:
    -tart stop {{name}}
    tart delete {{name}}

# evict cached OCI layers not accessed in N days (bare integer, "30d" is rejected)
[group('tart')]
tart-prune days='30':
    tart prune --entries caches --older-than {{days}}
