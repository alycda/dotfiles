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

ip:
    curl -s https://ipinfo.io/json

# create a user-defined docker network if it doesn't exist yet (safe to re-run)
[group('personal')]
docker-net name='claude-net':
    @docker network inspect {{name}} >/dev/null 2>&1 || docker network create {{name}}


# Ghost on venari (tools/venari/README.md, "Ghost"): the API and Postgres listen
# on the box's loopback, so the CLI needs these ssh forwards open. ghost-tunnel is
# safe to re-run: a second tunnel fails to bind and ExitOnForwardFailure kills it.

# open the Ghost tunnel: 8787 -> API, 15432 -> Postgres on venari
[group('personal')]
ghost-tunnel:
    @pgrep -qf 'ssh -fN venari-ghost' && echo "ghost tunnel already open" || ssh -fN venari-ghost

# close the Ghost tunnel
[group('personal')]
ghost-tunnel-close:
    @pkill -f 'ssh -fN venari-ghost' && echo "ghost tunnel closed" || echo "no ghost tunnel open"

# The box has two vCPUs and no Go, so the server binary is cross-compiled here
# and only the static binary travels; the image on the box is Alpine plus that
# file (tools/venari/ghost/server/Dockerfile).

# ship a new ghost-server to venari from the fork checkout, rebuild its image, restart it
[group('personal')]
ghost-deploy src='~/Projects/ghost':
    cd {{src}} && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 nix shell nixpkgs#go -c go build -trimpath -ldflags='-s -w' -o "${TMPDIR:-/tmp}/ghost-server" ./cmd/ghost-server
    scp "${TMPDIR:-/tmp}/ghost-server" venari-root:/srv/ghost/server/ghost-server
    ssh venari-root 'cd /srv/ghost && docker compose build -q server && docker compose up -d server && docker compose ps --format "table {{{{.Name}}}}\t{{{{.Status}}}}"'
