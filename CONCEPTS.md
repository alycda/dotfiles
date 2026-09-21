# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Dev container

### Dev image
The container image this repo builds to serve as a complete development environment, with the home-manager closure built in at image-build time rather than installed when a container starts.

Its filesystem is a Nix store rather than a conventional Unix layout: the standard library and system-binary directories are absent, and several configuration files that do sit in the usual place are symlinks pointing into the store. This is load-bearing rather than incidental. External tooling that assumes a conventional layout fails against this image while working normally everywhere else — prebuilt binaries that expect a system dynamic linker, and host-side path resolution that refuses to follow a symlink out of its parent directory, are the two recurring shapes. Such failures characteristically report something other than the layout, so the reported error is rarely the place to start.

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

### Generation
A complete, immutable snapshot of what one profile evaluates to at a point in time. Generations are addressable and switchable rather than overwritten: making a new one current leaves the previous one intact on disk, which is why going back is a switch rather than a restore.

### Closure
The full set of packages something transitively depends on, assembled into one tree. The distinction that matters in practice is closure versus user environment: two packages can collide *inside* a single closure as it is assembled, or *between* separately installed elements of a user environment. Priority settings resolve the first kind and cannot reach the second — a priority set on a package inside a closure is invisible once that closure is one opaque element among others.

### User environment
The merged symlink tree that becomes the active set of installed programs, assembled by unioning every installed element — the base profile's packages and home-manager's package set alike. The union is computed at activation time on the target machine, not at build time, so it can fail on a machine even when the configuration builds cleanly everywhere. Two elements that provide the same file path are a hard error, not a precedence question.

### Activation
The process that makes a generation live. It runs in ordered stages, and in practice the stage that links files runs before the stage that installs packages — so a failed activation can leave a machine with correct dotfiles and none of its tools. Activation is non-fatal by design in the container: the entrypoint reports the failure and still starts a shell.

## Agent instructions

### Public layers
The agent-instruction files that are safe to publish and are tracked in the repo — entrypoint, preferred tooling, company values, persona. They reach every agent surface as local files written by home-manager activation, not fetched from a URL at runtime.

### Private overlay
The encrypted agent-instruction layer, decrypted by agenix only on machines holding the identity key. It is ordered last in the managed import block, so it is authoritative on conflict with the public layers — and it may legitimately dangle on a machine without the key, which consumers tolerate by skipping the unresolvable import rather than failing.

## Sharing

### Slug
The opaque random identifier that names one published upload and stands in for access control. Note this inverts the usual meaning: a slug here is deliberately *unreadable*, because unguessability is the only thing keeping a private object private — the bucket is never public and content is reached solely through time-limited signed URLs.

A slug is stable and reusable: republishing to an existing slug replaces its content in place, so a link already shared keeps working. Uploads are ephemeral by default, expiring through a storage lifecycle rule unless explicitly published as permanent; permanence governs how long the *object* survives, which is independent of how long any signed URL for it remains valid.

## Cross-cutting

### Drift
Divergence between committed source and a derived artifact that should faithfully reflect it — a built image carrying uncommitted state, a runtime config with no source of record, or a stale pin emitting flags newer tools reject. Runtime state that cannot be traced to a commit is drift to be committed or filed, never adopted as truth.

## Flagged ambiguities

- *Profile* had been used for both a home-manager profile (a composition of modules, as in this repo's profiles) and a Nix profile (the installed-package tree, as in the base profile). These are distinct, and conflating them hides the fact that packages from both a Nix profile and a home-manager profile land in the same *user environment*.
