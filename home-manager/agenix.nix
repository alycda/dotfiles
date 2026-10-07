# agenix: every secret under secrets/, decrypted into ~/.local/share/agenix
# with the age identity at ~/.age/personal-key.txt.
#
# Each secret installs as ~/.local/share/agenix/<name>, its path under
# secrets/ with the .age dropped (secrets/example.age -> example). Nothing is
# declared per secret here: a consumer reads config.age.secrets.<name>.path.
# The identity is delivered out of band and may be absent; then nothing is
# decrypted and activation says so.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  secretsRoot = ../secrets;

  # secrets/a/b.age -> { "a/b" = ../secrets/a/b.age; }
  ageFiles =
    dir: prefix:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          ageFiles (dir + "/${name}") "${prefix}${name}/"
        else if lib.hasSuffix ".age" name then
          [
            {
              name = prefix + lib.removeSuffix ".age" name;
              file = dir + "/${name}";
            }
          ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  inherit (config.age) secretsDir identityPaths;

  # `age -i` takes the identity repeatedly; an unreadable one is skipped at
  # runtime, not at eval, since it is delivered out of band.
  identityArgs = lib.concatMapStringsSep " " (p: "-i ${lib.escapeShellArg p}") identityPaths;

  installOne =
    s:
    "_agenix_install "
    + lib.escapeShellArg s.name
    + " "
    + lib.escapeShellArg "${s.file}"
    + " "
    + lib.escapeShellArg s.path
    + " "
    + lib.escapeShellArg s.mode
    + "\n";
in
{
  age = {
    # A stable path under ~, which a config file can name. The default on
    # macOS is a shell expression ($(getconf DARWIN_USER_TEMP_DIR)/agenix).
    secretsDir = "${config.home.homeDirectory}/.local/share/agenix";
    identityPaths = [ "${config.home.homeDirectory}/.age/personal-key.txt" ];
    secrets = lib.listToAttrs (
      map (s: {
        inherit (s) name;
        value.file = s.file;
      }) (ageFiles secretsRoot "")
    );
  };

  # Install the secrets from activation, on Linux.
  #
  # ragenix's module installs them from a systemd user service, which the
  # devcontainer and the Docker image don't run (home-manager prints "User
  # systemd daemon not running"), so secrets would silently never arrive. On
  # macOS its module uses a launchd agent instead, which works, so this stays
  # off there rather than race it.
  #
  # Never aborts activation: home-manager runs its steps in order, and dying
  # here would skip installing packages. A failed decrypt warns and goes on.
  home.activation.agenixInstallSecrets = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _agenix_age=${lib.escapeShellArg "${config.age.package}/bin/age"}
      _agenix_dir=${lib.escapeShellArg secretsDir}

      _agenix_install() {
        _name="$1"; _src="$2"; _dest="$3"; _mode="$4"

        # Not through `run`: the decrypt needs its exit status, and `run`
        # returns 0 under dry-run. Bail out here instead, or `switch -n`
        # would really decrypt and leave .tmp files behind.
        if [ -n "''${DRY_RUN+x}" ]; then
          echo "would install agenix secret '$_name' -> $_dest"
          return 0
        fi

        # The canonical copy stays <secretsDir>/<name> even when a secret
        # overrides `path`; the override becomes a symlink to it.
        _canon="$_agenix_dir/$_name"
        run mkdir -p "$(dirname "$_canon")"

        if ! "$_agenix_age" -d ${identityArgs} -o "$_canon.tmp" "$_src" 2>/dev/null; then
          rm -f "$_canon.tmp"
          echo ">> agenix: could not decrypt '$_name' - is the identity present?" >&2
          echo ">>   expected one of: ${lib.concatStringsSep ", " identityPaths}" >&2
          return 0
        fi

        run mv -f "$_canon.tmp" "$_canon"
        run chmod "$_mode" "$_canon"

        if [ "$_dest" != "$_canon" ]; then
          run mkdir -p "$(dirname "$_dest")"
          run ln -sfn "$_canon" "$_dest"
        fi
      }

      ${lib.concatMapStrings installOne (lib.attrValues config.age.secrets)}
      unset -f _agenix_install
    ''
  );
}
