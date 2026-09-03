# Agenix secrets configuration
# Run `just edit-secret <name>.age` (repo root) to create/edit secrets -
# bare agenix lacks the --rules and -i flags (see cheat agenix/edit)
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

  # Linear API key for the `linear` MCP server. Work and personal Linear
  # accounts issue separate keys, so the *directory* carries the identity and
  # neither filename grows a suffix. Committed ARMORED (`rage -a`) - see the
  # note in these secrets' home-manager wiring for why binary blobs do not
  # reliably survive the trip into a commit.
  "work/linear-api-key.age".publicKeys = [ alyssa ];
  "personal/linear-api-key.age".publicKeys = [ alyssa ];

  # HackMD API token, consumed by the hackmd-cli wrapper
  # (home-manager/modules/tools/hackmd.nix). Same convention as the Linear keys
  # above: the *directory* carries the account, so neither filename needs a
  # suffix, and a profile picks one with `hackmd.account = "personal" | "work"`.
  #
  # Both ciphertexts came from PR #59, which wired these secrets to a HackMD MCP
  # server. That module is superseded by the CLI, but the secrets outlived it -
  # a token is a token whichever process spends it. Their plaintext has never
  # been read in this repo's history that is visible here, so treat the values
  # as unverified until a decrypt proves otherwise: `just edit-secret
  # personal/hackmd-api-token.age` opens the current value for inspection.
  "work/hackmd-api-token.age".publicKeys = [ alyssa ];
  "personal/hackmd-api-token.age".publicKeys = [ alyssa ];

  # Venice API key for crush (see cheat crush/venice). Committed value is an
  # encrypted PLACEHOLDER string, not a real key - replace in place with
  # `just edit-secret personal/venice-api-key.age` before wiring it into
  # home-manager. Armored, like the linear keys above.
  "personal/venice-api-key.age".publicKeys = [ alyssa ];
}
