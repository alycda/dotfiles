[group('nix')]
gc:
    nix-collect-garbage

[group('nix')]
nix-info:
    nix-shell -p nix-info --run "nix-info -m"
