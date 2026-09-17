# hermes-boxed — what to restore after a rebuild

Companion to `docker-compose.yml`. Things the agent installed *inside* the
container that a `docker compose pull && up -d --force-recreate` would lose.

## What persists, and what doesn't

`./state:/opt/data` is a host bind mount (grpcfuse), so **everything under
`/opt/data` survives image rebuilds** — it is host storage, not a layer.
Everything else in the container lives on the overlay filesystem and is
destroyed by any recreate, not just a rebuild:

```
overlay      59G  53G  3.2G  95% /        <- ephemeral, and nearly full
grpcfuse    1.7T 440G  1.2T  27% /opt/data <- persistent (= ./state on the host)
```

The rule for anything installed by hand: **put it under `/opt/data`, or it is
gone on the next recreate.**

## PATH — the part that bites

The supervised hermes process runs with:

```
PATH=/command:/opt/hermes/bin:/opt/hermes/.venv/bin:/opt/data/.local/bin:...
```

`/opt/data/.local/bin` is on PATH. `/opt/data/home/.local/bin` is **not**.

The agent's tool sandbox runs with `HOME=/opt/data/home`, so `~/.local/bin`
expands to a directory that is persistent but **not on the runtime PATH**.
`docker exec -u 501` shows `HOME=/opt/data`, a third value again. Do not trust
`~` here — always install to the absolute path `/opt/data/.local/bin`.

---

## 1. Typst 0.15.1 — persists, but installed to the wrong directory

Current location: `/opt/data/home/.local/bin/typst`
(host: `state/home/.local/bin/typst`, 55 MB)

Verified working: `typst 0.15.1 (9dfd3a08)`, and `readelf -l` reports
**statically linked** — no interpreter, so the musl build runs fine on this
Debian 13 (trixie) glibc image. It will keep working across image rebuilds.

It is on the bind mount, so it needs no reinstall. It only needs relocating
onto the PATH the agent actually runs with:

```bash
# host — no container restart required
mkdir -p ~/hermes-boxed/state/.local/bin
mv ~/hermes-boxed/state/home/.local/bin/typst ~/hermes-boxed/state/.local/bin/typst
```

If it ever does need a fresh fetch:

```bash
curl -sL https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz \
  | tar -xJ -C /tmp
install -m755 /tmp/typst-x86_64-unknown-linux-musl/typst /opt/data/.local/bin/typst
```

## 2. pymupdf venv — does NOT persist, `/tmp` is on the overlay

Current location: `/tmp/pdfenv` — **destroyed by any container recreate.**
PEP 668 blocks a system-wide pip install, so a venv is the right shape; it is
just in the wrong place. Move it under `/opt/data`:

```bash
docker exec hermes-boxed sh -c '
  uv venv /opt/data/.local/venvs/pdfenv &&
  VIRTUAL_ENV=/opt/data/.local/venvs/pdfenv uv pip install pymupdf pymupdf4llm'
```

Then invoke it as `/opt/data/.local/venvs/pdfenv/bin/python3`.

The uv cache is already persistent (`/opt/data/.cache/uv`, 14 MB), so a
recreate is fast and does not need the network.

**Caveat:** a venv hardcodes the base interpreter path and symlinks it. The
image ships **Python 3.13.5**; if a future image bumps the minor version, the
persisted venv breaks with a confusing import error rather than a clean
failure. Re-run the command above after any image bump — it is idempotent.

## 3. Disk — check before rebuilding

The container's overlay root is at **95% (3.2 GB free)**. A `docker compose
pull` of a new hermes-agent image may not fit. Run `docker system prune -f`
before pulling.

---

## 4. Resume source — markdown, no longer Upstash

The resume graph was exported from the `resume-graph` MCP (Upstash Redis) to
markdown at `Career/Resume/` in the Obsidian vault — visible to the agent as
`/artifacts/Career/Resume`. 28 files: one per experience/project/recognition/
extracurricular, plus `contact.md` and `technologies.md`. Frontmatter holds the
structured fields, the body holds prose, and each file keeps its Upstash `id`
for traceability. Audit notes are in that directory's `README.md`.

This lives on the host bind mount, so it survives rebuilds. Nothing to restore
— but the regeneration path is kept here:

```bash
python3 ~/hermes-boxed/tools/gen_resume_md.py <outdir> ~/hermes-boxed/tools/resume-graph.json
```

`resume-graph.json` is the snapshot taken at export time (2026-07-30). Upstash
still holds the original and was not modified; it is no longer the working
surface.

**Optional mount change to consider at the next rebuild.** `/artifacts` is
mounted read-write, so the agent can rewrite the resume source, not just read
it. If it should compose resumes *from* this data without editing it, add a
read-only mount of just that subtree to the gateway service:

```yaml
      - /Users/alyssa/Library/Mobile Documents/iCloud~md~obsidian/Documents/Hermes/Career:/career:ro
