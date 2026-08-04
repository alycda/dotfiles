# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Dev container

### Baked generation
The home-manager generation built into the dev image at image-build time. The container entrypoint re-activates it only when the volume's home profile is missing or its active generation differs — so hand-activated generations inside a running container are ephemeral, and the baked generation is what every restart converges back to.

### Devhome volume
The persistent home volume of the dev container. It survives container removal and recreation, which also means it can shadow home content baked into the image; the entrypoint reconciles the two at start.

### Claude-home volume
A volume nested inside the devhome volume that isolates Claude Code's authentication and state. Its reason for existing is survival: resetting the devhome volume must not log Claude out.

### Base profile
The package set the upstream Nix base image already installed into root's user environment, independent of anything this repo declares. It is not empty and not inert: every program in it competes for the same names as the packages home-manager installs, so it is the hazard surface for activation collisions. Each refresh of the base image can add a new entry, which is why a collision can appear without any change to this repo.

## Home-manager

### Profile
A named composition of modules describing one machine or context — a work laptop, a personal laptop, the dev container. Profiles select and combine modules; they are the unit a build or switch is named after. Distinct from a *user environment*, which is what the resulting packages get installed into.

### Module
A reusable unit of configuration that profiles import. Modules are the shared layer: a change to one reaches every profile that imports it, including the container, which is why a module-level addition is the riskiest place to introduce a package.

### User environment
The merged symlink tree that becomes the active set of installed programs, assembled by unioning every installed element — the base profile's packages and home-manager's package set alike. The union is computed at activation time on the target machine, not at build time, so it can fail on a machine even when the configuration builds cleanly everywhere. Two elements that provide the same file path are a hard error, not a precedence question.

### Activation
The process that makes a generation live. It runs in ordered stages, and in practice the stage that links files runs before the stage that installs packages — so a failed activation can leave a machine with correct dotfiles and none of its tools. Activation is non-fatal by design in the container: the entrypoint reports the failure and still starts a shell.

## Flagged ambiguities

- *Profile* had been used for both a home-manager profile (a composition of modules, as in this repo's profiles) and a Nix profile (the installed-package tree, as in the base profile). These are distinct, and conflating them hides the fact that packages from both a Nix profile and a home-manager profile land in the same *user environment*.
