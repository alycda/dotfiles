# Interactive zsh settings.

# --- line editor ------------------------------------------------------------
# undo keeps zsh's stock emacs keys: ^_, ^Xu, ^X^U. redo has no default key.
# ^X^R replaces _read_comp, which compinit binds there.
bindkey '^X^R' redo

# Expand history designators (!!, !$, !-2, ...) in place on space, so the
# command is visible before Enter runs it.
bindkey ' ' magic-space

# --- chpwd --------------------------------------------------------------------
# Show where you are on entering a repository: `jj log -r @` for jj, else
# `git status -sb`. Quiet while moving inside the same repository. The nearer
# root wins, so a git worktree nested in a jj workspace reports as git.
# --ignore-working-copy keeps cd from snapshotting; @ may lag unsaved edits.
autoload -Uz add-zsh-hook
typeset -g _dotfiles_repo_root=

_dotfiles_repo_status() {
  local jj_root git_root
  (( $+commands[jj] )) && jj_root=$(jj root --ignore-working-copy 2>/dev/null)
  (( $+commands[git] )) && git_root=$(git rev-parse --show-toplevel 2>/dev/null)

  local root=$jj_root kind=jj
  if (( ${#git_root} > ${#jj_root} )); then root=$git_root kind=git; fi

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

# --- history and cd -----------------------------------------------------------
# Sharing and dedupe are already on (macOS /etc/zshrc, home-manager defaults).
setopt EXTENDED_HISTORY HIST_REDUCE_BLANKS HIST_FIND_NO_DUPS
setopt AUTO_CD
alias ..='cd ..' ...='cd ../..'
