#!/bin/sh
# alycda/dotfiles - lightweight remote bootstrap (no root, no docker, no nix).
#
# Fills the empty cell in the coverage matrix: issue #29 covers machines where
# you ARE admin, docker/dev.sh covers no-admin-but-docker. A Linux box you SSH
# into with neither is uncovered - that is this script.
#
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/bootstrap/lite.sh | sh -s -- all
#
# POSIX sh on purpose, same as docker/dev.sh: the target may have nothing but a
# shell, curl and tar. Nothing here needs a package manager or a writable /nix.
#
# TWO TIERS, installed separately so you can take just the cheap one:
#
#   config  ~700K of plaintext from tools/, symlinked into ~/.config, ~/.agents
#           and ~/.claude. Zero binaries. This is the part that actually
#           carries the knowledge (364K of cheatsheets, 252K of agent
#           instructions).
#   bins    ~10 static binaries into ~/.local/bin. No package manager, no
#           shared-library assumptions beyond libc.
#
# WHAT THIS DELIBERATELY DOES NOT DO (all of it needs Nix or a secret):
#
#   - starship prompt. There is no plain-file starship config in the repo;
#     home-manager/modules/tools/starship.nix generates it from the
#     nerd-font-symbols preset plus Nix-level settings. Adding a checked-in
#     TOML twin would be exactly the drift this script otherwise avoids.
#   - git identity. It lives in an agenix secret (secrets/personal/git-config.age,
#     wired by home-manager/modules/git.nix). `bins` installs `rage`, so you can
#     decrypt it by hand once the age key is staged, but nothing here does it
#     for you.
#   - the private agent overlay (~/.agents/instructions.private.md) - same
#     reason. The five PUBLIC layers do get installed.
#   - the ~/.claude/settings.json deep-merge that claude-code.nix performs. It
#     needs jq, it mutates a file Claude Code owns at runtime, and the plugin
#     half of it (tools/agents/plugins/catalog.json) makes Claude fetch
#     marketplaces on next start. Too much side effect for a bootstrap; do a
#     real home-manager switch if you want it.
#   - checksum pinning on the downloaded binaries. Versions are pinned, the
#     transport is https, but a compromised upstream release would not be
#     caught. Known gap, tracked in the issue.
#
# LINUX ONLY, x86_64 and aarch64. macOS is not a gap: a Mac you can log into is
# a Mac where you can install Nix (#29) or run docker (docker/dev.sh).

set -eu

REF="${REF:-main}"
TARBALL_URL="${TARBALL_URL:-https://codeload.github.com/alycda/dotfiles/tar.gz/refs/heads/$REF}"
LITE_HOME="${LITE_HOME:-$HOME/.local/share/dotfiles-lite}"
LITE_BIN="${LITE_BIN:-$HOME/.local/bin}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

TOOLS="$LITE_HOME/tools"
ENV_FILE="$LITE_HOME/env.sh"
HELIX_RUNTIME_DIR="$LITE_HOME/helix-runtime"

say()  { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31mlite.sh: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
usage: lite.sh <command> [tool...]

  config       install the plaintext config tier (tools/ -> ~/.config, ~/.agents)
  bins [tool]  install static binaries into ~/.local/bin (default: all of them)
  all          config + bins
  env          print the shell snippet that puts them on PATH
  list         show the pinned binary table for this machine
  uninstall    remove everything this script installed
  doctor       report what is installed and what is missing

env overrides: REF          git ref to fetch          (default: main)
               LITE_HOME    state + tools tree        (default: ~/.local/share/dotfiles-lite)
               LITE_BIN     binary install dir        (default: ~/.local/bin)
               LITE_SOURCE  path to a dotfiles checkout to use instead of fetching

After `config` or `bins`, add this to your shell rc:

  . ~/.local/share/dotfiles-lite/env.sh
USAGE
}

# --- platform -----------------------------------------------------------

detect_platform() {
  [ "$(uname -s)" = "Linux" ] || die "Linux only (got $(uname -s)). On macOS use issue #29's installer or docker/dev.sh."
  case "$(uname -m)" in
    x86_64|amd64)  ARCH=x86_64 ;;
    aarch64|arm64) ARCH=aarch64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"
}

