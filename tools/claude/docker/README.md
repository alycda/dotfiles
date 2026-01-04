# Portable Claude Code (Docker)

A sandboxed Claude Code environment for use when:
- You can't install Nix but have Docker (remote devcontainers)
- You want extra security (only mounted volume at risk, not entire hard drive)

## Build

```bash
cd tools/claude/docker
docker build -t claude-sandbox .
```

## Usage

Mount your project directory to `/workspace`:

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
  claude-sandbox
```

## Authentication

Claude Code stores credentials in `~/.claude/.credentials.json`. Mount this read-only to avoid re-authenticating each time.

If you have authentication issues:
1. Run `claude login` locally first
2. Mount the credentials file as shown above

## Security

The sandboxed settings restrict Claude to:
- Read-only git operations (status, diff, log)
- Jujutsu commands
- Denies `rm -rf` and `sudo`

Only the mounted `/workspace` volume is at risk - your host filesystem is protected.

## Networking

For multi-container setups, create a network:

```bash
docker network create claude-net
docker run -it --rm --network claude-net -v $(pwd):/workspace claude-sandbox
```
