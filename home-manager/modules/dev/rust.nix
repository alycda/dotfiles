{ pkgs, lib, ... }:

{
  # Rust toolchain only. Deliberately scoped to what every Rust profile needs,
  # so container profiles can import this module without inheriting a desktop's
  # worth of closure.
  #
  # lldb used to live here and now sits in work.nix, the one profile that wants
  # a system debugger. It is a 1.6 GiB closure - against 94 MiB for rustup and
  # 63 MiB for bacon - and it is not a Rust dependency: cargo and bacon never
  # invoke it, and VS Code's CodeLLDB extension ships its own. Carrying it in
  # the shared module priced the container profiles out of importing this at
  # all, which is how `dev` ended up with no Rust.
  home.packages = with pkgs; [
    rustup
    # rust-analyzer # Don't install standalone - rustup provides rust-analyzer and installing both causes conflicts
    bacon

    # rustup ships rustc and cargo and deliberately stops there: linking is the
    # system's job. Without a C toolchain the first dependency with a build
    # script dies on `linker \`cc\` not found`, which reads like a Rust problem
    # and is not one. stdenv.cc is the wrapped compiler - it provides cc, ld and
    # binutils, correctly wired to this nixpkgs.
    #
    # pkg-config rides along because the -sys crates (openssl-sys, libgit2-sys,
    # ...) shell out to it to locate system libraries, and its absence produces
    # a build-script failure just as indirect as the missing linker. It does not
    # supply the libraries themselves: a crate needing openssl still needs
    # openssl in the profile, or its vendored feature.
    stdenv.cc
    pkg-config
  ];

  # Install a default toolchain once per generation, rather than the
  # `rustup update` this module used to put in programs.zsh.initContent.
  #
  # Two problems with doing it from shell init. It fired a network call on
  # *every* shell, which is invisible on a laptop with one terminal open and
  # miserable in a devcontainer where every VS Code terminal pays it before
  # handing you a prompt. And it was the wrong command: `rustup update`
  # refreshes toolchains that are already installed and installs nothing when
  # there are none, so a fresh profile got rustup's shims with no toolchain
  # behind them - `cargo` on PATH, erroring with "no default toolchain".
  # `rustup default stable` is what actually makes the profile usable, and it
  # is a no-op once the toolchain is there.
  #
  # `|| true` is load-bearing. This is the only network call in activation, and
  # activation runs at container start; a failed `run` aborts the whole
  # activation *after* linkGeneration has written the dotfiles, which is the
  # documented way to end up with a perfect prompt and no packages. Starting
  # offline must degrade to "no toolchain yet", never to a broken profile.
  #
  # Toolchains land in ~/.rustup, which is the devhome volume in containers -
  # so this downloads once and persists across --rm, not once per start.
  #
  # rust-analyzer is added as a rustup component rather than installed from
  # nixpkgs, per the standing rule against having both on PATH. It matters more
  # than style here: VS Code's rust-analyzer extension ships its own prebuilt
  # server, and that binary is an unpatched FHS build that cannot run on a Nix
  # rootfs - it fails as `spawn ... ENOENT`, which reads as "file missing" when
  # the file is present and only its ELF interpreter is absent. Toolchain
  # binaries rustup installs are patched by the nixpkgs rustup and do run, so
  # pointing the editor at this one is what makes the extension work at all.
  #
  # The symlink gives editors an arch-independent path to name; the real one
  # carries the target triple, which a shared settings file cannot hardcode.
  home.activation.rustupDefaultToolchain =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.rustup}/bin/rustup default stable || true
      run ${pkgs.rustup}/bin/rustup component add rust-analyzer || true

      ra="$(${pkgs.rustup}/bin/rustup which rust-analyzer 2>/dev/null || true)"
      if [ -n "$ra" ] && [ -x "$ra" ]; then
        run mkdir -p "$HOME/.local/bin"
        run ln -sfn "$ra" "$HOME/.local/bin/rust-analyzer"
      fi
    '';
}
