# Managed user-scope MCP servers, merged into ~/.claude.json by the
# claudeMcpServers activation in home-manager/modules/tools/claude-code.nix.
#
# jq filter rather than a JSON fragment so the secret ($lin, read with
# --rawfile from the agenix-decrypted file at activation time) never appears
# in a tracked file, the Nix store, or a process argv. `+` (not `*`) so the
# entries here are owned wholesale while hand-added servers (e.g. apple-mail,
# which points at a machine-specific build path) are left alone.
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
    headers: { Authorization: ("Bearer " + ($lin | rtrimstr("\n"))) }
  }
}
