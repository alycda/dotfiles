# Claude Code Configuration

This directory contains Claude Code configuration: skills, agents, and settings.

## Architecture

Two installation paths are provided:

### Home Manager (Primary)

For full system integration, import the home-manager module:

```nix
# In home-manager/modules/common.nix
imports = [
  ./tools/claude.nix
];
```

This:
- Installs `claude-code` CLI
- Symlinks skills/agents/settings to `~/.claude/`

### Docker (Portable/Sandboxed)

For environments without Nix, or when you want extra security:

```bash
cd tools/claude/docker
docker build -t claude-sandbox .
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.claude/.credentials.json:/root/.claude/.credentials.json:ro \
  claude-sandbox
```

See `docker/README.md` for details.

## Directory Structure

```
tools/claude/
├── skills/           # Reusable prompts invoked with /skill
│   ├── learn.md      # Step-by-step learning methodology
│   ├── write-recco.md # Generate recommendations from git history
│   ├── oss-deep-dive.md # OSS codebase exploration
│   └── commit-craft.md  # Chris Beams' commit rules
├── agents/           # Autonomous agents with specific personas
│   └── code-mentor.md   # Pair programming mentor
├── settings.json     # Global permissions (allow/deny patterns)
└── docker/           # Portable sandboxed environment
    ├── Dockerfile
    ├── flake.nix
    ├── settings.sandboxed.json  # Restricted permissions
    └── README.md
```

## Skills vs Agents

**Skills** are invoked prompts that guide Claude's behavior for specific tasks. They're reusable templates you trigger with `/skill`.

**Agents** are autonomous personas with defined characteristics and workflows. They operate more independently with a specific perspective.

## Customization

### Adding Skills

Create a new `.md` file in `skills/` and add it to `home-manager/modules/tools/claude.nix`:

```nix
home.file = {
  # ... existing files ...
  ".claude/skills/my-skill.md".source = "${claudeDir}/skills/my-skill.md";
};
```

### Adding Agents

Same pattern as skills, but in the `agents/` directory.

### Modifying Permissions

Edit `settings.json` for home-manager installs, or `docker/settings.sandboxed.json` for Docker.

The Docker environment uses restricted permissions by default (read-only git, jj allowed, rm -rf and sudo denied).
