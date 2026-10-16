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

# Convex on venari (tools/venari/README.md, "Convex"): backend, HTTP actions and
# dashboard listen on the box's loopback. The forwards are inline rather than an
# ssh alias like venari-ghost, so nothing outside this repo has to exist first;
# laptop ports are the box's plus 10000 (13210 -> 3210, like Ghost's 15432 -> 5432),
# because 3210/3211 are where a local `npx convex dev` deployment starts, and they
# must match CONVEX_CLOUD_ORIGIN / CONVEX_SITE_ORIGIN in convex/docker-compose.yml.
# The tunnel is an ssh control master on a socket, so `ssh -O check` / `-O exit`
# find and close it on macOS and Linux alike - no pgrep/pkill, whose flags differ
# (procps pgrep has no -q) and whose -f pattern also matches the calling shell.

# open the Convex tunnel: 13210 -> API, 13211 -> HTTP actions, 16791 -> dashboard
[group('personal')]
convex-tunnel:
    #!/usr/bin/env bash
    set -euo pipefail
    sock="$HOME/.ssh/venari-convex.sock"
    if ssh -o ControlPath="$sock" -O check venari 2>/dev/null; then
        echo "convex tunnel already open"
        exit 0
    fi
    rm -f "$sock"   # a master that died uncleanly leaves its socket behind
    ssh -fN -o ControlMaster=yes -o ControlPath="$sock" -o ExitOnForwardFailure=yes \
        -L 13210:127.0.0.1:3210 -L 13211:127.0.0.1:3211 -L 16791:127.0.0.1:6791 venari
    echo "convex tunnel open: API 13210, HTTP actions 13211, dashboard 16791"

# close the Convex tunnel
[group('personal')]
convex-tunnel-close:
    #!/usr/bin/env bash
    set -euo pipefail
    sock="$HOME/.ssh/venari-convex.sock"
    if ssh -o ControlPath="$sock" -O exit venari 2>/dev/null; then
        echo "convex tunnel closed"
    else
        rm -f "$sock"
        echo "no convex tunnel open"
    fi

# print a new Convex admin key (each call differs; all stay valid until data/ is lost)
[group('personal')]
convex-admin-key:
    @ssh venari-root 'cd /srv/convex && docker compose exec -T backend ./generate_admin_key.sh' | tail -1

# The box has two vCPUs and no Go, so the server binary is cross-compiled here
# and only the static binary travels; the image on the box is Alpine plus that
# file (tools/venari/ghost/server/Dockerfile).

# ship a new ghost-server to venari from the fork checkout, rebuild its image, restart it
[group('personal')]
ghost-deploy src='~/Projects/ghost':
    cd {{src}} && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 nix shell nixpkgs#go -c go build -trimpath -ldflags='-s -w' -o "${TMPDIR:-/tmp}/ghost-server" ./cmd/ghost-server
    scp "${TMPDIR:-/tmp}/ghost-server" venari-root:/srv/ghost/server/ghost-server
    ssh venari-root 'cd /srv/ghost && docker compose build -q server && docker compose up -d server && docker compose ps --format "table {{{{.Name}}}}\t{{{{.Status}}}}"'
