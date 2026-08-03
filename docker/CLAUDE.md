# Machine: mid-2012 MacBook Pro via Docker container

Claude Code runs inside a Linux container (image: `dev-x86`, built with
`docker build -t dev-x86 .` from the dotfiles repo) on a 2012 MacBook Pro. The
host CANNOT run current Claude Code: Nix itself requires macOS 14+ (host is on
10.15), and the host's npm install of `@anthropic-ai/claude-code` is pinned at
1.0.56 with max compatibility ~1.0.93. The container IS the modern toolchain;
the host is frozen. Dotfiles: https://github.com/alycda/dotfiles (its
`Dockerfile` + `docker/CLAUDE.md` cover the container build). PR #34 *fixed* the
two startup pitfalls this image used to hit, so you should not see them: the
entrypoint now auto-drops the base image's `git-minimal` (it collided with
home-manager's full git), and the documented run command no longer mounts a
volume over `/nix`.

## Hardware (verified 2026-06-11)

- **Host**: MacBookPro10,1 (mid-2012 15" Retina), i7-3720QM @ 2.6 GHz — 4 cores /
  8 threads, Ivy Bridge. 16 GB RAM (soldered, not upgradable). 1.7 TB APFS SSD.
- **OS**: macOS Catalina 10.15.8 — the FINAL macOS for this hardware.
- **Docker**: engine 20.10.x (Docker Desktop ≤4.15) — the last release line that
  supports Catalina. Never suggest updating Docker Desktop.
- **Container VM**: 4 CPUs, 8 GB RAM, 1 GB swap, linuxkit 5.15.49 kernel, x86_64.

## Memory — the #1 constraint

The host is chronically swapping (observed: 5.8 GB of 6 GB swap used). The Docker VM
takes half the host's RAM, and host Ollama models (up to ~3 GB, see below) compete
for the rest. Inside the container you have 8 GB and only 1 GB swap; the OOM killer
is real here.

- Don't spawn many parallel subagents or background processes at once.
- Cap parallel builds: `make -j2`, `cargo build -j 2`. Never `-j$(nproc)` for heavy
  compiles.
- Don't suggest raising the Docker VM's memory allocation — the host can't spare it.
- Exit code 137 / "Killed" = OOM. Retry serially with lower parallelism, don't just
  rerun.
- A 7.3 GB Ollama model once (probably) crashed the whole machine. Local models are
  vetted with `llmfit`; anything that fits poorly (>~50% memory) is a bad idea.

## Filesystem — /work is slow, / is fast

`/work` is a **grpcfuse** bind mount of the host disk (VirtioFS needs macOS 12.5+,
unavailable here). Consequences:

- I/O on `/work` is an order of magnitude slower than the container's overlay fs.
  Do heavy I/O (dependency installs, build output, scratch files, large greps) in a
  container-local path like `/tmp` or `$HOME`, then copy results to `/work`.
- **inotify does not propagate across grpcfuse**: file watchers and hot-reload dev
  servers won't see host-side edits. Use polling (`CHOKIDAR_USEPOLLING=1`,
  `WATCHPACK_POLLING=true`, `cargo watch --poll`, etc.).
- Container overlay `/` is ~59 GB shared with images; "no space left on device"
  means the Docker VM disk is full — fix with `docker system prune` on the HOST,
  not by deleting files in `/work` (the host SSD has ~1.2 TB free).
- The Nix store is baked into the image. Never mount a named volume over `/nix`
  (copies the ~10 GB closure, doubles disk use, and leaves stale shadows that
  break startup). The documented run command already omits this since PR #34 —
  don't add it back.

## CPU / age-related gotchas

- Ivy Bridge has AVX but **no AVX2**. Modern prebuilt binaries (onnxruntime, some
  TF/PyTorch wheels, some native node modules) die with `SIGILL` / "Illegal
  instruction". Not a bug — pick an older build, a no-AVX2 variant, or compile
  from source.
- Everything is ~5–10× slower than a modern machine. Use generous Bash timeouts;
  a "hung" compile is usually just a slow one.

## Host software ceilings (Catalina, do not suggest upgrades)

| Thing | Ceiling | Notes |
|---|---|---|
| macOS | 10.15.8 | last for MacBookPro10,1 |
| Docker Desktop | 4.15 / engine 20.10 | dropped Catalina in 4.16 |
| File sharing | grpcfuse | VirtioFS needs macOS 12.5+ |
| Nix on host | none | Nix requires macOS 14+ — host has NO nix |
| Claude Code on host (npm) | 1.0.93 | why this container exists |
| Electron apps | Electron 32 | Electron 33 dropped Catalina |
| VS Code | 1.97.2 | Electron ceiling; has remote-containers ext |
| Obsidian | 1.7.7 | Electron ceiling |
| Chrome | 128 | Safari is 15.6.1; some sites need Chrome |
| Homebrew gh, git | dropped | brew bottles no longer support Catalina |
| Xcode | 12.4 | last for Catalina |
| Anything AVX2 | n/a | CPU baseline |

Unsupported on host entirely: GitHub Desktop, Discord, Slack, Workflowy app,
LogSeq, ghostty, OrbStack, Claude desktop app (claude.ai runs as Chrome web app).

**Pattern**: when a host tool is too old or its brew bottle dropped Catalina, the
fix is (a) `cargo install --locked` on the host (works: jj, just, rustledger), or
(b) run it in this container — not chasing newer macOS-incompatible builds.

Inside the container, Linux software is NOT capped — current Node, Rust, Claude
Code, etc. all run fine. That's the point of the container.

## Host editing setup

- Host terminal is Warp; editing happens via VS Code 1.97.2 + Remote Containers on
  the host. This image is Claude-only: no GUI, no `code` binary inside.

## Working with the host

- `! commands` typed in this session run INSIDE the container. Anything that must
  run on the host (docker prune, system_profiler, launching services), the user
  runs in a host terminal and pastes output.
- Host default shell is **bash 3.2**: no associative arrays, no `mapfile`,
  no `${var,,}`. BSD userland: `sed -i ''` not `sed -i`, no GNU-only flags.
- Don't suggest memory-hungry host-side work; the host is already swapping.

@includes/agents-company-values.md

@includes/agents-personal-constitution.md

@includes/agents-instructions.private.md

@rules/outbound-comment-gate.md
