# The shell is zsh, not bash

Every shell you drive on my machines is zsh: the one that runs your shell
commands locally, and the remote side of `ssh host '...'` wherever my login
shell is zsh (`ssh host cmd` runs `$SHELL -c cmd`). Write for zsh, or wrap the
command in `bash -c '...'` on purpose. Don't write bash and assume it runs as
bash. Two differences keep causing failures:

- **zsh doesn't word-split.** An unquoted `$var` is one word, so a command
  prefix kept in a string runs as a single program named by the whole string:

  ```sh
  B="env -i HOME=$HOME /usr/local/bin/brew"; $B info x
  # zsh: no such file or directory: env -i HOME=... /usr/local/bin/brew
  ```

  Use a function (`b() { env -i HOME="$HOME" /usr/local/bin/brew "$@"; }`)
  or an array (`cmd=(env -i ...); "${cmd[@]}"`). `${=B}` works too, but
  only in zsh.

- **A glob that matches nothing is an error.** zsh aborts the whole command
  with `no matches found: dir/*.x` where bash would pass the pattern through.
  For probe paths that may be empty, use the `(N)` qualifier
  (`ls -d dir/*.x(N)`), test with `[ -e ]` first, or use `find`.

These rules don't apply to a script with a `#!/bin/sh` or `#!/usr/bin/env
bash` shebang, or to one piped into `sh -s`. It runs in the interpreter it
names.
