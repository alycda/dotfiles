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
    initContent = ''
      # undo keeps zsh's stock emacs keys: ^_, ^Xu, ^X^U. redo ships with no
      # key at all. ^X^R replaces _read_comp, which compinit binds there; this
      # runs after compinit (order 1000 vs 570), so this binding wins.
      bindkey '^X^R' redo

      # Expand history designators (!!, !$, !-2, ...) in place on space, so
      # the command is visible before Enter runs it.
      bindkey ' ' magic-space
    '';
  };
}