```

and have the agent read `/career` rather than `/artifacts/Career`. Deliberately
not applied yet — it needs a container recreate.

## 5. Local Postgres — PLANNED, not applied

Design decision recorded for the next rebuild. Nothing below is running.

### Named volume, NOT a bind mount

Do not put the data directory on `/Users/alyssa/...`. Every host path in this
compose crosses grpcfuse (osxfs), which does not provide the POSIX semantics a
Postgres cluster requires — fsync ordering, file locking, and ownership/chmod
during `initdb`. The documented failure modes are `initdb` refusing to set
permissions, and cluster corruption after an unclean stop.

That last one is not hypothetical here: this VM has died twice with no clean
shutdown. Postgres recovers from that correctly via WAL replay **on a real
filesystem**. On grpcfuse, an unclean stop is precisely where the corruption
happens. A named volume lives on the VM's own ext4 and behaves correctly.

The host-visible part should be backups, not the live cluster — `pg_dump`
output is ordinary sequential file writes, safe on grpcfuse, and gives you
plaintext you can diff and version.

```yaml
  postgres:
    image: postgres:17          # pin the major; a major upgrade = dump + restore
    container_name: pg-local
    environment:
      - POSTGRES_USER=alyssa
      - POSTGRES_DB=notes
      - POSTGRES_PASSWORD_FILE=/run/secrets/pg_password
    volumes:
      - pgdata:/var/lib/postgresql/data          # named volume — VM ext4
      - ./pg-backups:/backups                    # bind mount — dumps only
    shm_size: 256mb             # default 64m is too small for real queries
    networks: [pgnet]           # NOT on the gateway's default network
    restart: unless-stopped

volumes:
  pgdata: {}
networks:
  pgnet: {}
```

### Prune first — the VM disk is the blocker

The VM disk is 59 GB with 3.2 GB free. `docker system df` reports **18.87 GB
reclaimable in images (64% of 29.41 GB)**. Run `docker image prune -a` before
adding anything; that alone clears the constraint.

Memory is not a concern: 16 GB host, 8 GB allocated to the VM, ~2.5 GB in use
across 13 containers. `immich_postgres` runs in 80 MB.

### Agent access — reuse the broker pattern

Do not hand the gateway a Postgres connection string. You already solved this
shape once: the ledger goes through a host MCP broker on `127.0.0.1:8643` with
a bearer token, and the container has no direct access. Same reasoning applies
harder to SQL, because the gateway ingests untrusted statement text through
`ledger_read_import` — raw SQL plus an injection source on one agent is the
combination to avoid.

If the agent does eventually get direct access, give it a role with explicit
grants on one schema, never the `POSTGRES_USER` superuser.

## 6. Pending config change — takes effect at the next restart

`state/config.yaml` line 402, `memory.write_approval`, was flipped
`false` → `true` on 2026-07-31 (backup alongside it as `config.yaml.bak-*`).
The gateway reads this file only at start, so it is inert until the next
restart — confirmed by mtime: the file had not been rewritten since
2026-07-28 while the gateway had been up since 2026-07-31.

**Why.** The agent was writing its own persistent memory unattended while also
ingesting untrusted statement text through `ledger_read_import`. Every other
injection path in this stack is scoped to a single session; memory is not —
text planted in `MEMORY.md` applies to every future session, before Alyssa
sees it. Approval makes that structurally impossible rather than something to
re-audit.

**Verify after the restart** that memory writes now prompt:

```bash
grep -n -A6 '^memory:' ~/hermes-boxed/state/config.yaml
```

### Two related settings deliberately NOT changed

- `skills.write_approval: false` (line 431) with `skills.guard_agent_created:
  false` — the agent can author its own skills unattended. Same persistence
  class as memory: a skill is durable instructions loaded on later turns.
  Left alone because it was not asked for; worth a separate decision.
- `curator.enabled: true`, `interval_hours: 168` — a curator pass runs weekly
  and may rewrite memory on its own. Check whether it honours
  `write_approval`; if it does not, approval covers agent writes but not the
  curator's.

## Preferred long-term fix

Both items are workarounds for the image lacking typst and pymupdf. The
durable version is a small `Dockerfile` in this directory that does
`FROM nousresearch/hermes-agent:latest` and installs both, with the compose
service switched from `image:` to `build:`. That survives rebuilds by
construction and drops the `/opt/data` PATH problem entirely. Cost: an
image build on a 2012 MBP on every upstream bump. Until then, this file is
the recovery procedure.
