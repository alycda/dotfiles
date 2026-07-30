# Agenix secrets configuration
# Run `agenix -e secrets/<name>.age` to create/edit encrypted secrets
#
# Usage in home-manager:
#   age.secrets.example.file = ../../secrets/example.age;
#   # Then reference: config.age.secrets.example.path
let
  # Age public key (from tools/cheat/cheatsheets/personal/rage)
  alyssa = "age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09";

  # You can also use SSH public keys:
  # alyssa-ssh = "ssh-ed25519 AAAA... alyssa@machine";
in
{
  "personal/git-config.age".publicKeys = [ alyssa ];

  # Private agent-instruction overlay (issue #40). Decrypted only on local
  # machines to ~/.agents/instructions.private.md; never committed as plaintext.
  "personal/agent-instructions.age".publicKeys = [ alyssa ];

  # HackMD API token, decrypted to ~/.config/hackmd/env in env-file format.
  # Two accounts, one per machine profile (see hackmd-{work,personal}.nix):
  #   work profile  -> hackmd-work.nix
  #   home profile  -> hackmd-personal.nix
  "work/hackmd-api-token.age".publicKeys = [ alyssa ];
  "personal/hackmd-api-token.age".publicKeys = [ alyssa ];
}
