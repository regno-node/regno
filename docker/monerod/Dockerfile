# monerod docker image
# original credit to https://github.com/leonardochaia/docker-monerod

ARG REGNO_MONEROD_VERSION
ARG REGNO_UBUNTU_VERSION

# Use Ubuntu for the build image base
FROM ubuntu:${REGNO_UBUNTU_VERSION} as build

# Dependency list from https://github.com/monero-project/monero#compiling-monero-from-source
# Added DEBIAN_FRONTEND=noninteractive to workaround tzdata prompt on installation
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends build-essential cmake \
    pkg-config libboost-all-dev libssl-dev libzmq3-dev libunbound-dev ca-certificates \
    libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev \
    libexpat1-dev doxygen graphviz libpgm-dev qttools5-dev-tools libhidapi-dev \
    libusb-dev libprotobuf-dev protobuf-compiler libgtest-dev git \
    libnorm-dev libpgm-dev libusb-1.0-0-dev libudev-dev libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch to directory for gtest and make/install libs
WORKDIR /usr/src/gtest
RUN cmake . && make && cp ./lib/libgtest*.a /usr/lib

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch
ARG REGNO_MONEROD_VERSION
RUN git config --global https.postBuffer 2147483648 \
    && git clone --recursive --depth 1 --branch ${REGNO_MONEROD_VERSION} \
    https://github.com/monero-project/monero . \
    && git submodule init && git submodule update

# Make static Monero binaries
RUN make -j$(nproc) release-static

# Clean Ubuntu layer for the runtime image
FROM ubuntu:${REGNO_UBUNTU_VERSION}

# Install remaining dependencies
RUN apt-get update && apt-get install --no-install-recommends -y libnorm-dev libpgm-dev libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add user and setup directories for monerod
RUN useradd -ms /bin/bash monero && mkdir -p /home/monero/.bitmonero \
    && chown -R monero:monero /home/monero/.bitmonero
USER monero

# Switch to home directory and install newly built monerod binary
WORKDIR /home/monero
COPY --chown=monero:monero --from=build /monero/build/Linux/*/release/bin/monerod /usr/local/bin/monerod

# Expose p2p, RPC, and ZMQ ports
EXPOSE 18080, 18081, 18083

# Start monerod with required --non-interactive flag and sane defaults that are overridden by user input (if applicable)
ENTRYPOINT ["monerod"]
CMD ["--p2p-bind-ip=0.0.0.0", "--p2p-bind-port=18080", "--rpc-bind-ip=0.0.0.0", --rpc-bind-port=18081", "--non-interactive", "--confirm-external-bind", "--zmq-pub tcp://0.0.0.0:18083", "--enable-dns-blocklist"]