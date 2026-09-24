# Cloudflare R2 credentials for the cf-now skill (tools/agents/skills/cf-now,
# deployed by ./agent-skills.nix). The skill drives the AWS CLI against the R2
# S3-compatible endpoint, so what it actually needs is an AWS named profile -
# this module is how that profile arrives with the generation instead of by
# hand.
#
# Two secrets, matching the AWS CLI's own split:
#   r2-config      -> ~/.aws/config       region `auto` + the R2 endpoint URL
#   r2-credentials -> ~/.aws/credentials  the R2 API token's key ID + secret
#
# Opt-in, and the default matters. `path` makes agenix symlink ~/.aws/config
# and ~/.aws/credentials at the decrypted copies, which on a machine that
# already has real AWS config would replace it. A work machine plausibly does.
# So this defaults off and profiles turn it on; it is not a module that is safe
# to enable from common.nix.
#
# There is no `aws` in any profile's closure on purpose. awscli2 is a ~500MB
# Python closure, common.nix is inherited by the x86 devcontainer image, and
# the repo already has a better answer for a tool needed occasionally: summon
# it (`nix run nixpkgs#awscli2 -- ...`). SKILL.md's Requirements section says
# so explicitly - it used to claim the CLI was "installed on this machine",
# which was never true in the container.
{ config, lib, ... }:
let
  cfg = config.cfNow;
in
{
  options.cfNow.enable = lib.mkEnableOption ''
    the Cloudflare R2 profile for the cf-now skill. Decrypts the R2 API token
    to ~/.aws/credentials and its endpoint config to ~/.aws/config, replacing
    whatever is at those paths - enable only on machines whose AWS config is
    Alyssa's personal R2 and nothing else
  '';

  config = lib.mkIf cfg.enable {
    # Identity and secretsDir come from ../git.nix, as with every other secret
    # here. One attrset rather than two `age.secrets.<name> =` lines: statix's
    # repeated_keys fires at the third assignment sharing a prefix, and a
    # third R2 secret is exactly the kind of additive change that would
    # otherwise fail CI for whoever writes it.
    age.secrets = {
      r2-config = {
        file = ../../../secrets/personal/r2-config.age;
        path = "${config.home.homeDirectory}/.aws/config";
      };
      r2-credentials = {
        file = ../../../secrets/personal/r2-credentials.age;
        path = "${config.home.homeDirectory}/.aws/credentials";
      };
    };
  };
}
