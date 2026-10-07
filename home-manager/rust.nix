# Rust, from rustup, as main's home-manager/modules/dev/rust.nix: the toolchain
# and what building crates needs beside it. Imported by the profiles that
# build Rust; lldb (1.6 GiB, not a Rust dependency) stays out.
{ lib, pkgs, ... }:
{
  home.packages = [
    # rust-analyzer comes as a rustup component (below), not from nixpkgs:
    # both on PATH conflict.
    pkgs.rustup
    pkgs.bacon
    # rustup stops at rustc and cargo; linking is the system's job. Without
    # cc the first crate with a build script fails on `linker \`cc\` not
    # found`. pkg-config is what the -sys crates use to find libraries; the
    # libraries themselves still have to be in the profile.
    pkgs.stdenv.cc
    pkgs.pkg-config
  ];

  # A default toolchain, once per switch, not from shell init. `|| true`
  # throughout: this is the one network call in activation, and a failed
  # `run` stops activation after the dotfiles are written, leaving a prompt
  # and no packages. Offline means no toolchain yet, not a broken profile.
  #
  # The probe repairs a ~/.rustup that outlived a container image: nixpkgs'
  # rustup patchelfs toolchains against the glibc of the image that installed
  # them, so on a new image `cargo` fails with "No such file or directory".
  # `rustup default stable` sees the toolchain and does nothing, and
  # `toolchain install --force` re-fetches nothing at the current stable, so
  # uninstall and install again. On a Mac the probe always passes.
  home.activation.rustupDefaultToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.rustup}/bin/rustup default stable || true

    if ! run --silence ${pkgs.rustup}/bin/rustup run stable cargo --version; then
      run ${pkgs.rustup}/bin/rustup toolchain uninstall stable || true
      run ${pkgs.rustup}/bin/rustup default stable || true
    fi

    run ${pkgs.rustup}/bin/rustup component add rust-analyzer || true
  '';
}
