# Managed user-scope MCP servers, merged into ~/.claude.json by the
# claudeMcpServers activation in home-manager/modules/tools/claude-code.nix.
#
# jq filter rather than a JSON fragment so the secret values ($lin, $hmd -
# passed with --arg from the agenix-decrypted files at activation time) never
# appear in a tracked file or the Nix store. `+` (not `*`) so these two
# entries are owned wholesale while hand-added servers (e.g. apple-mail, which
# points at a machine-specific build path) are left alone.
#
# linear: Linear's hosted MCP server authenticates with a plain API key in the
# Authorization header - no OAuth dance - so unlike `claude /login` this needs
# no manual step after checkout. Uses the PERSONAL account key: user scope is
# the machine's ambient identity, and that is the personal account. The work
# tree keeps work Linear regardless - its project-scope config names the -work
# key explicitly, and more specific MCP scopes shadow user scope. The flip
# side: a work repo *without* its own .mcp.json gets personal Linear here.
.mcpServers = (.mcpServers // {}) + {
  linear: {
    type: "http",
    url: "https://mcp.linear.app/mcp",
    headers: { Authorization: ("Bearer " + $lin) }
  },
  hackmd: {
    type: "stdio",
    command: "npx",
    args: ["-y", "hackmd-mcp"],
    env: { HACKMD_API_TOKEN: $hmd }
  }
}
