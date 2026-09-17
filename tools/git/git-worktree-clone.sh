# git worktree-clone [clone-flags...] <url|owner/repo> [dir]
#
# One-command bare-repo worktree layout:
#   <dir>/.bare     bare repository (all git data)
#   <dir>/.git      "gitdir: ./.bare" pointer so git works from <dir>
#   <dir>/<branch>  one worktree per branch, starting with the default branch
#
# Flags pass through to `git clone` — repo-specific speedups (e.g. a partial
# clone filter like --filter=blob:none) are documented by the target repo's
# README, not baked in here. Use the --flag=value form: a detached value
# ("--depth 1") would be read as a positional argument.
#
# Wrapped by writeShellApplication (git-worktree-clone.nix): bash with
# `set -euo pipefail`, shellcheck-clean, git pinned on PATH.

usage() {
  echo "usage: git worktree-clone [clone-flags...] <url|owner/repo> [dir]" >&2
  exit 2
}

flags=()
positional=()
for arg in "$@"; do
  case "$arg" in
    -h | --help) usage ;;
    -*) flags+=("$arg") ;;
    *) positional+=("$arg") ;;
  esac
done

case "${#positional[@]}" in
  1) url="${positional[0]}" dir="" ;;
  2) url="${positional[0]}" dir="${positional[1]}" ;;
  *) usage ;;
esac

case "$url" in
  # full URLs, scp-style remotes, and local paths pass through untouched
  *://* | *@*:* | /* | ./* | ../*) ;;
  # owner/repo shorthand -> GitHub over https (gh's credential helper covers auth)
  */*) url="https://github.com/${url}.git" ;;
  *) usage ;;
esac

[ -n "$dir" ] || dir=$(basename "$url" .git)

# fail before cloning, not mid-recipe, if the target is already a checkout
if [ -e "$dir/.bare" ] || [ -e "$dir/.git" ]; then
  echo "error: $dir already contains a .bare or .git — refusing to clobber" >&2
  exit 1
fi

git clone --bare "${flags[@]}" "$url" "$dir/.bare"
echo "gitdir: ./.bare" >"$dir/.git"
# bare clones only ever fetch HEAD unless told otherwise
git -C "$dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
branch=$(git -C "$dir" symbolic-ref --short HEAD)
git -C "$dir" worktree add "$branch" "$branch"
echo "ready: $dir/$branch — more branches: git -C $dir worktree add <branch> <branch>"
