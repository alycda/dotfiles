# CI

`lint.yml` runs on every push and pull request, and needs neither Nix nor
mise. Actions are pinned to commit SHAs, with the tag in a comment.

## editorconfig

`editorconfig-checker` checks every file against `.editorconfig`: charset,
line endings, final newline, trailing whitespace and indentation.

`.editorconfig-checker.json` excludes files that aren't ours to reformat:

- `LICENSE`: the license text, as published.

Run it locally with `editorconfig-checker`.
