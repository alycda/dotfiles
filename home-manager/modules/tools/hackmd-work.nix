# HackMD API token — WORK account (agenix). Decrypts to ~/.config/hackmd/env in
# "HACKMD_API_TOKEN=<token>" env-file format, sourced at spawn time by the
# launcher in ./hackmd-mcp.nix, which this module imports so the MCP server and
# the token it needs always arrive together.
# identityPaths/secretsDir come from ../git.nix. Imported by the work profile;
# hackmd-personal.nix is the personal-account parallel imported by home.nix.
# The two are mutually exclusive (one HackMD account per machine) and share the
# same secret name + decrypt path, so only one may be imported per profile.
# Encrypt the plaintext with:
#   agenix -e secrets/work/hackmd-api-token.age   # type: HACKMD_API_TOKEN=<token>
{ config, ... }:
{
  imports = [ ./hackmd-mcp.nix ];

  age.secrets.hackmd-api-token = {
    file = ../../../secrets/work/hackmd-api-token.age;
    path = "${config.home.homeDirectory}/.config/hackmd/env";
    mode = "0600";
  };
}
