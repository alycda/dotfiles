---
title: "home-manager's bash collides with the base image's bash, killing container activation"
date: 2026-08-04
category: build-errors
module: home-manager/profiles/dev.nix
problem_type: build_error
component: tooling
severity: high
symptoms:
  - "home-manager activation aborts at installPackages: 'Unable to build profile. There is a conflict for the following files' listing two store paths that both provide bin/bash"
  - "error: Cannot build '/nix/store/...-user-environment.drv' printed on every docker run, followed by '>> activation failed.'"
  - "`which claude` returns 'no claude in (/root/.nix-profile/bin:...)' — claude, jj, and rg are all missing from PATH in a freshly built container"
  - Dotfiles and the starship prompt render correctly because linkGeneration runs before installPackages, so the container looks like it has a PATH bug rather than a failed activation
root_cause: config_error
resolution_type: config_change
related_components:
  - development_workflow
  - documentation
tags:
  - nix
  - home-manager
  - docker
  - bash
  - starship
  - profile-conflict
  - devcontainer
---

# home-manager's bash collides with the base image's bash, killing container activation

## Problem

Enabling a home-manager `programs.*` module can silently install a *package*, not just configuration. When that package already exists in the base image's `nix-env` profile at a different store path, the two collide and the entire home-manager activation dies — taking every other tool with it.

**This is the third instance of one failure class in this repo, not a novel bug.** (session history) The `nixos/nix` base image ships its own populated `nix-env` profile, and each package in it is a potential collision with home-manager's:

| Instance | Colliding package | Remedy used |
|---|---|---|
| PR #34 (merged 2026-06-11) | `git-minimal` vs home-manager's full `git` | remove the base copy at the entrypoint |
| PR #60 (merged 2026-08-03) | `man-db` vs home-manager's `man` | remove the base copy at the entrypoint |
| PR #74 (this doc, unmerged at time of writing) | `bash-interactive` vs home-manager's `bashInteractive` | **ship none** — `package = null` |

Three instances, three remedies. Which one applies is decided by a single question: **does home-manager need to *provide* this program, or only to *configure* it?** bash is the first case where the base image's copy is load-bearing — it is root's login shell — so the established entrypoint trick could not be reused.

