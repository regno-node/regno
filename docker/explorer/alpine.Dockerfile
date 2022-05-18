ARG REGNO_MONEROD_VERSION
ARG REGNO_ALPINE_VERSION

FROM regno/monerod-build:${REGNO_MONEROD_VERSION} as build
RUN set -ex && apk add --update --no-cache curl-dev patch zip
RUN git clone --depth 1 --branch master \
    https://github.com/moneroexamples/onion-monero-blockchain-explorer.git \
    /monero/onion-monero-blockchain-explorer

RUN ln -s /monero ~/monero

# Get rid of backtrace calls - doesn't work with musl / alpine
# building monerod with -DELPP_FEATURE_CRASH_LOG doesn't fix this
# for some reason, hence the patch.
WORKDIR /monero
COPY ./remove_backtrace.patch .
RUN patch -p1 < remove_backtrace.patch
RUN cd build/release/external/easylogging++ && make clean && make

WORKDIR /monero/onion-monero-blockchain-explorer/build

ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1

RUN cmake .. && make -j$(nproc)

# Use ldd and awk to bundle up dynamic libraries for the final image
RUN zip /lib.zip $(ldd xmrblocks | grep -E '/[^\ ]*' -o)

# Build final image
ARG REGNO_ALPINE_VERSION
FROM alpine:${REGNO_ALPINE_VERSION}
RUN set -ex && apk --update --no-cache upgrade
RUN set -ex && apk add --update --no-cache unzip

COPY --from=build /lib.zip .
RUN unzip -o lib.zip && rm -rf lib.zip

ARG REGNO_MONERO_UID
RUN adduser -Ds /bin/bash --uid ${REGNO_MONERO_UID} monero && \
    mkdir -p /home/monero/.bitmonero && \
    chown -R monero:monero /home/monero/.bitmonero
USER monero

WORKDIR /home/monero
COPY --chown=monero:monero --from=build /monero/onion-monero-blockchain-explorer/build/xmrblocks .
COPY --chown=monero:monero --from=build /monero/onion-monero-blockchain-explorer/build/templates ./templates/

# Expose volume for lmdb access by xmrblocks
VOLUME /home/monero/.bitmonero
EXPOSE 8081 
ENTRYPOINT ["/bin/sh", "-c"]

# Set sane defaults that are overridden if the user passes any commands
CMD ["./xmrblocks --enable-json-api --enable-autorefresh-option --enable-pusher"]
