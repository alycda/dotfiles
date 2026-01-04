FROM nixos/nix:latest

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Copy flake and skills
COPY flake.nix flake.lock /flake/
COPY skills /flake/skills
COPY agents /flake/agents

# Setup jujutsu config
COPY jjconfig.toml /root/.jjconfig.toml

# Setup claude config with restricted permissions
RUN mkdir -p /root/.claude
COPY settings.sandboxed.json /root/.claude/settings.json

# Symlink skills and agents
RUN mkdir -p /root/.claude/skills /root/.claude/agents && \
    for f in /flake/skills/*.md; do ln -s "$f" /root/.claude/skills/; done && \
    for f in /flake/agents/*.md; do ln -s "$f" /root/.claude/agents/; done

# Pre-build the environment
RUN nix develop /flake --command true

WORKDIR /workspace

# Mount your project to /workspace
ENTRYPOINT ["nix", "develop", "/flake", "--command", "claude"]
