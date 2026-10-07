# josh views

Each `.josh` file here is a [josh](https://josh-project.github.io/josh/)
filter that selects one **toolset**'s files from the repository, with
history:

- `minimal.josh`: the **Minimal toolset**, what mise reads (`mise.toml`,
  the mise devcontainer).
- `full.josh`: the **Full toolset**, what Nix reads (the flake,
  `home-manager/`, `darwin/`, `lib/`, the secrets, the Nix devcontainer and
  the Docker image).
- `shared.josh`: the plain-file configs both of them link or copy into
  `$HOME` (`tools/{cheat,git,helix,jujutsu,just,zsh}`, `tasks/scripts`).
  The other two include it with `:+tools/josh/shared`, so the shared list is
  written once.

These are views, not Lanes: a view selects files across the whole history,
while a Lane is a line of Changes. A file belongs to a view when that
toolset reads it. Anything neither toolset reads (the repo's own `justfile`,
`tools/effver`, `tools/setup`, `tasks/`, docs and agent config) is in
neither view.

## Use

josh isn't in either toolset yet; nixpkgs has it:

```sh
# The Full toolset's view of HEAD, written to refs/josh/full
nix shell nixpkgs#josh -c josh-filter ':+tools/josh/full' HEAD --update refs/josh/full
git log --stat refs/josh/full

# Files neither view selects
git ls-tree -r --name-only HEAD | sort > /tmp/all
for v in full minimal; do
  nix shell nixpkgs#josh -c josh-filter ":+tools/josh/$v" HEAD --update refs/josh/$v
  git ls-tree -r --name-only refs/josh/$v
done | sort -u | comm -23 /tmp/all -
```

Served through josh-proxy, the same filter makes a clone with only that view
and its history, and pushes to it are mapped back onto the full repository:

```sh
git clone 'http://<proxy>/alycda/dotfiles.git:+tools/josh/minimal.git'
```

## Writing a filter file

- Pass the filter as `:+tools/josh/<name>`, or as the file's contents with
  its newlines kept (`"$(cat file.josh)"`). `josh-filter --file f.josh REV`
  ignores `REV` and filters HEAD, with no warning.
- Comments are allowed only before the filter starts. A `#` line inside
  `:[ ]` or after the closing `]` is a parse error.
- `josh-filter -p '<filter>'` prints the parsed filter. Run it when a view
  comes out empty: a filter that doesn't parse the way you meant becomes
  `:empty`, and the only other sign is "reference ... wasn't updated".
