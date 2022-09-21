ARG REGNO_UBUNTU_VERSION
FROM regno-ubuntu:${REGNO_UBUNTU_VERSION}

ENV DEBIAN_FRONTEND="noninteractive"
RUN apt-get -y install --no-install-recommends build-essential cmake \
    pkg-config libboost-all-dev libssl-dev libzmq3-dev ca-certificates \
    libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev \
    libexpat1-dev doxygen graphviz libpgm-dev qttools5-dev-tools libhidapi-dev \
    libusb-dev libprotobuf-dev protobuf-compiler libgtest-dev git wget \
    libnorm-dev libpgm-dev libusb-1.0-0-dev libudev-dev libgssapi-krb5-2

WORKDIR /usr/src/gtest
RUN cmake . && make && cp ./lib/libgtest*.a /usr/lib

WORKDIR /tmp
# Build expat, a dependency for libunbound
RUN set -ex && wget https://github.com/libexpat/libexpat/releases/download/R_2_4_8/expat-2.4.8.tar.bz2 && \
    echo "a247a7f6bbb21cf2ca81ea4cbb916bfb9717ca523631675f99b3d4a5678dcd16  expat-2.4.8.tar.bz2" | sha256sum -c && \
    tar -xf expat-2.4.8.tar.bz2 && \
    rm expat-2.4.8.tar.bz2 && \
    cd expat-2.4.8 && \
    ./configure --enable-static --disable-shared --prefix=/usr && \
    make -j${NPROC:-$(nproc)} && \
    make -j${NPROC:-$(nproc)} install

# Build libunbound for static builds
WORKDIR /tmp
RUN set -ex && wget https://www.nlnetlabs.nl/downloads/unbound/unbound-1.16.1.tar.gz && \
    echo "2fe4762abccd564a0738d5d502f57ead273e681e92d50d7fba32d11103174e9a  unbound-1.16.1.tar.gz" | sha256sum -c && \
    tar -xzf unbound-1.16.1.tar.gz && \
    rm unbound-1.16.1.tar.gz && \
    cd unbound-1.16.1 && \
    ./configure --disable-shared --enable-static --without-pyunbound --with-libexpat=/usr --with-ssl=/usr --with-libevent=no --without-pythonmodule --disable-flto --with-pthreads --with-libunbound-only --with-pic && \
    make -j${NPROC:-$(nproc)} && \
    make -j${NPROC:-$(nproc)} install


# Switch to Monero source directory
WORKDIR /root/monero

# Git pull Monero source at specified tag/branch
ARG REGNO_MONEROD_VERSION
RUN  git clone --recurse-submodules --shallow-submodules --depth 1 \
    --branch ${REGNO_MONEROD_VERSION} \
    https://github.com/monero-project/monero .

ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1
ARG TARGETARCH
ARG REGNO_MONEROD_COMMIT
RUN test `git rev-parse HEAD` = ${REGNO_MONEROD_COMMIT} || exit 1 && \
    case ${TARGETARCH:-amd64} in \
        "arm64") CMAKE_ARCH="armv8-a"; CMAKE_BUILD_TAG="linux-armv8" ;; \
        "amd64") CMAKE_ARCH="x86-64"; CMAKE_BUILD_TAG="linux-x64" ;; \
        *) echo "Dockerfile does not support this platform"; exit 1 ;; \
    esac \
    && mkdir -p build/release && cd build/release \
    && cmake -D ARCH=${CMAKE_ARCH} -D STATIC=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG=${CMAKE_BUILD_TAG} ../.. \
    && cd /root/monero && nice -n 19 ionice -c2 -n7 make -j$(nproc) -C build/release

ENTRYPOINT ["/bin/sh"]
