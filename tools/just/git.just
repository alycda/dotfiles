# delete local branches already merged into origin/main
[group('git')]
del-merged:
    git branch --merged origin/main | grep -v "^\*" | grep -v "main" | xargs git branch -d

# delegate: canonical logic is the git-worktree-clone PATH binary (tools/git-worktree-clone.nix)
[group('git')]
worktree-clone *args:
    git worktree-clone {{args}}
