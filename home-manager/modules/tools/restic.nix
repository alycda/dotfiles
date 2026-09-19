# restic - the offsite backup client, and one scheduled backup of $HOME.
#
# The strategy is in docs/backup-strategy.md; the short form: restic holds the
# backup tier (client-side encrypted, deduplicated across machines, per-host
# retention) and nothing else does, so the sync stores (iCloud, Drive, Proton)
# stop being mistaken for one. The repository lives on rsync.net over SFTP or
# on R2 over S3 - the choice is a line in the secret, not in this module, and
# `restic copy` moves snapshots between the two.
#
# Three plain files under tools/restic/ are the whole configuration, shared
# with the accounts that have no Nix (tools/mise/*/config.toml run the same
# script as `mise run backup`), on the helix.nix pattern of reading a file the
# tool loads anyway rather than restating it in Nix:
#   backup.sh      the run: backup $HOME, then forget --prune under the policy
#   excludes.txt   what not to store
# This module owns what is tied to the store or a secret: the restic package,
# the wrapper that fills in the store paths, the agenix secret that carries the
# repository URL and password, and the launchd schedule.
#
# The secret. secrets/personal/restic-env.age is an env file (RESTIC_REPOSITORY,
# RESTIC_PASSWORD) and the committed ciphertext is a PLACEHOLDER, like
# venice-api-key.age, so this module evaluates and switches before the
# repository exists. backup.sh refuses to run against the placeholder - `init`
# against it would key the repository to the word PLACEHOLDER. First-time
# setup, in order:
#   just edit-secret personal/restic-env.age    # real URL + a generated password
#   home-manager switch ...                     # or darwin-rebuild
#   restic-backup init                          # once per repository
#   restic-backup                               # first snapshot, by hand
# Keep the password somewhere that is not this repository or the machine
# being backed up (Proton Pass). Losing it loses every snapshot.
#
# macOS runs the schedule through launchd, not cron, so a missed slot (lid
# closed) runs at the next wake instead of being skipped. Two things launchd
# does not do for you:
#   - Full Disk Access. Without it TCC hides ~/Library/Mail, Messages, Safari
#     and the like from the backup; restic logs permission errors and exits 3,
#     which backup.sh treats as "snapshot done, some files unreadable". Grant
#     it to the restic binary in System Settings > Privacy & Security, and
#     again after a restic bump: the grant is on the store path.
#   - SSH keys. The wrapper deliberately does not put nixpkgs' openssh on
#     PATH: restic's sftp backend execs `ssh`, and Apple's /usr/bin/ssh is the
#     one that reads the login keychain (UseKeychain), so a passphrase-protected
#     key works under launchd without an agent. launchd's default PATH has it.
#
# Opt-in, default off: common.nix imports this so every profile has the
# option, and the desktop profiles turn it on gated to Darwin. The containers
# have nothing worth a snapshot, and work.nix is also alyssa@work-dev.
{ config, lib, pkgs, ... }:
let
  cfg = config.resticBackup;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  backupScript = pkgs.writeShellApplication {
    name = "restic-backup";
    # coreutils for uname (the host tag); ssh comes from the system, see above.
    runtimeInputs = [ pkgs.restic pkgs.coreutils ];
    text = ''
      export RESTIC_ENV_FILE="''${RESTIC_ENV_FILE:-${config.age.secrets.restic-env.path}}"
      export RESTIC_EXCLUDES="''${RESTIC_EXCLUDES:-${../../../tools/restic/excludes.txt}}"
    '' + builtins.readFile ../../../tools/restic/backup.sh;
  };

  logFile = "${config.home.homeDirectory}/Library/Logs/restic-backup.log";
in
{
  options.resticBackup = {
    enable = lib.mkEnableOption ''
      restic, a `restic-backup` wrapper bound to the repository in
      secrets/personal/restic-env.age, and (on Darwin) a daily launchd run
    '';

    schedule = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.int);
      default = [ { Hour = 13; Minute = 0; } ];
      description = ''
        launchd StartCalendarInterval entries for the scheduled run. Midday
        by default: a laptop is more likely awake and on a network then than
        at 02:00, and launchd runs a slot missed while asleep at the next
        wake anyway.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.restic backupScript ];

    # Identity and secretsDir come from ../git.nix. No `path` override: the
    # default under ~/.local/share/agenix is fine, only the wrapper reads it.
    age.secrets.restic-env.file = ../../../secrets/personal/restic-env.age;

    launchd.agents.restic-backup = lib.mkIf isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${backupScript}/bin/restic-backup" ];
        StartCalendarInterval = cfg.schedule;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
      };
    };
  };
}
