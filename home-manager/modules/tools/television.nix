{ lib, pkgs, ... }:

# television (tv): modern fuzzy finder (Rust), channel-based architecture
# Unlike fzf's single-stream model, tv has typed "channels":
#   tv files, tv text, tv git-log, tv git-refs, tv shell-history, tv env, tv alias
# No automatic shell keybindings — invoked explicitly as `tv [channel]`
# Tradeoff: more structured/visual than fzf, but less drop-in for existing workflows
{
  home.packages = [ pkgs.television ];

  # Custom cable channels tailored to this repo's tooling. Canonical TOML lives
  # in tools/television/cable/ (editable plaintext, same pattern as tools/helix);
  # this wires each file into television's channel directory.
  #
  # SCHEMA VERIFIED against television 0.15.9 (aarch64-linux dev container),
  # which is what #21 could not do from the build sandbox. All five files parse
  # and resolve as channels; the three doubts #21 raised are settled for 0.15.9:
  #   - the per-file cable/*.toml layout is correct (NOT the older single
  #     channels.toml with [[cable_channel]] + source_command/preview_command);
  #   - the preview placeholder is `{0}`, not `{}` — for jj-log, `{0}` is the
  #     short change id and `jj show <id>` accepts it;
  #   - the [metadata]/[source]/[preview] table split is current.
  # macOS config path VERIFIED (felixia, tv 0.15.9 via mise, Catalina): with
  # XDG_CONFIG_HOME unset, `tv list-channels` picks up
  # ~/.config/television/cable/*.toml, so xdg.configFile lands in the right
  # place there too. The sqlite and apple-notes queries were run against real
  # dbs; postgres/redis queries remain schema-checked only (no live DB). Each
  # DB channel declares `requirements`, so it stays inert on a machine lacking
  # its client rather than erroring at startup.
  # DB channels (sqlite/postgres/redis) are EXAMPLES: their queries reference
  # placeholder tables (tasks/users) and read connection info from the
  # environment ($TV_SQLITE_DB / $DATABASE_URL / $REDIS_URL) — no secrets in the
  # repo. Edit the queries for real schemas. The redis channel is
  # endpoint-agnostic (Upstash now, KeyDB after migration) via redis-cli.
  xdg.configFile = {
    "television/cable/jj-log.toml".source = ../../../tools/television/cable/jj-log.toml;
    "television/cable/cheat.toml".source = ../../../tools/television/cable/cheat.toml;
    "television/cable/claude.toml".source = ../../../tools/television/cable/claude.toml;
    "television/cable/sqlite.toml".source = ../../../tools/television/cable/sqlite.toml;
    "television/cable/postgres.toml".source = ../../../tools/television/cable/postgres.toml;
    "television/cable/redis.toml".source = ../../../tools/television/cable/redis.toml;
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # Read-only Apple Notes browser over NoteStore.sqlite; the path only exists
    # on macOS, and reading it needs Full Disk Access for the calling process.
    "television/cable/apple-notes.toml".source = ../../../tools/television/cable/apple-notes.toml;
  };

  # Wire `tv` into Ctrl+R for shell history as an fzf alternative
  # Remove or adjust if using fzf.nix alongside this module
  programs.zsh.initContent = ''
    tv_history() {
      local selected
      selected=$(tv shell-history 2>/dev/null)
      LBUFFER="$selected"
      zle redisplay
    }
    zle -N tv_history
    bindkey '^R' tv_history
  '';
}
