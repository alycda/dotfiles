# clock-rs ships everywhere via lib/core-packages.nix
[group('personal')]
clock:
    clock-rs --fmt="%A, %Y-%m-%d" -t

# render markdown from cwd or a given file (glow ships via core-packages)
[group('personal')]
md *args:
    glow {{args}}

# encrypt to Alyssa's age public key (stdin->stdout, or pass rage args)
[group('personal')]
encrypt *args:
    rage -e -r age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09 {{args}}
