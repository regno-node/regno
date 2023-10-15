# p2pool docker image
# original credit to https://github.com/SChernykh/p2pool

ARG REGNO_UBUNTU_VERSION
FROM regno-ubuntu:${REGNO_UBUNTU_VERSION}
RUN set -e && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -q -y --no-install-recommends \
    git \
    build-essential \
    ca-certificates \
    cmake \
    libuv1-dev \
    libzmq3-dev \
    libsodium-dev \
    libpgm-dev \
    libnorm-dev \
    libgss-dev \
    libcurl4-openssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/p2pool
ARG REGNO_P2POOL_VERSION
ARG REGNO_P2POOL_COMMIT
RUN git clone --recursive --depth 1 --branch ${REGNO_P2POOL_VERSION} --shallow-submodules https://github.com/SChernykh/p2pool.git .
RUN test `git rev-parse HEAD` = ${REGNO_P2POOL_COMMIT} || exit 1 && \
    mkdir build && \
    cd build && \
    cmake .. && \
    NJOBS=$( [ "$(nproc)" -gt 1 ] && echo "$(expr $(nproc) - 1)" || echo 1 ) && \
    make -j$NJOBS

FROM regno-ubuntu:${REGNO_UBUNTU_VERSION}
COPY --from=0 /usr/src/p2pool/build/p2pool /

RUN set -e && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -q -y --no-install-recommends \
    libzmq5 \
    libuv1 \
    libcurl4 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r p2pool -g 1000 && \
    useradd -u 1000 -r -g p2pool -s /sbin/nologin -c "p2pool user" p2pool

RUN mkdir -p /home/p2pool/.p2pool && \
    chown p2pool.p2pool /home/p2pool /home/p2pool/.p2pool

USER p2pool

EXPOSE 3333
EXPOSE 37889

VOLUME /home/p2pool/.p2pool

WORKDIR /home/p2pool/.p2pool
ENTRYPOINT ["/p2pool"]