# --- the tools/ tree ----------------------------------------------------

# Local mode mirrors docker/dev.sh's build-local: if this file is a real path
# inside a checkout, use that checkout. Piped through `curl | sh`, $0 is "sh"
# (not a readable path), so the check falls through to the fetch - which is the
# whole point of the pipe form.
find_local_checkout() {
  if [ -n "${LITE_SOURCE:-}" ]; then
    printf '%s' "$LITE_SOURCE"
    return 0
  fi
  [ -f "$0" ] || return 1
  d=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || return 1
  [ -d "$d/tools/cheat/cheatsheets" ] || return 1
  printf '%s' "$d"
}

fetch_tools() {
  if src=$(find_local_checkout); then
    say "-> using local checkout: $src"
    [ -d "$src/tools" ] || die "$src has no tools/ directory"
    rm -rf "$TOOLS"
    mkdir -p "$LITE_HOME"
    cp -R "$src/tools" "$TOOLS"
    ok "copied tools/ from $src"
    return
  fi

  need curl
  need tar
  say "-> fetching tools/ from $TARBALL_URL"
  tmp=$(mktemp -d) || die "mktemp failed"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT INT TERM
  curl -fsSL "$TARBALL_URL" | tar -xzf - -C "$tmp" ||
    die "could not fetch or unpack $TARBALL_URL"
  # The tarball's top-level directory is dotfiles-<ref>; do not hardcode it,
  # refs with slashes get mangled into the name.
  extracted=$(find "$tmp" -maxdepth 2 -type d -name tools | head -1)
  [ -n "$extracted" ] || die "tarball contained no tools/ directory"
  rm -rf "$TOOLS"
  mkdir -p "$LITE_HOME"
  cp -R "$extracted" "$TOOLS"
  rm -rf "$tmp"
  trap - EXIT INT TERM
  ok "unpacked tools/ ($(du -sh "$TOOLS" | cut -f1))"
}

# --- linking ------------------------------------------------------------

# Never clobber. A real file at the destination is someone's existing config;
# move it aside loudly rather than replacing it, because the failure mode of
# silently eating a hand-written ~/.config/helix/config.toml on a shared remote
# box is unrecoverable.
link() { # src dest
  src="$1"; dest="$2"
  [ -e "$src" ] || { warn "skip (missing in tools/): $src"; return 0; }
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    rm -f "$dest"
  elif [ -e "$dest" ]; then
    mv "$dest" "$dest.pre-lite"
    warn "backed up existing $dest -> $dest.pre-lite"
  fi
  ln -s "$src" "$dest"
}

