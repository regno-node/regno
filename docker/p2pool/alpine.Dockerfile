ARG REGNO_ALPINE_VERSION

FROM alpine:${REGNO_ALPINE_VERSION} as updated_alpine
RUN set -ex && apk --update --no-cache upgrade

FROM updated_alpine as build
RUN set -ex && apk add --update --no-cache ca-certificates git libsodium-dev zeromq-dev cmake \
    build-base libuv openpgm-dev libgss-dev
RUN set -ex && apk add --update --no-cache python3 linux-headers
RUN ln -s /usr/bin/python3 /usr/bin/python

# build norm - no alpine package for it
WORKDIR /tmp
RUN git clone --depth 1 --shallow-submodules --recurse-submodules \
    https://github.com/USNavalResearchLaboratory/norm.git

RUN cd norm && ./waf configure && ./waf install

RUN set -ex && apk add --update --no-cache libuv-dev
# build p2pool
WORKDIR /usr/src/p2pool
ARG REGNO_P2POOL_VERSION
RUN git clone --recursive --depth 1 --branch ${REGNO_P2POOL_VERSION} --shallow-submodules https://github.com/SChernykh/p2pool.git . && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc)

FROM updated_alpine
COPY --from=build /usr/src/p2pool/build/p2pool /

RUN set -ex && apk add --update --no-cache zeromq libuv
RUN addgroup -S p2pool -g 1000 && \
    adduser -S -u 1000 -g p2pool -s /sbin/nologin p2pool

RUN mkdir -p /home/p2pool/.p2pool && \
    chown p2pool:p2pool /home/p2pool /home/p2pool/.p2pool

USER p2pool

EXPOSE 3333
EXPOSE 37889

VOLUME /home/p2pool/.p2pool

WORKDIR /home/p2pool/.p2pool
ENTRYPOINT ["/p2pool"]
