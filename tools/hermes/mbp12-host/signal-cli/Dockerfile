FROM eclipse-temurin:25-jre
ARG SIGNAL_CLI_VERSION=0.14.6
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/signal-cli.tar.gz \
      "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz" \
 && tar -xzf /tmp/signal-cli.tar.gz -C /opt \
 && ln -s "/opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli" /usr/local/bin/signal-cli \
 && rm /tmp/signal-cli.tar.gz
# State (accounts, sessions, keys) lives here — bind-mounted from the host so it
# can be backed up / rsynced to another machine. Guard it like a password.
VOLUME /root/.local/share/signal-cli
EXPOSE 8080
ENTRYPOINT ["signal-cli"]
CMD ["daemon", "--http", "0.0.0.0:8080"]
