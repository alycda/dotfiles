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
  home.activation.rustupDefaultToolchain =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.rustup}/bin/rustup default stable || true
    '';
}
