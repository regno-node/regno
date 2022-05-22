ARG REGNO_MONEROD_VERSION
ARG REGNO_UBUNTU_VERSION
FROM regno/monerod-build:${REGNO_MONEROD_VERSION} as builder

ARG REGNO_UBUNTU_VERSION
FROM regno-ubuntu:${REGNO_UBUNTU_VERSION}

# Install remaining dependencies
RUN apt-get install --no-install-recommends -y libnorm-dev libpgm-dev libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add user and setup directories for monerod
RUN useradd -ms /bin/bash monero && mkdir -p /home/monero/.bitmonero \
    && chown -R monero:monero /home/monero/.bitmonero
USER monero

# Switch to home directory and install newly built monerod binary
WORKDIR /home/monero
ARG REGNO_MONEROD_VERSION
COPY --chown=monero:monero --from=builder /root/monero/build/release/bin/monerod /usr/local/bin/monerod

# Expose p2p, RPC, and ZMQ ports
EXPOSE 18080
EXPOSE 18081
EXPOSE 18083

# Start monerod with required --non-interactive flag and sane defaults that are overridden by user input (if applicable)
ENTRYPOINT ["monerod", "--non-interactive"]
CMD ["--p2p-bind-ip=0.0.0.0", "--p2p-bind-port=18080", "--rpc-bind-ip=0.0.0.0", "--rpc-bind-port=18081", "--non-interactive", "--confirm-external-bind", "--zmq-pub tcp://0.0.0.0:18083", "--enable-dns-blocklist"]
