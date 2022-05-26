#!/bin/bash
set -e

echo "Starting tor..."

tor_options=(
    --SocksPort "$NET_REGNO_TOR_IPV4:$REGNO_TOR_SOCKS_PORT"
    --SocksPolicy "accept $REGNONET_SUBNET"
    --SocksPolicy "reject *"
    --DataDirectory /var/lib/tor/.tor
    --DataDirectoryGroupReadable 1
    --HiddenServiceDir /var/lib/tor/hsv3regno
    --HiddenServiceVersion 3
    --HiddenServicePort "80 $NET_DMZ_NGINX_IPV4:80"
)

if [ "$MONEROD_ENABLE" == "on" ]; then
    tor_options+=(--HiddenServiceDir /var/lib/tor/hsv3monerod)
    tor_options+=(--HiddenServiceVersion 3)
    tor_options+=(--HiddenServicePort "18080 $NET_REGNO_MONEROD_IPV4:$REGNO_MOENROD_P2P_PORT")
    tor_options+=(--HiddenServiceDirGroupReadable 1)
fi

if [ "$EXPLORER_ENABLE" == "on" ]; then
    tor_options+=(--HiddenServiceDir /var/lib/tor/hsv3explorer)
    tor_options+=(--HiddenServiceVersion 3)
    tor_options+=(--HiddenServicePort "80 $NET_DMZ_NGINX_IPV4:$REGNO_EXPLORER_PORT")
    tor_options+=(--HiddenServiceDirGroupReadable 1)
fi

tor "${tor_options[@]}"
