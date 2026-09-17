# Hermes in a box

Hermes Agent, running against a local model, in a container that **has no route
to the internet**. The default mode is no egress at all; the opt-in mode is a
deny-by-default hostname allowlist through one auditable door.

The claim is deliberately narrow, structural, and testable in one command:

```console
$ ./hermes-box.sh verify
topology
  ok    hermes-box is internal (docker installs no gateway and no NAT for it)
  ok    a container on hermes-box has no default route at all
```

Not "we set `HTTP_PROXY`". Not "we disabled the web tools". No default route —
so a socket has nowhere to go regardless of what the agent, a skill, an MCP
server, or a shell command the agent writes for itself decides to try.

## Topology

```
  ┌─ hermes-box (internal: true — docker adds no gateway, installs no NAT) ──┐
  │                                                                         │
  │   hermes ─────────► ollama          (alias: the shim, or the contained   │
  │      │                               ollama service — same URL either    │
  │      │                               way: http://ollama:11434/v1)        │
  │      └────────────► egress-proxy:8888     [only with --allowlist]        │
  └──────────────┬──────────────────────────────┬───────────────────────────┘
                 │                              │
        ollama-shim (socat,              egress-proxy (tinyproxy,
        one fixed destination)           FilterDefaultDeny)
                 │                              │
  ┌─ hermes-box-egress (ordinary bridge) ───────────────────────────────────┐
  │        host's ollama :11434                      the internet           │
  └─────────────────────────────────────────────────────────────────────────┘
```

Only the two door containers have a foot on both networks. The agent has one
interface, on a network that cannot reach anything the doors do not hand it.

- **`ollama-shim`** is `socat` with a single hard-coded destination. It cannot
  be talked into a second one — there is no protocol for that.
- **`egress-proxy`** is `tinyproxy` with `FilterDefaultDeny Yes`, so
  `net/allowlist` is an *allow* list and an empty file blocks everything. That
  is the shipped state.

## Quickstart

```sh
cd docker/hermes-box

./hermes-box.sh init          # ~/.hermes-box + a seeded config.yaml
# edit ~/.hermes-box/config.yaml: model.default must be a model you have
./hermes-box.sh up
./hermes-box.sh verify        # before trusting any of the above
./hermes-box.sh chat
```

Two modes, picked with `HERMES_BOX_MODE`:

| mode | model runs | why |
|---|---|---|
| `host-model` (default) | host's ollama, reached through the shim | keeps Metal/GPU acceleration; the agent still cannot address the host |
| `contained-model` | an `ollama` container on the internal network | nothing outside the box at all; **CPU-only**, because Docker on macOS has no GPU passthrough |

In `contained-model`, models arrive through an explicit, separate step:

```sh
HERMES_BOX_MODE=contained-model ./hermes-box.sh pull qwen2.5-coder:14b
```

That briefly runs the *same* ollama image on the egress network only, pulls into
the shared volume, and removes it. Fetching weights is an auditable act you
perform — not something the agent can decide to do.

To open the filtered door later: add an anchored pattern to `net/allowlist`
(`^docs\.ditto\.live$`), then `./hermes-box.sh up --allowlist`. Every allow and
deny lands in `./hermes-box.sh proxy-log`.

## Verify, and why it has a control

A box that cannot reach the internet proves nothing if the *host* cannot reach
it either. So every egress probe runs twice — once inside the box, once on an
ordinary bridge network — and the run is only a pass when the control succeeds
and the box fails. Otherwise it reports `????` and exits 2, rather than letting
you screenshot a green wall that a flaky wifi connection produced.

The probes hit `1.1.1.1:443` by raw IP before hitting a hostname, so a pass
cannot be explained away as "DNS was broken". Note what `verify` prints when it
sees resolution working: **names still resolve inside the box** (docker proxies
DNS through the daemon). `connect()` is what fails. Resolution is not the
boundary, and anyone evaluating this should be told that up front.

When the agent container is running, `verify` also checks the agent's *own*
container — no default route, and a Python socket to `1.1.1.1:443` that does not
open — rather than a probe that merely looks like it.

## What this does NOT do

Being straight about the edges is the point; a control you have oversold is
worse than none.

- **It is not filesystem isolation.** `/workspace` is a read-write bind mount of
  whatever directory you started it from. Set `HERMES_BOX_WORKSPACE_MODE=ro` if
  you want the agent to read your code and not rewrite it.
- **An allowlisted host is a full bidirectional channel.** `docs.ditto.live` on
  the list means an agent that wanted to exfiltrate could POST to
  `docs.ditto.live`. The allowlist shrinks the door; it does not make it
  one-way.
- **The proxy does not inspect TLS.** CONNECT is tunnelled, hostname-matched,
  end-to-end. That is a feature (no MITM, no corporate CA in the box) and a
  limit (no content inspection).
- **It does not stop prompt injection, bad patches, or a deleted working tree.**
  Everything an agent can do to files it can reach, it can still do. The claim
  is about the network.
- **It is not a container escape boundary.** Standard docker isolation, plus
  `no-new-privileges` and a pids/memory cap. The docker socket is never mounted
  — which is also why `terminal.backend` stays `local` in the seeded config:
  switching it to `docker` would need that socket, and handing the agent the
  socket hands it the daemon.
- **Image supply chain is unchanged.** `nousresearch/hermes-agent` and
  `ollama/ollama` are pulled from Docker Hub. Pin tags via `HERMES_BOX_TAG` /
  `HERMES_BOX_OLLAMA_TAG` if that matters to you. The one image this repo
  builds — `net/Dockerfile` — is four lines on purpose, since it holds both
  doors.

## Two corrections to how this repo already talks about sandboxing

1. **`just -g docker-net` is not a lockdown.** A user-defined bridge network
   segments containers from *each other*; it has a gateway and NAT like any
   bridge, so anything on it still reaches the internet. Its cheatsheet says so;
   worth repeating, because "I put it on its own network" is exactly the sentence
   people mistake for this file's `internal: true`.
2. **The dev container is a toolchain box, not a network sandbox.**
   `docker/dev.sh run` uses `--network host` — Claude in that container has the
   host's network stack, unfiltered. That is the right trade for a dev image on
   the 2012 MBP. It just isn't the thing this directory does.

## If this is for a conversation at work

What is demonstrable here: an agent harness can be run with a verifiable
no-egress network boundary and a local model, with a one-command transcript
anyone can reproduce and an audit log for any exception.

What is not demonstrable by any amount of compose YAML: that a policy should
change. A ban that names a product is a decision about a product. The useful
move is to ask whoever owns it which *control* they are actually buying — if it
is "no agent may send our source to a third party", this addresses that class
directly and does so for every harness, including the ones already permitted.
If it is "no unapproved software on managed hardware", then a sandbox is not
responsive to it and nothing here changes that.

Two things worth keeping honest in that conversation:

- "Any harness can nuke your machine" is true, and it argues for sandboxing
  *all* of them — not for exempting one. The version of the argument that holds
  is: state the requirement as a control (no egress, local inference, auditable
  exceptions), and let any harness that meets it in.
- A local-only box removes the vendor-egress hazard. It does not remove the
  hazards your employer may care about just as much — what the agent does to
  the code it can reach, and what a permitted exception carries.
