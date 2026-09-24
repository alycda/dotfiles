# ghost-server from a binary built elsewhere: `GOOS=linux GOARCH=amd64
# CGO_ENABLED=0 go build ./cmd/ghost-server` on the laptop, copied next to this
# file. The box has two vCPUs and no Go; the fork's own Dockerfile.server is the
# from-source build for a machine that has both.
FROM alpine:3.23
RUN addgroup -g 1000 ghost && adduser -u 1000 -G ghost -D ghost
USER ghost
COPY ghost-server /usr/local/bin/ghost-server
ENTRYPOINT ["ghost-server"]
