# A release binary from GitHub, patched to run from the Nix store. Used for
# the tools whose release binaries mise installs but nixpkgs lacks (see
# lib/packages/).
#
# The patching:
# - macOS: Ataraxy's binaries load OpenSSL from Homebrew's path
#   (/opt/homebrew/opt/openssl@3, per `otool -L`), so they only run where
#   Homebrew's openssl@3 is installed. They are pointed at nixpkgs' OpenSSL,
#   and re-signed, since editing the load commands breaks the signature and
#   arm64 macOS kills unsigned binaries.
# - Linux: release binaries are linked against an FHS glibc loader, which a
#   Nix-only system (the Docker image) doesn't have. autoPatchelfHook fixes
#   them.
#
# Bumping a tool: change its version, set each hash to lib.fakeHash, build,
# and take the hashes Nix reports.
{ pkgs }:
let
  inherit (pkgs) lib stdenv;
  system = stdenv.hostPlatform.system;
in
{
  pname,
  version,
  bin,
  assets,
}:
let
  asset = assets.${system} or (throw "${pname}: no release asset for ${system}");
in
stdenv.mkDerivation {
  inherit pname version;
  src = pkgs.fetchurl asset;
  sourceRoot = ".";
  unpackPhase = if lib.hasSuffix ".tar.gz" asset.url then "tar xzf $src" else "cp $src ${bin}";
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ pkgs.darwin.autoSignDarwinBinariesHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    pkgs.openssl
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$(find . -type f -name ${bin} | head -n 1)" $out/bin/${bin}
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      for dylib in libssl.3.dylib libcrypto.3.dylib; do
        install_name_tool -change \
          /opt/homebrew/opt/openssl@3/lib/$dylib \
          ${lib.getLib pkgs.openssl}/lib/$dylib \
          $out/bin/${bin}
      done
    ''}
    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/Ataraxy-Labs/${pname}";
    mainProgram = bin;
    platforms = builtins.attrNames assets;
  };
}
