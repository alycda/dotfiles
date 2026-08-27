# cargo with dirty-tracking made visible: `just -g cargo-dirty build -p foo`
[group('rust')]
cargo-dirty *args:
    #!/usr/bin/env bash
    cargo {{args}} -vvv --color=always |& grep -v Running | grep -e '' -e Dirty
