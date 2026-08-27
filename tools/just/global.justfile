# Invocable cheatsheets, promoted to just's GLOBAL justfile: `just -g <recipe>`
# from anywhere (recipes run with the invocation directory as cwd). Each
# converted sheet under tools/cheat/cheatsheets keeps a pointer line to its
# recipe here; sheets that are genuinely reference material stay sheets.
# Successor to the community/nix/sh trick (`cheat <name> | sh`).

[group('gh')]
my-prs:
    gh pr list -a @me

# name + email of the logged-in gh user
[group('gh')]
gh-whoami:
    @gh api user | jq -r '.name, .email'

# delete local branches already merged into origin/main
[group('git')]
del-merged:
    git branch --merged origin/main | grep -v "^\*" | grep -v "main" | xargs git branch -d

[group('jj')]
jj-heads:
    jj log -r 'heads(all())'

[group('jj')]
jj-log-all:
    jj log -r '::'

[group('nix')]
gc:
    nix-collect-garbage

[group('nix')]
nix-info:
    nix-shell -p nix-info --run "nix-info -m"

# find which Claude Code session transcripts mention a ticket
[group('claude')]
find-session ticket:
    grep -rl "{{ticket}}" ~/.claude/projects/

# clock-rs is installed system-level on the ditto machine (darwin/profiles/ditto.nix)
[group('personal')]
clock:
    clock-rs --fmt="%A, %Y-%m-%d" -t

[group('personal')]
home-vpn:
    sudo /opt/homebrew/opt/openvpn/sbin/openvpn --config ~/Downloads/Firewalla.ovpn

# render markdown (defaults to cwd; pass a file to render one). glow is
# always installed (lib/core-packages.nix) since main's glow promotion.
[group('personal')]
md *args:
    glow {{args}}

# encrypt to Alyssa's age public key (stdin->stdout, or pass rage args)
[group('personal')]
encrypt *args:
    rage -e -r age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09 {{args}}

# cargo with dirty-tracking made visible: `just -g cargo-dirty build -p foo`
[group('rust')]
cargo-dirty *args:
    #!/usr/bin/env bash
    cargo {{args}} -vvv --color=always |& grep -v Running | grep -e '' -e Dirty
