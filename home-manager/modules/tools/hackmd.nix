# HackMD API token (agenix). Decrypts to the shared secretsDir
# (~/.local/share/agenix/hackmd-api-token); identityPaths and secretsDir are
# configured in ../git.nix, this module only adds the secret. Consumers should
# read the file at config.age.secrets.hackmd-api-token.path rather than baking
# the token into the environment, e.g.:
#   export HMD_API_ACCESS_TOKEN="$(cat ~/.local/share/agenix/hackmd-api-token)"
_:
{
  age.secrets.hackmd-api-token.file = ../../../secrets/personal/hackmd-api-token.age;
}
