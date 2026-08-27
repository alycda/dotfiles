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
