_:

# zsh line editor (issue #15): the items starship (#74) left open.
#
# Imported from common.nix, so every profile gets the same bindings. Only
# widgets zsh already ships - no plugin manager (zinit is struck in #15).
#
# The keymap is emacs everywhere: zsh only picks vi when EDITOR/VISUAL
# contains "vi", and EDITOR is hx.
{
  programs.zsh = {
    # Options the 2026-09-16 status comment on #15 listed as worth adding.
    # Sharing and dedupe (SHARE_HISTORY, HIST_IGNORE_DUPS) are already
    # home-manager's defaults.
    history = {
      extended = true; # EXTENDED_HISTORY: timestamps, for `tv shell-history`
      findNoDups = true; # HIST_FIND_NO_DUPS: search skips repeats
    };
    # No typed option for this one; merges with what history sets.
    setOptions = [ "HIST_REDUCE_BLANKS" ];

    autocd = true; # AUTO_CD: a bare directory name cds into it
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    initContent = ''
      # undo keeps zsh's stock emacs keys: ^_, ^Xu, ^X^U. redo ships with no
      # key at all. ^X^R replaces _read_comp, which compinit binds there; this
      # runs after compinit (order 1000 vs 570), so this binding wins.
      bindkey '^X^R' redo

      # Expand history designators (!!, !$, !-2, ...) in place on space, so
      # the command is visible before Enter runs it.
      bindkey ' ' magic-space

      # chpwd: on entering a repository, show where you are - `jj log -r @` for
      # jj, else `git status -sb`. Quiet while moving inside the same one. The
      # nearer root wins, so a git worktree nested in a jj workspace (Claude
      # Code's worktrees) reports as git. --ignore-working-copy keeps a cd from
      # snapshotting, so @ may lag an unsnapshotted edit. add-zsh-hook leaves
      # direnv's own chpwd hook in place.
      autoload -Uz add-zsh-hook
      typeset -g _dotfiles_repo_root=

      _dotfiles_repo_status() {
        local jj_root git_root
        (( $+commands[jj] )) && jj_root=$(jj root --ignore-working-copy 2>/dev/null)
        (( $+commands[git] )) && git_root=$(git rev-parse --show-toplevel 2>/dev/null)

        local root=$jj_root kind=jj
        if (( ''${#git_root} > ''${#jj_root} )); then root=$git_root kind=git; fi

        [[ $root == "$_dotfiles_repo_root" ]] && return
        _dotfiles_repo_root=$root
        [[ -z $root ]] && return

        if [[ $kind == jj ]]; then
          jj log --ignore-working-copy --no-graph -r @ -T builtin_log_oneline
        else
          git status -sb
        fi
      }
      add-zsh-hook chpwd _dotfiles_repo_status
    '';
  };
}