# Refuse to fight home-manager over the same paths. `link()` replaces existing
# symlinks without backing them up (a symlink is assumed to be ours), and on a
# switched machine ~/.config/helix/config.toml is a symlink into the nix store.
# Clobbering it is recoverable - the next `home-manager switch` puts it back -
# but silently detaching a managed config from its generation is not something
# to do by accident, and `just lite-config` in the wrong terminal is an easy
# accident to have.
refuse_if_home_manager() {
  [ -n "${LITE_FORCE:-}" ] && return 0
  for marker in "$HOME/.local/state/nix/profiles/home-manager" \
                "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"; do
    if [ -e "$marker" ]; then
      die "home-manager is active on this machine ($marker).
  lite.sh would replace its managed symlinks. Use \`home-manager switch\` instead,
  or set LITE_FORCE=1 if you really mean it."
    fi
  done
  return 0
}

install_config() {
  refuse_if_home_manager
  fetch_tools

  say "-> helix"
  link "$TOOLS/helix/config.toml"      "$XDG_CONFIG_HOME/helix/config.toml"
  link "$TOOLS/helix/languages.toml"   "$XDG_CONFIG_HOME/helix/languages.toml"
  link "$TOOLS/helix/themes/mine.toml" "$XDG_CONFIG_HOME/helix/themes/mine.toml"
  link "$TOOLS/helix/ignore"           "$XDG_CONFIG_HOME/helix/ignore"
  ok "config.toml, languages.toml, themes/mine.toml, ignore"

  # These TOMLs are dead weight everywhere else in the repo: helix.nix
  # re-encodes the same settings in Nix by hand (tools/helix/README.md calls it
  # "manually translated"). Consuming them here is the point - it makes the
  # plaintext load-bearing instead of decorative, so drift between the two
  # becomes a thing you notice.

  say "-> cheat"
  # conf.nix hardcodes `pager: bat --paging=auto`, which is safe under Nix
  # because lib/core-packages.nix guarantees bat is in the same closure. Here it
  # is not: `config` can run without `bins` at all, and even `all` writes this
  # file before bat is downloaded. cheat treats a missing pager as fatal - it
  # fails the whole lookup with "failed to write to pager", so you get the
  # cheatsheets installed and unreadable. Resolve at call time instead of at
  # generation time.
  mkdir -p "$LITE_HOME"
  cat > "$LITE_HOME/pager.sh" <<'PAGER'
#!/bin/sh
# Generated by bootstrap/lite.sh. Whatever pager this machine actually has.
if command -v bat >/dev/null 2>&1; then exec bat --paging=auto "$@"; fi
if command -v less >/dev/null 2>&1; then exec less -FRX "$@"; fi
exec cat "$@"
PAGER
  chmod +x "$LITE_HOME/pager.sh"

  # cheat needs absolute cheatpaths, so this file is generated rather than
  # linked - the same job tools/cheat/conf.nix does for the Nix path, where the
  # paths point into the store instead of $HOME.
  mkdir -p "$XDG_CONFIG_HOME/cheat"
  cat > "$XDG_CONFIG_HOME/cheat/conf.yml" <<EOF
# Generated by bootstrap/lite.sh - edits will be overwritten.
# Nix equivalent: tools/cheat/conf.nix
editor: hx
colorize: true
style: monokai
formatter: terminal256
pager: $LITE_HOME/pager.sh
cheatpaths:
  - name: community
    path: $TOOLS/cheat/cheatsheets/community
    tags: [ community ]
    readonly: true
  - name: personal
    path: $TOOLS/cheat/cheatsheets/personal
    tags: [ personal ]
    readonly: true
EOF
  ok "conf.yml -> $(find "$TOOLS/cheat/cheatsheets" -type f | wc -l) cheatsheets"

  say "-> agents (public layers only)"
  for f in AGENTS.md company-values.md personal-constitution.md \
           personal-constitution-distilled.md preferred-tooling.md; do
    link "$TOOLS/agents/$f" "$HOME/.agents/$f"
  done
  # Same include names home-manager/modules/tools/agents.nix uses, so a machine
  # that later gets a real switch lands on identical paths.
  link "$HOME/.agents/company-values.md" \
       "$HOME/.claude/includes/agents-company-values.md"
  link "$HOME/.agents/preferred-tooling.md" \
       "$HOME/.claude/includes/agents-preferred-tooling.md"
  link "$HOME/.agents/personal-constitution-distilled.md" \
       "$HOME/.claude/includes/agents-personal-constitution-distilled.md"
  ok "5 public layers + 3 ~/.claude/includes symlinks"
  warn "no instructions.private.md - the encrypted overlay needs the age key"

  say "-> claude rules"
  link "$TOOLS/claude/rules/outbound-comment-gate.md" \
       "$HOME/.claude/rules/outbound-comment-gate.md"
  # Idempotent @import, same contract as claude-code.nix's activation script.
  claude_md="$HOME/.claude/CLAUDE.md"
  import_line="@rules/outbound-comment-gate.md"
  if [ ! -f "$claude_md" ] || ! grep -qxF "$import_line" "$claude_md" 2>/dev/null; then
    mkdir -p "$HOME/.claude"
    printf '\n%s\n' "$import_line" >> "$claude_md"
    ok "appended $import_line to ~/.claude/CLAUDE.md"
  else
    ok "@import already present"
  fi

  say "-> television"
  # Only the channel television.nix actually enables; the rest are commented
  # out there as unverified against the current schema.
  link "$TOOLS/television/cable/cheat.toml" \
       "$XDG_CONFIG_HOME/television/cable/cheat.toml"
  ok "cable/cheat.toml"

  write_env
}

# --- binaries -----------------------------------------------------------

# name|repo|tag|asset-x86_64|asset-aarch64|binary-name
#
# Pinned rather than resolved from /releases/latest on purpose: the redirect and
# api.github.com are the first things an egress proxy blocks, and a bootstrap
# script that only works on an unfiltered network is not a bootstrap script.
# Override a single tool with e.g. VER_ripgrep=14.1.2 (tag substitution only -
# if upstream also renames the asset, edit the row).
#
# Every URL below was probed for a 200 on both architectures on 2026-08-14.
# Four upstream asymmetries the table has to absorb, none of them guessable:
#   - ripgrep and television publish no aarch64 *musl* build, only gnu;
#   - rage calls arm64 "arm64-linux", not "aarch64-*";
#   - cheat ships a bare gzipped binary (.gz, not .tar.gz) whose filename
#     carries no version, so a VER_ override changes only the URL's tag;
#   - television's tag has no leading "v", unlike almost everything else.
bin_table() {
  cat <<'TABLE'
helix|helix-editor/helix|25.07.1|helix-25.07.1-x86_64-linux.tar.xz|helix-25.07.1-aarch64-linux.tar.xz|hx
cheat|cheat/cheat|4.5.0|cheat-linux-amd64.gz|cheat-linux-arm64.gz|cheat
ripgrep|BurntSushi/ripgrep|14.1.1|ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz|ripgrep-14.1.1-aarch64-unknown-linux-gnu.tar.gz|rg
jq|jqlang/jq|jq-1.8.1|jq-linux-amd64|jq-linux-arm64|jq
fzf|junegunn/fzf|v0.65.0|fzf-0.65.0-linux_amd64.tar.gz|fzf-0.65.0-linux_arm64.tar.gz|fzf
starship|starship/starship|v1.23.0|starship-x86_64-unknown-linux-musl.tar.gz|starship-aarch64-unknown-linux-musl.tar.gz|starship
jj|jj-vcs/jj|v0.35.0|jj-v0.35.0-x86_64-unknown-linux-musl.tar.gz|jj-v0.35.0-aarch64-unknown-linux-musl.tar.gz|jj
gh|cli/cli|v2.80.0|gh_2.80.0_linux_amd64.tar.gz|gh_2.80.0_linux_arm64.tar.gz|gh
rage|str4d/rage|v0.11.1|rage-v0.11.1-x86_64-linux.tar.gz|rage-v0.11.1-arm64-linux.tar.gz|rage
bat|sharkdp/bat|v0.25.0|bat-v0.25.0-x86_64-unknown-linux-musl.tar.gz|bat-v0.25.0-aarch64-unknown-linux-musl.tar.gz|bat
eza|eza-community/eza|v0.23.0|eza_x86_64-unknown-linux-musl.tar.gz|eza_aarch64-unknown-linux-gnu.tar.gz|eza
television|alexpasmantier/television|0.14.0|tv-0.14.0-x86_64-unknown-linux-musl.tar.gz|tv-0.14.0-aarch64-unknown-linux-gnu.tar.gz|tv
TABLE
}

bin_row() { bin_table | grep "^$1|" || true; }

# Fields for $1 land in NAME REPO TAG ASSET BINARY for the current $ARCH.
bin_fields() {
  row=$(bin_row "$1")
  [ -n "$row" ] || return 1
  NAME=$(printf '%s' "$row" | cut -d'|' -f1)
  REPO=$(printf '%s' "$row" | cut -d'|' -f2)
  TAG=$(printf '%s' "$row" | cut -d'|' -f3)
  if [ "$ARCH" = "x86_64" ]; then
    ASSET=$(printf '%s' "$row" | cut -d'|' -f4)
  else
    ASSET=$(printf '%s' "$row" | cut -d'|' -f5)
  fi
  BINARY=$(printf '%s' "$row" | cut -d'|' -f6)
  # Per-tool version override, e.g. VER_ripgrep=14.1.2.
  override=$(eval "printf '%s' \"\${VER_$NAME:-}\"")
  if [ -n "$override" ]; then
    ASSET=$(printf '%s' "$ASSET" | sed "s/${TAG#v}/${override#v}/g")
    TAG="$override"
  fi
}

unpack() { # archive destdir
  case "$1" in
    *.tar.gz|*.tgz) tar -xzf "$1" -C "$2" ;;
    *.tar.xz)
      # busybox tar has no -J; fall back to piping through xz if it exists.
      tar -xJf "$1" -C "$2" 2>/dev/null ||
        { command -v xz >/dev/null 2>&1 || return 2; xz -dc "$1" | tar -xf - -C "$2"; } ;;
    *) return 1 ;;
  esac
}

install_bin() { # tool
  bin_fields "$1" || { warn "unknown tool: $1"; return 0; }
  url="https://github.com/$REPO/releases/download/$TAG/$ASSET"
  mkdir -p "$LITE_BIN"

  tmp=$(mktemp -d) || die "mktemp failed"
  if ! curl -fsSL --retry 2 -o "$tmp/$ASSET" "$url"; then
    rm -rf "$tmp"
    warn "$NAME: download failed ($url)"
    return 0
  fi

  case "$ASSET" in
    *.tar.*|*.tgz)
      if ! unpack "$tmp/$ASSET" "$tmp"; then
        rm -rf "$tmp"
        warn "$NAME: cannot unpack $ASSET (need xz for .tar.xz?)"
        return 0
      fi
      # Locate by exact name rather than encoding a path per tool - the layouts
      # differ (gh nests bin/, eza is flat) and rage ships rage-mount alongside
      # the binary we want.
      found=$(find "$tmp" -type f -name "$BINARY" | head -1)
      if [ -z "$found" ]; then
        rm -rf "$tmp"
        warn "$NAME: no '$BINARY' inside $ASSET (upstream layout changed?)"
        return 0
      fi
      cp "$found" "$LITE_BIN/$BINARY"
      # helix refuses to start without its tree-sitter grammars and queries.
      if [ "$NAME" = "helix" ]; then
        rt=$(find "$tmp" -type d -name runtime | head -1)
        if [ -n "$rt" ]; then
          rm -rf "$HELIX_RUNTIME_DIR"
          mkdir -p "$LITE_HOME"
          cp -R "$rt" "$HELIX_RUNTIME_DIR"
        else
          warn "helix: no runtime/ in the tarball - grammars will be missing"
        fi
      fi
      ;;
    *.gz)
      # Bare gzipped binary, not a tarball (cheat). Must come after the
      # *.tar.* branch above or every .tar.gz would land here.
      if command -v gzip >/dev/null 2>&1; then
        gzip -dc "$tmp/$ASSET" > "$LITE_BIN/$BINARY"
      else
        rm -rf "$tmp"
        warn "$NAME: needs gzip to unpack $ASSET"
        return 0
      fi
      ;;
    *) cp "$tmp/$ASSET" "$LITE_BIN/$BINARY" ;;
  esac

  chmod +x "$LITE_BIN/$BINARY"
  rm -rf "$tmp"
  ok "$BINARY  ($TAG)"
}

install_bins() {
  need curl
  need tar
  say "-> installing binaries into $LITE_BIN ($ARCH)"
  if [ $# -eq 0 ]; then
    bin_table | cut -d'|' -f1 | while read -r t; do install_bin "$t"; done
  else
    for t in "$@"; do install_bin "$t"; done
  fi
  write_env
}

# --- env ----------------------------------------------------------------

write_env() {
  mkdir -p "$LITE_HOME"
  cat > "$ENV_FILE" <<EOF
# Generated by bootstrap/lite.sh. Source this from your shell rc:
#   . $ENV_FILE
case ":\$PATH:" in
  *":$LITE_BIN:"*) ;;
  *) PATH="$LITE_BIN:\$PATH"; export PATH ;;
esac
# if/fi rather than trailing \`&&\` chains: this file gets sourced from a shell
# rc, and a final AND-list whose test fails makes \`.\` return non-zero - enough
# to abort an rc running under \`set -e\`.
if [ -d "$HELIX_RUNTIME_DIR" ]; then
  export HELIX_RUNTIME="$HELIX_RUNTIME_DIR"
fi
if [ -f "$XDG_CONFIG_HOME/cheat/conf.yml" ]; then
  export CHEAT_CONFIG_PATH="$XDG_CONFIG_HOME/cheat/conf.yml"
fi
if command -v hx >/dev/null 2>&1; then
  export EDITOR=hx
fi
# starship has no plain-file config in this repo (see the header): this is the
# stock prompt, not the nerd-font-symbols one home-manager builds.
if command -v starship >/dev/null 2>&1; then
  if [ -n "\${ZSH_VERSION:-}" ]; then
    eval "\$(starship init zsh)"
  elif [ -n "\${BASH_VERSION:-}" ]; then
    eval "\$(starship init bash)"
  fi
fi
true
EOF
  say "-> wrote $ENV_FILE"
  printf '   add to your shell rc:  \033[1m. %s\033[0m\n' "$ENV_FILE"
}

# --- introspection ------------------------------------------------------

cmd_list() {
  printf '%-10s %-10s %s\n' TOOL VERSION ASSET
  bin_table | cut -d'|' -f1 | while read -r t; do
    bin_fields "$t"
    printf '%-10s %-10s %s\n' "$NAME" "$TAG" "$ASSET"
  done
}

cmd_doctor() {
  say "-> config"
  for p in "$XDG_CONFIG_HOME/helix/config.toml" "$XDG_CONFIG_HOME/cheat/conf.yml" \
           "$HOME/.agents/AGENTS.md" "$HOME/.claude/rules/outbound-comment-gate.md"; do
    if [ -e "$p" ]; then ok "present: $p"; else warn "missing: $p"; fi
  done
  say "-> binaries"
  bin_table | cut -d'|' -f6 | while read -r b; do
    if [ -x "$LITE_BIN/$b" ]; then ok "present: $b"; else warn "missing: $b"; fi
  done
  say "-> not covered by lite.sh (needs nix or the age key)"
  warn "starship config, git identity, private agent overlay, claude settings merge"
}

cmd_uninstall() {
  say "-> removing symlinks that point into $LITE_HOME"
  for d in "$XDG_CONFIG_HOME/helix" "$XDG_CONFIG_HOME/television" "$HOME/.agents" \
           "$HOME/.claude/includes" "$HOME/.claude/rules"; do
    [ -d "$d" ] || continue
    find "$d" -type l 2>/dev/null | while read -r l; do
      case "$(readlink "$l")" in
        "$LITE_HOME"*|"$HOME/.agents"*) rm -f "$l"; ok "unlinked $l" ;;
      esac
    done
  done
  rm -f "$XDG_CONFIG_HOME/cheat/conf.yml"
  say "-> removing binaries"
  # if/fi, not `[ -e x ] && { ...; }`. As the last command in the loop body,
  # a false test makes the whole pipeline exit 1, and under `set -e` that
  # aborted uninstall before it reached the lines below - leaving $LITE_HOME
  # behind whenever the last tool in the table happened not to be installed.
  bin_table | cut -d'|' -f6 | while read -r b; do
    if [ -e "$LITE_BIN/$b" ]; then
      rm -f "$LITE_BIN/$b"
      ok "removed $b"
    fi
  done
  say "-> removing $LITE_HOME"
  rm -rf "$LITE_HOME"
  warn "left alone: *.pre-lite backups, and the @import line in ~/.claude/CLAUDE.md"
}

# --- main ---------------------------------------------------------------

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  config)    detect_platform; install_config ;;
  bins)      detect_platform; install_bins "$@" ;;
  all)       detect_platform; install_config; install_bins ;;
  env)       cat "$ENV_FILE" 2>/dev/null || die "no $ENV_FILE yet - run 'lite.sh config' first" ;;
  list)      detect_platform; cmd_list ;;
  doctor)    detect_platform; cmd_doctor ;;
  uninstall) cmd_uninstall ;;
  ''|-h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
