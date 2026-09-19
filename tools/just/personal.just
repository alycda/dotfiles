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

# push every Moment document to Soft Serve as a private repo moment/<id>
[group('personal')]
moment-backup remote='hermes-git':
    #!/usr/bin/env bash
    # Needs the `hermes-git` ssh alias (Soft Serve on hermes-1, reached via
    # ProxyJump; kept in ~/.ssh/config, not in this repo).
    #
    # Pushes HEAD, not `main`: in a colocated jj repo git's HEAD is the last
    # committed change (@-), while Moment stops advancing `main` once anything
    # outside the app has touched the repo. Uncommitted draft edits are not
    # pushed - commit in Moment first. Never forces: a rejected push (history
    # rewritten locally) is reported and left for a human to decide.
    set -uo pipefail
    remote={{quote(remote)}}
    root="$HOME/.moment/documents"
    existing=$(ssh "$remote" repo list) || { echo "cannot reach $remote" >&2; exit 1; }
    failed=0
    for dir in "$root"/*/; do
        dir=${dir%/}; id=${dir##*/}; repo="moment/$id"
        # Moment leaves bare .moment/ dirs for documents it never finished creating.
        [ -f "$dir/moment.yml" ] || continue
        git -C "$dir" rev-parse -q --verify HEAD >/dev/null || { echo "skip $id: no commits"; continue; }
        title=$(sed -n 's/^title: //p' "$dir/moment.yml" | head -n1)
        if ! grep -qxF "$repo" <<<"$existing"; then
            ssh "$remote" repo create -p "$repo" >/dev/null || { echo "FAIL $id: create"; failed=1; continue; }
        fi
        # ssh joins its arguments into one string that Soft Serve re-splits, so
        # the title travels single-quoted with embedded quotes escaped. The
        # client-side expansion is the point, hence the SC2029 opt-out.
        # shellcheck disable=SC2029
        ssh "$remote" repo description "$repo" "'${title//\'/\'\\\'\'}'" >/dev/null
        if git -C "$dir" push -q "$remote:$repo" HEAD:refs/heads/main 2>/dev/null; then
            echo "ok   $repo  $(git -C "$dir" log -1 --format='%h %an: %s')  ($title)"
        else
            echo "FAIL $repo: push rejected ($title)"; failed=1
        fi
    done
    exit "$failed"
