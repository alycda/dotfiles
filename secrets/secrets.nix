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

  # Linear API key for the `linear` MCP server. Work and personal Linear
  # accounts issue separate keys, so the *directory* carries the identity and
  # neither filename grows a suffix. Committed ARMORED (`rage -a`) - see the
  # note in these secrets' home-manager wiring for why binary blobs do not
  # reliably survive the trip into a commit.
  "work/linear-api-key.age".publicKeys = [ alyssa ];
  "personal/linear-api-key.age".publicKeys = [ alyssa ];

  # Cloudflare API token for the `cloudflare-bindings` MCP connector. Personal
  # only - there is no work Cloudflare account - so unlike the Linear keys this
  # name needs no directory to disambiguate it. Also ARMORED, for the reason
  # above. NOT the credential cf-now uses: R2's S3 API takes a separate R2 API
  # token (an access-key/secret pair minted in the R2 dashboard), and the two
  # are not interchangeable in either direction.
  "personal/cloudflare-api-token.age".publicKeys = [ alyssa ];
}
