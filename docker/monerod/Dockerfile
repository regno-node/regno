ARG REGNO_ALPINE_VERSION
ARG REGNO_MONEROD_VERSION
FROM regno/monerod-build:${REGNO_MONEROD_VERSION} as build

FROM alpine:${REGNO_ALPINE_VERSION}
RUN set -ex && apk --update --no-cache upgrade
RUN set -ex && apk add --update --no-cache curl ca-certificates libexecinfo \
    libsodium ncurses-libs pcsc-lite-libs readline zeromq

# Add user and setup directories for monerod
RUN set -ex && adduser -Ds /bin/bash monero \
    && mkdir -p /home/monero/.bitmonero \
    && chown -R monero:monero /home/monero/.bitmonero
USER monero

# Switch to home directory and install newly built monerod binary
WORKDIR /home/monero
COPY --chown=monero:monero --from=build /monero/build/release/bin/monerod /usr/local/bin/monerod

# p2p port
EXPOSE 18080
# regular RPC port
EXPOSE 18081
# ZMQ port
EXPOSE 18083
# restricted RPC port
EXPOSE 18089

# Add HEALTHCHECK against get_info endpoint
HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://localhost:18089/get_info || exit 1

VOLUME /home/monero/.bitmonero

# Start monerod with required --non-interactive flag and sane defaults that are overridden by user input (if applicable)
ENTRYPOINT ["monerod", "--non-interactive"]
CMD ["--rpc-restricted-bind-ip=0.0.0.0", "--rpc-restricted-bind-port=18089", "--enable-dns-blocklist", "--p2p-bind-ip=0.0.0.0", "--p2p-bind-port=18080",  "--confirm-external-bind"]
