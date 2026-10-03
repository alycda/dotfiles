# Mount the age identity in the Nix devcontainer

- STATUS: CLOSED
- TAGS: agenix, secrets, devcontainer, nix

## Description

The Nix devcontainer (`.devcontainer.json`) applies home-manager in its
`postCreateCommand`, and activation installs every agenix secret under
`secrets/` (`home-manager/agenix.nix`). It has no identity to decrypt with, so
today activation warns `could not decrypt` for each secret and they never
arrive. Give it the host's identity, read-only.

Do this together with the first real secret, so there is something to check
end to end; `secrets/example.age` alone proves only the plumbing.

### What to change in `.devcontainer.json`

1. Mount the host's `~/.age` at the container user's `~/.age`, read-only:

   ```jsonc
   "mounts": [
       "source=${localEnv:HOME}/.age,target=/home/vscode/.age,type=bind,readonly"
   ],
   ```

2. Create `~/.age` on the host before the container starts. A bind mount whose
   source is missing stops the container from starting at all, which would
   make a key-less host unable to open the repo:

   ```jsonc
   "initializeCommand": "mkdir -p \"$HOME/.age\"",
   ```

   `initializeCommand` runs on the host, before the container exists.

3. Nothing else: the existing `postCreateCommand` switch already installs the
   secrets once the key is there. With an empty `~/.age`, it warns and the
   container still works.

### Things to check

- **Ownership.** With `chmod 600` on the host (see below), the key belongs to
  the host user. On OrbStack and Docker Desktop, bind mounts are readable by
  the container user anyway; confirm that `vscode` can read it.
- **When secrets update.** They install at activation, which runs on create.
  After adding a secret, rebuild the container, or run the switch again:
  `nix run .#home-manager -- switch --flake .#vscode@$(uname -m)-linux`.
  Decide whether that is enough, or whether `postStartCommand` should switch
  too.
- **The mise devcontainer** (`.devcontainer/mise/`) needs nothing: it has no
  home-manager, so no agenix.

### Before starting, on the host

The key at `~/.age/personal-key.txt` currently:

- has no trailing newline: fine for `age -d`, which activation uses, but
  `just edit-secret` refuses it, since ragenix fails on it. Fix:
  `echo >> ~/.age/personal-key.txt`.
- is readable by every user (`-rw-r--r--`). Fix: `chmod 600`.

## Open questions

- Re-switch on every start (`postStartCommand`), or only on create?
  Assumed: only on create, as the plan says. After adding a secret, rebuild
  the container or run the switch by hand.
- No real secret exists yet, so only `secrets/example.age` can prove it end
  to end. The plan said to wait for one; done now as part of 0.1.6, since the
  agenix plumbing ships in it anyway.
- Effort for the release: micro if a host without `~/.age` still opens the
  container. `initializeCommand` creates the directory first, and a missing
  source is the one thing that would stop it (checked below).

## Verification

Done, on 2026-10-04 (OrbStack 29.4.0, arm64, macOS host), running the
devcontainer's image `mcr.microsoft.com/devcontainers/base:bookworm` with the
same mount, since the devcontainer CLI isn't installed here:

- `docker run -u vscode --mount type=bind,source=$HOME/.age,target=/home/vscode/.age,readonly`:
  the key shows as uid 1000 (`vscode`), mode 0600, and `vscode` can read it.
  `mount` shows `/home/vscode/.age` as `virtiofs (ro,...)`, and `touch` in it
  fails with "Read-only file system".
- The same with a missing source: `docker run` exits 125, "bind source path
  does not exist". That is what `initializeCommand` prevents.
- The host key already has its trailing newline and mode 600.

Rebuilt in VS Code on this Mac (OrbStack) and confirmed working by Alyssa on
2026-10-04, with the key present. Her report was "confirmed", without the
switch output, so the no-key rebuild is covered only by the missing-source
check above and the activation check in `nixos/nix` below.

Not checked: a non-OrbStack runtime (Docker Desktop), where bind-mount
ownership may differ and `vscode` might not read a mode-0600 key.

Already verified, in `nixos/nix` with `~/.age` mounted read-only (change "nix(hm):
agenix, installing secrets at activation"): activation decrypts
`secrets/example.age` with the key as it is, trailing newline or not.
