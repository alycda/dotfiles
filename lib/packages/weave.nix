# weave (Ataraxy Labs): the entity-level merge driver. Its CLI and the driver
# jj and git invoke are separate release assets; both are the binaries mise
# installs, at the same version, patched to run from the Nix store
# (lib/release-binary.nix). nixpkgs' weave lags upstream.
{ pkgs }:
let
  release = import ../release-binary.nix { inherit pkgs; };
in
[
  (release {
    pname = "weave";
    version = "0.5.4";
    bin = "weave";
    assets = {
      aarch64-darwin = {
        url = "https://github.com/Ataraxy-Labs/weave/releases/download/v0.5.4/weave-cli-aarch64-apple-darwin.tar.gz";
        hash = "sha256-bogOt6A4+9I8Lo33vU3tF+6cBPvx7fyLbQM2RHmwnYc=";
      };
      aarch64-linux = {
        url = "https://github.com/Ataraxy-Labs/weave/releases/download/v0.5.4/weave-cli-aarch64-unknown-linux-gnu.tar.gz";
        hash = "sha256-6MwhreAcj5tmWzx/NEZ4Zr5yMgy8VKchZlV+5QJEDnE=";
      };
      x86_64-linux = {
        url = "https://github.com/Ataraxy-Labs/weave/releases/download/v0.5.4/weave-cli-x86_64-unknown-linux-gnu.tar.gz";
        hash = "sha256-k7n6A+cUr4CR9MKKhse6gNmAPVoH0ZbEYBlgrVFCbfw=";
      };
    };
  })
  # What jj and git invoke to merge (the entity-level-git and jujutsu skills).
  (release {
    pname = "weave-driver";
    version = "0.5.4";
    bin = "weave-driver";
    assets = {
      aarch64-darwin = {
        url = "https://github.com/Ataraxy-Labs/weave/releases/download/v0.5.4/weave-driver-aarch64-apple-darwin.tar.gz";
        hash = "sha256-4kSXyo563hKH0ZhtSa5EoSiY0x7Go+a/NpjllGKdE8I=";
      };
      aarch64-linux = {
        url = "https://github.com/Ataraxy-Labs/weave/releases/download/v0.5.4/weave-driver-aarch64-unknown-linux-gnu.tar.gz";
        hash = "sha256-sjIO4iMPowyI/ho/pPpEfpno18pjhfKr45Htvj4xl74=";
      };
      x86_64-linux = {
        url = "https://github.com/Ataraxy-Labs/weave/releases/download/v0.5.4/weave-driver-x86_64-unknown-linux-gnu.tar.gz";
        hash = "sha256-gjaT7IM73+HZlRLtN/9YBHwWqoF0FsZFDiOfzd69BQM=";
      };
    };
  })
]