Concretely: while wiring up a starship prompt (issue #15, PR #74), `programs.bash.enable = true` was added at `home-manager/modules/common.nix:57` so the container's fallback bash shell would pick up the starship and direnv hooks. The motivation was sound — `docker exec -it dev bash` lands in bash regardless of the Dockerfile `CMD`, because root's login shell in `/etc/passwd` is the base image's bash, and until then that shell got no home-manager config at all.

The side effect was not. home-manager's bash module installs bash into the user environment:

```nix
home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];
```

— that is upstream home-manager's own `modules/programs/bash.nix:247`, in the pinned input rather than in this repo, defaulting to `bashInteractive` (same file, `:45-48`). The dev container is built `FROM nixos/nix:latest` (`Dockerfile:65`), and that base image already ships `bash-interactive` in root's nix-env profile. Two different `bin/bash` from two different store paths, both unioned into one profile. Nix refuses.

## Symptoms

Rebuilding the image and starting the container printed a successful-looking activation that fell over near the end:

```
Activating linkGeneration
Creating home file links in /root
...
Activating installPackages
installing 'home-manager-path'
error: Unable to build profile. There is a conflict for the following files:

         "/nix/store/jj9...-home-manager-path/bin/bash"
         "/nix/store/q1n...-bash-interactive-5.3p9/bin/bash"
error: Cannot build '/nix/store/8fv...-user-environment.drv'.
       Reason: builder failed with exit code 1.

Oops, Nix failed to install your new Home Manager profile!
>> activation failed.
```

The second store path is exactly root's login shell — `grep '^root' /etc/passwd` in the container returns that same `bash-interactive-5.3p9` path.

The container still started, because `docker/entrypoint.sh` prints the failure and continues rather than aborting. And the prompt looked *right* — starship rendered, direnv worked. But every tool from `home.packages` had vanished:

```
❯ claude --continue
bash: claude: command not found
❯ which claude
which: no claude in (/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:...)
```

**This is the confusing part and deserves a name.** The dotfiles landed and the packages didn't, because `linkGeneration` runs before `installPackages`. Worth knowing precisely: the two are DAG *siblings* — both declared `entryAfter [ "writeBoundary" ]` upstream, with no explicit constraint ordering one against the other — so this ordering is how the DAG happened to resolve in the built activation script, not a guarantee you can lean on. Verify it in your own generation rather than assuming it (`grep -n 'Activating' /opt/hm-activation/activate`). Either way the failure presents as a *PATH bug*: a working prompt over an empty toolchain. Reading the activation output from the top, you see hundreds of lines of success and one error buried near the end.

## What Didn't Work

**1. The original change itself — `programs.bash.enable = true` in `common.nix`, unqualified.**

The change did exactly what it advertises; the failure was one of scope. `common.nix` is imported by *every* profile, including `dev.nix`, which is the container. What is free on macOS (nothing pre-populates a nix-env profile there) is a hard conflict inside `nixos/nix:latest`. `enable = true` reads like "turn on configuration"; it also means "ship a binary", and that second meaning is what broke.

A `nix build` of the activationPackage **succeeds** under the broken configuration. There was no build-time signal at all.

**2. `lib.hiPrio` — right tool, wrong layer.**

`lib.hiPrio pkgs.git` sits at `home-manager/modules/git.nix:35`, added during PR #34, and reaching for it here is the natural mistake. It cannot fix this collision — but not because it is useless. PR #34 contained *two different* git collisions living at two different layers:

- **Inside home-manager's own `buildEnv`.** Full `git` 2.52.0 and a transitively-pulled `git-minimal` 2.51.2 both shipped `share/git-core/templates/info/exclude`, and the buildEnv refused to merge them. `hiPrio` genuinely fixes this — it tells buildEnv which of two *inner* packages wins.
- **Between profile elements.** The base image's `git-minimal` versus the assembled `home-manager-path`. `hiPrio` cannot reach this one: `home-manager-path` is a single opaque element in root's nix-env profile, and the base image's package is another element beside it. A priority set on a package *inside* the buildEnv is invisible at the outer union. That collision is what the entrypoint prune fixed.

The bash collision is the second kind. So the rule is not "`hiPrio` is useless" but: **`hiPrio` resolves collisions within a closure, never between profile elements.** Knowing which of the two layers you are on is the whole diagnosis.

**3. Rejected: adding `bash-interactive` to the entrypoint's prune loop.**

`docker/entrypoint.sh:32` already handles this class for other packages:

```sh
  for pkg in git-minimal man-db; do
    nix-env -e "$pkg" 2>/dev/null || true
  done
```

Adding `bash-interactive` is a one-word change and would have made the error go away. Rejected on the merits:

- The removal target is the binary root's login shell in `/etc/passwd` points at, and that `/bin/sh` resolves through. Deleting it mid-entrypoint — from inside a shell script — to fix a problem the *consumer* side can decline is the wrong end of the pipe.
- The loop exists for genuinely unavoidable conflicts: home-manager needs full `git` and provides its own `man`, so the base copies must go. Nothing here needs home-manager's bash.
- The comment at `docker/entrypoint.sh:31` explicitly claims bash "is preserved and merges fine". That was true when written, and `programs.bash.enable = true` silently invalidated it. Extending the loop would have papered over an invariant break rather than restoring the invariant.

## Solution

Decline the package on the container profile only — `home-manager/profiles/dev.nix:38`:

```nix
programs.bash.package = null;
```

The option is nullable by design (upstream home-manager, `modules/programs/bash.nix:45-48`):

```nix
package = lib.mkPackageOption pkgs "bash" {
  nullable = true;
  default = "bashInteractive";
};
```

With `package = null`, the `mkIf` in that same upstream module yields nothing and bash never enters `home.packages`. Everything else the module produces — `~/.bashrc`, `~/.bash_profile`, `~/.profile`, and the starship and direnv hooks inside them — is unaffected, because those come from separate `home.file` declarations. *Configuring a shell and installing one are separate concerns; here we only want the former.*

Validated by reproducing the profile union in isolated scratch profiles via `nix-env --profile`: the base image's `bash-interactive` store path alongside the *old* `home-manager-path` reproduced the reported error verbatim with identical store paths; the same with the *new* `home-manager-path` built clean at exit 0, with `claude`, `jj`, `rg`, `hx`, `just`, `gh` and `starship` all resolving and `bash` resolving to the base image's 5.3.9.

## Why This Works

A nix-env user environment is a **union of symlink trees**. Two packages that each provide `bin/bash` cannot both be linked into one profile, and Nix treats it as a hard error rather than picking a winner. `home-manager-path` is itself just another package installed into that profile — visible in `nix-env -q` alongside the base image's entries — so it competes on equal footing. That is also why `hiPrio` cannot help: priority resolves conflicts inside a `buildEnv`, not between profile elements.

There are exactly two ways to break the tie: remove one side, or don't add it. `package = null` is the second and is strictly less invasive — nothing is deleted, no existing behavior changes, and the base image's bash remains what `/etc/passwd` and `/bin/sh` already point at.

The general principle: home-manager's `programs.*` modules do two separable jobs — they *generate configuration* (`home.file` / `xdg.configFile`) and they *provide the program* (`home.packages`). Usually you want both, so `enable = true` bundles them. When the program already exists on the system, you want only the first half, and the nullable `package` option is the supported way to say so. This idiom is not bash-specific.

### Why scoped to `dev.nix` and not `common.nix`

The collision is a *container* fact, not a Linux fact: it exists because `nixos/nix:latest` ships a pre-populated nix-env profile. A machine without that profile has no conflict, so hoisting `package = null` into `common.nix` would fix nothing and cost something real on macOS:

- macOS ships bash 3.2 (Apple stopped updating at the last GPLv2 release).
- home-manager's own generated bashrc uses `[[ ! -v BASH_COMPLETION_VERSINFO ]]` inside the completion block that `enableCompletion` turns on by default. The `-v` test is a bash 4.2+ construct.

So on darwin the config home-manager generates *requires* a bash newer than the one macOS provides. The darwin profiles keep the default deliberately.

## Prevention

**Before enabling a home-manager `programs.*` module that will run in the container, check for a binary collision.**

1. **Ask what the module installs, not just what it configures.**

   ```sh
   hm=$(nix eval --raw --impure --expr \
     '(builtins.getFlake "path:/work/alycda/dotfiles").inputs.home-manager.outPath')
   rg -n 'home\.packages' "$hm/modules/programs/<name>.nix"
   ```

   `home.packages = lib.mkIf (cfg.package != null) [ cfg.package ]` tells you both that the module ships a binary and that `package` is nullable.

2. **Diff what home-manager will install against the base image's profile.** No image rebuild needed:

   ```sh
   ls $(nix eval --raw 'path:.#homeConfigurations."alyssa@dev".config.home.path')/bin  # ours
   nix-env -q                                                                          # base image's (in container)
   ```

   Any name on both sides is a candidate collision. The base profile is short enough to eyeball — and `bash-interactive` has been sitting at the top of that list since PR #34, which means this collision was sitting in plain sight for roughly eight weeks before it fired. (session history)

3. **Do not trust a green `nix build`.** It proves the configuration evaluates and its closure builds; it proves nothing about activation, because the profile union is computed at activation time against whatever the *target machine's* profile contains. CI can be fully green and the container unusable. For a real check, reproduce the union in a scratch profile:

   ```sh
   nix-env --profile /tmp/scratch-profile -i \
     $(nix eval --raw 'path:.#homeConfigurations."alyssa@dev".config.home.path') \
     /nix/store/<base-image-bash-interactive-path>
   ```

   Exit 0 means clean; the conflict error means not. This is how the fix was validated.

4. **Pick the remedy by asking who needs the program.** Decline on the home-manager side (`package = null`) when you only wanted configuration. Remove the base copy at the entrypoint only when home-manager's version is genuinely required (full `git` over `git-minimal`) or supersedes it (`man` over `man-db`). Never prune something `/etc/passwd`, `/bin/sh`, or the entrypoint itself depends on. `lib.hiPrio` is not an option for this class at all.

5. **Re-verify container activation whenever the base image or `common.nix`'s package set changes.** Each `nixos/nix` refresh can seed a new colliding package — that is exactly how `man-db` appeared on arm64 in PR #60.

6. **If store hashes are unchanged across a rebuild, the conflict is persisted state, not the flake.** (session history) PR #34 lost several rounds to a stale-`flake.lock` theory; the decisive disproof was comparing `user-environment.drv` and `home-manager-path` hashes across a clean rebuild and finding them byte-for-byte identical.

7. **When a comment states an invariant, treat changing it as part of the diff.** `docker/entrypoint.sh:31` asserts bash "is preserved and merges fine". A change that makes bash stop merging fine changes that comment's truth value whether or not it touches the file.

8. **Read activation output from the bottom.** "Prompt works, `command not found` for everything" is the fingerprint of a failed `installPackages` — check the tail of the activation log before debugging `PATH`.

## Related Issues

- Issue #15 (Zsh) — the umbrella shell issue this work hangs off.
- PR #74 — where both the regression and the fix live; open and unmerged at time of writing, so the fix is not yet on `main`.
- PR #34 — first instance of this collision class (`git-minimal`); introduced the entrypoint prune loop and the `lib.hiPrio` insurance.
- PR #60 — second instance (`man-db` on arm64); extended the prune loop.
- PR #24 — the precedent for enabling a shell in home-manager purely to get hooks injected, which is the motivation that later produced `bash.enable = true`.
