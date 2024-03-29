FROM    golang:1.16.6-buster AS builder

ENV     TOR_URL             https://dist.torproject.org
ENV     TOR_MIRROR_URL      https://tor.eff.org/dist
ENV     TOR_VERSION         0.4.8.6
ENV     TOR_GPG_KS_URI      hkps://keyserver.ubuntu.com:443
ENV     TOR_GPG_KEYS        0xEB5A896A28988BF5 0xC218525819F78451 0x21194EBB165733EA 0x6AFEE6D49E92B601 B74417EDDF22AC9F9E90F49142E86A2A11F48D36 514102454D0A87DB0767A1EBBE6A0531C18A9179

ENV     OBFS4_URL           https://github.com/Yawning/obfs4.git
ENV     OBFS4_VERSION       0.0.13


# Install Tor
RUN     set -ex && \
        apt-get update && \
        apt-get install -y git libevent-dev zlib1g-dev libssl-dev gcc make automake ca-certificates autoconf musl-dev coreutils gpg wget python3 && \
        mkdir -p /usr/local/src/ && \
        cd /usr/local/src && \
        res=0; \
        wget -qO "tor-$TOR_VERSION.tar.gz" "$TOR_URL/tor-$TOR_VERSION.tar.gz" || res=$?; \
        if [ $res -gt 0 ]; then \
          wget -qO "tor-$TOR_VERSION.tar.gz" "$TOR_MIRROR_URL/tor-$TOR_VERSION.tar.gz"; \
        fi && \
        res=0; \
        wget -qO "tor-$TOR_VERSION.tar.gz.sha256sum" "$TOR_URL/tor-$TOR_VERSION.tar.gz.sha256sum" || res=$?; \
        if [ $res -gt 0 ]; then \
          wget -qO "tor-$TOR_VERSION.tar.gz.sha256sum" "$TOR_MIRROR_URL/tor-$TOR_VERSION.tar.gz.sha256sum"; \
        fi && \
        res=0; \
        wget -qO "tor-$TOR_VERSION.tar.gz.sha256sum.asc" "$TOR_URL/tor-$TOR_VERSION.tar.gz.sha256sum.asc" || res=$?; \
        if [ $res -gt 0 ]; then \
          wget -qO "tor-$TOR_VERSION.tar.gz.sha256sum.asc" "$TOR_MIRROR_URL/tor-$TOR_VERSION.tar.gz.sha256sum.asc"; \
        fi && \
        gpg --batch --keyserver "$TOR_GPG_KS_URI" --recv-keys $TOR_GPG_KEYS && \
        gpg --verify "tor-$TOR_VERSION.tar.gz.sha256sum.asc" && \
        sha256sum --ignore-missing --check "tor-$TOR_VERSION.tar.gz.sha256sum" && \
        tar -xzvf "tor-$TOR_VERSION.tar.gz" -C /usr/local/src && \
        cd "/usr/local/src/tor-$TOR_VERSION" && \
        ./configure \
            --disable-asciidoc \
            --sysconfdir=/etc \
            --disable-unittests && \
        make && make install && \
        cd .. && \
        rm -rf "tor-$TOR_VERSION" && \
        rm "tor-$TOR_VERSION.tar.gz" "tor-$TOR_VERSION.tar.gz.sha256sum" "tor-$TOR_VERSION.tar.gz.sha256sum.asc"

# Install Golang & OBFS4 proxy
RUN     git clone "$OBFS4_URL" /usr/local/src/obfs4proxy && \
        cd /usr/local/src/obfs4proxy && \
        git checkout "tags/obfs4proxy-$OBFS4_VERSION" && \
        go build -o obfs4proxy/obfs4proxy ./obfs4proxy && \
        cp ./obfs4proxy/obfs4proxy /usr/local/bin && \
        cd .. && \
        rm -rf obfs4proxy

FROM    debian:buster-slim

ENV     TOR_HOME        /var/lib/tor
ENV     TOR_BIN         /usr/local/bin/tor
ENV     TOR_CONF        /etc/tor
ENV     TOR_MAN         /usr/local/share/man
ENV     OBFS_PROXY      /usr/local/bin/obfs4proxy

#ARG     TOR_LINUX_UID
#ARG     TOR_LINUX_GID

COPY    --from=builder $TOR_BIN $TOR_BIN
COPY    --from=builder $TOR_CONF $TOR_CONF
COPY    --from=builder $TOR_MAN $TOR_MAN
COPY    --from=builder $OBFS_PROXY $OBFS_PROXY

RUN     set -ex && \
        apt-get update && \
        apt-get install -y libevent-dev

# Create group & user tor
#RUN     addgroup --system -gid ${TOR_LINUX_GID} tor && \
#        adduser --system --ingroup tor -uid ${TOR_LINUX_UID} tor

RUN     addgroup --system tor && \
        adduser --system --ingroup tor tor

# Create /etc/tor directory
RUN     mkdir -p /etc/tor/ && \
        chown -Rv tor:tor /etc/tor

# Create .tor subdirectory of TOR_HOME
RUN     mkdir -p "$TOR_HOME/.tor" && \
        chown -Rv tor:tor "$TOR_HOME" && \
        chmod -R 750 "$TOR_HOME"

# Copy tor.sh
COPY    ./tor.sh /tor.sh

RUN     chown tor:tor /tor.sh && \
        chmod u+x /tor.sh && \
        chmod g+x /tor.sh

# Copy wait-for
COPY    ./wait-for /wait-for

RUN     chown tor:tor /wait-for && \
        chmod ug+x /wait-for

# Expose socks port
EXPOSE  ${TOR_SOCKS_PORT}

# Switch to user tor
USER    tor
