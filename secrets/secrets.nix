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

  # daily-ticket-status-drafts task (agent-tasks harness). Committed content is
  # a sentinel placeholder; scripts refuse to run until replaced via agenix -e.
  "personal/ticket-drafts-prompt.age".publicKeys = [ alyssa ];
  "personal/linear-api-key.age".publicKeys = [ alyssa ];
}
