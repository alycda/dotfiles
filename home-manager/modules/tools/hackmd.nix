# HackMD API token (agenix). Decrypts to ~/.config/hackmd/env in
# "HACKMD_API_TOKEN=<token>" env-file format, so consumers can source it:
#   set -a; . ~/.config/hackmd/env; set +a
# (the Claude Code hackmd MCP launcher in ~/.claude.json does exactly this).
# identityPaths and secretsDir are configured in ../git.nix; this module only
# adds the secret. Encrypt the plaintext with:
#   agenix -e secrets/work/hackmd-api-token.age   # type: HACKMD_API_TOKEN=<token>
{ config, ... }:
{
  age.secrets.hackmd-api-token = {
    file = ../../../secrets/work/hackmd-api-token.age;
    path = "${config.home.homeDirectory}/.config/hackmd/env";
    mode = "0600";
  };
}
