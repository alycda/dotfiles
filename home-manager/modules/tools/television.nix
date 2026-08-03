{ pkgs, ... }:

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
  # VERIFY LOCALLY (can't run `tv` in the build sandbox — schema is version-
  # dependent): after a switch, run `tv jj-log` / `tv cheat`. If a channel
  # errors, check `tv --version` against the docs —
  #   - older builds used one ~/.config/television/channels.toml with
  #     [[cable_channel]] + source_command/preview_command;
  #   - the preview placeholder may be `{}` rather than `{0}`;
  #   - on macOS confirm tv reads ~/.config/television (not ~/Library/...).
  # DB channels (sqlite/postgres/redis) are EXAMPLES: their queries reference
  # placeholder tables (tasks/users) and read connection info from the
  # environment ($TV_SQLITE_DB / $DATABASE_URL / $REDIS_URL) — no secrets in the
  # repo. Edit the queries for real schemas. The redis channel is
  # endpoint-agnostic (Upstash now, KeyDB after migration) via redis-cli.
  xdg.configFile = {
    # "television/cable/jj-log.toml".source = ../../../tools/television/cable/jj-log.toml; # unverified
    "television/cable/cheat.toml".source = ../../../tools/television/cable/cheat.toml;
    # "television/cable/sqlite.toml".source = ../../../tools/television/cable/sqlite.toml; # unverified
    # "television/cable/postgres.toml".source = ../../../tools/television/cable/postgres.toml; # unverified
    # "television/cable/redis.toml".source = ../../../tools/television/cable/redis.toml; # unverified
  };

  # Wire `tv` into Ctrl+R for shell history as an fzf alternative
  # Remove or adjust if using fzf.nix alongside this module
  programs.zsh.initExtra = ''
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
