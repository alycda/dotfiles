# The box's only network plumbing: one image, two roles.
#
#   socat     - fixed-destination TCP shim (the model port, and nothing else)
#   tinyproxy - CONNECT proxy with a deny-by-default hostname allowlist
#   curl      - what `hermes-box.sh verify` probes the boundary with
#
# Built locally rather than pulled from a third party on purpose: this image is
# the thing that holds the two doors, so it should be four lines you can read.
# Alpine is pinned to a minor; the apk versions inside it are not (apk has no
# lockfile), so a rebuild can move socat/tinyproxy. That is the trade for not
# running someone else's proxy image - if it matters, pin with `=version`.
FROM alpine:3.22

RUN apk add --no-cache socat tinyproxy curl

# tinyproxy's alpine package creates the `tinyproxy` user; the config below
# drops to it. socat and curl run as root in a container with no capabilities
# it needs - see compose.yaml's cap_drop.
