{ pkgs, lib, ... }:

let
  # Core packages shared with devShells (defined in lib/core-packages.nix)
  # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  corePackages = import ../../lib/core-packages.nix pkgs;

  # envelope is not yet in nixpkgs - build from source via cargo
  # https://github.com/mattrighetti/envelope
  # After updating version, run `nix build` to get the correct hashes from the error output
  envelope = pkgs.rustPlatform.buildRustPackage {
    pname = "envelope";
    version = "0.7.1";

    src = pkgs.fetchFromGitHub {
      owner = "mattrighetti";
      repo = "envelope";
      rev = "0.7.1";
      hash = lib.fakeHash;
    };

    cargoHash = lib.fakeHash;

    # rusqlite may require system sqlite depending on whether bundled feature is used
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.sqlite ];

    meta = {
      description = "An environment variables cli tool backed by SQLite";
      homepage = "https://github.com/mattrighetti/envelope";
      license = lib.licenses.mit;
      mainProgram = "envelope";
    };
  };
in
{
  imports = [
    ./ide/vscode.nix
    ./dev/nix-lang.nix
    ./tools/cheat.nix
    ./tools/helix.nix
  ];

  home = {
    stateVersion = "25.05";

    # Core packages across all profiles
    # Note: helix is configured via ./tools/helix.nix (programs.helix)
    # Note: claude-code CLI installed here (binary only, config not managed by home-manager)
    packages = corePackages ++ [ pkgs.claude-code envelope ];

    # Set helix as default editor
    sessionVariables = {
      EDITOR = "hx";
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Enable direnv for project-specific environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}