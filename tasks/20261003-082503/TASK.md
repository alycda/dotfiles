# Install agenix secrets when the Docker container starts

- STATUS: CLOSED
- TAGS: agenix, secrets, docker

## Description

The Dockerfile builds the home-manager generation and activates it at build
time, so the container starts straight into zsh. Activation is also when
agenix secrets install (`home-manager/agenix.nix`), and at build time there is
no identity: the build warns `could not decrypt` for each secret, and the
image ships without them. A container started from it never gets them either.
Install them at start, from an identity mounted read-only.

Do this together with the first real secret, so there is something to check
end to end; `secrets/example.age` alone proves only the plumbing.

### What to change

1. **An entrypoint** that re-runs activation at start when an identity is
   mounted, then execs the command:

   ```sh
   #!/bin/sh
   # Install agenix secrets (and anything else activation does) now that an
   # identity may be mounted; the build had none.
   if [ -r /root/.age/personal-key.txt ]; then
     HOME_MANAGER_BACKUP_EXT=backup /opt/hm-activation/activate >/dev/null
   fi
   exec "$@"
   ```

   Re-running the whole activation is simpler than extracting the agenix
   step, and it is idempotent. Time it: if it is slow, run only when the
   secrets are missing or older than the generation.

2. **The Dockerfile**: `ENTRYPOINT ["/opt/dotfiles/<path>/entrypoint.sh"]`,
   keeping `CMD ["zsh", "-l"]`. Put the script where the flake does not read
   it, or every edit rebuilds the generation; `.dockerignore` must still let
   it into the context.

3. **`just docker-run`**: mount `~/.age` read-only when it exists:
   `-v "$HOME/.age":/root/.age:ro`. Without it, the container still starts,
   with no secrets.

### Lessons from the old dotfiles repo's image

- It activated at start too, from `docker/entrypoint.sh`. An unconditional
  copy before a conditional activation once clobbered files the activation
  had written; keep the entrypoint to activation and `exec`.
- Activation must never stop the container: if it fails, still `exec` the
  shell, so there is a shell to fix it from.
- Don't mount a volume over `/root` or `/nix`: both hold the activated
  generation (the Dockerfile header says so).
- VS Code Dev Containers overrides `ENTRYPOINT`; that does not matter here,
  since this image is for `docker run` only.

### Before starting, on the host

The key at `~/.age/personal-key.txt` has no trailing newline and is readable
by every user. Fix both: `echo >> ~/.age/personal-key.txt` and `chmod 600`.
Decryption works either way; `just edit-secret` needs the newline.

### What was built

As planned, with two changes:

- The entrypoint is a heredoc `COPY` in the Dockerfile, after the
  generation is built, not a file from the context. Any file `COPY .` copies
  is a cache key for the generation, so a script in the context would
  rebuild it on every edit; `.dockerignore` can't both let it in and keep it
  out of that copy. Editing the heredoc reruns only the last layers (1s).
- Activation's output goes to `/tmp/activation.log`, not the terminal: nix
  prints "replacing old 'home-manager-path'" on stderr at every start. The
  entrypoint shows only the `agenix:` lines, and a one-line pointer to the
  log if activation fails.

`just docker-run` mounts `~/.age` read-only only when the host has it
(`path_exists`), so a host with no key runs as before.

## Open questions

- Re-activate on every start, or only when a secret is missing? Every
  start: it costs nothing measurable (below).
- Secrets in the container only, or in a named volume? Container only:
  re-decrypted at each start, nothing left behind after `--rm`.
- No real secret exists yet; `secrets/example.age` proves the path end to
  end. A real one changes nothing here.

## Verification

Done, on 2026-10-04 (OrbStack 29.4.0, arm64): `just docker-build`, then the
image run as `just docker-run` runs it (`just --dry-run docker-run` shows
the `-v ~/.age:/root/.age:ro` mount).

- Build: warns `agenix: could not decrypt 'example'` (no key at build
  time), as expected. Rebuilt after editing only the entrypoint: the
  generation layer is `CACHED`, 1s.
- With `~/.age` mounted read-only: `~/.local/share/agenix/example` is
  decrypted, 61 bytes, mode 0400; `zsh -l` starts through the entrypoint.
- Without it: no activation, `example` missing, the command still runs.
- With a wrong key: only `>> agenix: could not decrypt 'example'`, then
  the shell starts.
- Start time, `docker run --rm ... sh -c <check>`: 0.4s with the key and
  0.4s without; re-activation adds nothing noticeable.
- `docker inspect`: entrypoint `/opt/entrypoint.sh`, cmd `zsh -l`.
- `just --fmt --check --unstable` passes.

Not run: an interactive `just docker-run` session (`-it`), and amd64.
