{ ... }:

# fzf: mature fuzzy finder (Go), battle-tested shell integrations
# Activates Ctrl+R (history), Ctrl+T (files), Alt+C (dirs) in zsh
# Preview powered by bat + ripgrep (already in core packages)
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;

    # Respect .gitignore; surface hidden files that aren't git internals
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";

    defaultOptions = [
      "--height=50%"
      "--layout=reverse"
      "--border=rounded"
      "--preview='bat --style=numbers,changes --color=always --line-range=:200 {}'"
      "--preview-window=right:55%:wrap"
    ];

    # Ctrl+T file picker
    fileWidgetCommand = "rg --files --hidden --follow --glob '!.git'";
    fileWidgetOptions = [
      "--preview 'bat --style=numbers,changes --color=always --line-range=:300 {}'"
    ];

    # Alt+C directory picker
    changeDirWidgetOptions = [
      "--preview 'ls -la {}'"
    ];
  };
}
