ARG REGNO_ALPINE_VERSION

FROM alpine:${REGNO_ALPINE_VERSION} as build
RUN set -ex && apk --update --no-cache upgrade
RUN set -ex && apk add --update --no-cache  \
    autoconf automake boost boost-atomic boost-build boost-build-doc boost-chrono \
    boost-container boost-context boost-contract boost-coroutine boost-date_time \
    boost-dev boost-doc boost-fiber boost-filesystem boost-graph boost-iostreams \
    boost-libs boost-locale boost-log boost-log_setup boost-math boost-prg_exec_monitor \
    boost-program_options boost-python3 boost-random boost-regex boost-serialization \
    boost-stacktrace_basic boost-stacktrace_noop boost-static boost-system boost-thread \
    boost-timer boost-type_erasure boost-unit_test_framework boost-wave boost-wserialization \
    ca-certificates cmake curl dev86 doxygen eudev-dev file g++ git graphviz \
    libsodium-dev libtool libusb-dev linux-headers make miniupnpc-dev ncurses-dev openssl-dev \
    pcsc-lite-dev pkgconf protobuf-dev rapidjson-dev readline-dev unbound-dev zeromq-dev

RUN set -ex && apk add --update --no-cache libexecinfo-dev
# Set necessary args and environment variables for building Monero
ARG REGNO_MONEROD_VERSION
ARG REGNO_MONEROD_COMMIT

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch
RUN set -ex && git clone --recursive --branch ${REGNO_MONEROD_VERSION} \
    --depth 1 --shallow-submodules \
    https://github.com/monero-project/monero .

# compile statically-linked monerod binary
ARG NPROC
ARG TARGETARCH
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC -DELPP_FEATURE_CRASH_LOG'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1
RUN test `git rev-parse HEAD` = ${REGNO_MONEROD_COMMIT} || exit 1 && \
    case ${TARGETARCH:-amd64} in \
        "arm64") CMAKE_ARCH="armv8-a"; CMAKE_BUILD_TAG="linux-armv8" ;; \
        "amd64") CMAKE_ARCH="x86-64"; CMAKE_BUILD_TAG="linux-x64" ;; \
        *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac \
    && mkdir -p build/release && cd build/release \
    && cmake -D ARCH=${CMAKE_ARCH} -D STATIC=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG=${CMAKE_BUILD_TAG} ../.. \
    && cd /monero && nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} -C build/release

ENTRYPOINT ["/bin/sh"]
