# Install agenix secrets from the activation script instead of systemd.
#
# PROVENANCE: this file is taken from the unmerged `feat/cloudflare-docs-mcp`
# branch, where it was written for the same reason it is needed here. It is
# carried into this branch because without it `hackmd.account` is a no-op in the
# container - the token silently never arrives, and hackmd-cli reports "no API
# token" while pointing at an identity that is in fact present. If the two
# branches both land, this is one file to reconcile, not two designs.
#
# ragenix's home-manager module mounts secrets from a systemd *user* service
# (config.systemd.user.services.agenix -> agenix-home-manager-mount-secrets).
# It contributes no activation step at all. The dev container has no user
# systemd daemon - `home-manager switch` prints "User systemd daemon not
# running. Skipping reload." - so that unit never runs and every `age.secrets`
# entry silently never arrives. The mount script is not even realised into the
# store there, because nothing in the activation closure references it.
#
# Silently is the operative word, and why this module exists rather than a note
# in the README. Nothing fails. `home-manager switch` reports success, the
# generation links, and the only evidence is a file that is not there:
# ~/.agents/instructions.private.md was missing for months, leaving
# ~/.claude/includes/agents-instructions.private.md a dangling symlink and the
# `@includes/agents-instructions.private.md` line in ~/.claude/CLAUDE.md a dead
# import. An agent read that CLAUDE.md every session and simply never received
# the private overlay.
#
# Imported by the container profile only (profiles/dev.nix). Darwin installs
# secrets through ragenix.darwinModules and must not get a second installer
# racing it. That scoping is deliberate: the alternative - one shared module
# that probes whether systemd is usable - puts the machine that can't be tested
# from here in charge of choosing a code path. NOTE this leaves alyssa@work-dev
# uncovered: it is a Linux container too, but profiles/work.nix is shared with
# darwin, so it needs the same decision made for it separately.
#
# Never aborts activation. A failed decrypt warns and continues, because
# home-manager runs activation steps in order and dying here would skip
# installPackages - the exact failure shape that left a container with dotfiles
# and no claude/jj/rg in #74. A loud warning is the fix for silence; a hard
# failure would trade one broken container for another.
{
  config,
  lib,
  ...
}:
let
  inherit (config.age) secretsDir identityPaths;

  # `age -i` accepts the identity repeatedly; unreadable ones are skipped at
  # runtime rather than at eval, since the identity is delivered out of band
  # (docker cp) and may legitimately be absent when the closure is built.
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
  home.activation.agenixInstallSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _agenix_age=${lib.escapeShellArg "${config.age.package}/bin/age"}
    _agenix_dir=${lib.escapeShellArg secretsDir}

    _agenix_install() {
      _name="$1"; _src="$2"; _dest="$3"; _mode="$4"

      # The decrypt cannot go through `run`: it needs its exit status to decide
      # whether to warn, and `run` returns 0 unconditionally under dry-run. So
      # bail out here instead, or `switch -n` would really decrypt and leave
      # .tmp files behind - a dry run with side effects.
      if [ -n "''${DRY_RUN+x}" ]; then
        echo "would install agenix secret '$_name' -> $_dest"
        return 0
      fi

      # The canonical location stays <secretsDir>/<name> even when a secret
      # overrides `path`, because that default is what consumers hardcode
      # - the cloudflare headersHelper reads
      # ~/.local/share/agenix/cloudflare-api-token by name. A `path` override
      # then becomes a symlink to it rather than a second copy of the plaintext.
      _canon="$_agenix_dir/$_name"

      run mkdir -p "$_agenix_dir"

      if ! "$_agenix_age" -d ${identityArgs} -o "$_canon.tmp" "$_src" 2>/dev/null; then
        rm -f "$_canon.tmp"
        echo ">> agenix: could not decrypt '$_name' - is the identity present?" >&2
        echo ">>   expected one of: ${lib.concatStringsSep ", " identityPaths}" >&2
        echo ">>   recover with: docker cp ~/.age/personal-key.txt <container>:/root/.age/personal-key.txt" >&2
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
  '';
}
