#!/bin/bash

#if [ ! -d "docker/monerod" ]; then
#    echo "regno.sh must run in the 'regno' dir - aborting."
#    exit 1
#fi

cd "$(dirname "${BASH_SOURCE[0]}")"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
REGNO_CONFIG_PATH="$DIR/docker/regno.conf"

# Make sure we run from the regno/docker dir.
# If we don't do this, we run into very weird issues regarding docker-compose
# and build args not being passed correctly to the override compose files' Dockerfiles.
cd "$(dirname "${BASH_SOURCE[0]}")/docker" || exit 1

read -r dialog <<< "$(which whiptail dialog gdialog kdialog 2> /dev/null)"

print_config() {
echo "\
REGNO_TOR_ENABLE=$REGNO_TOR_ENABLE
REGNO_MONEROD_ENABLE=$REGNO_MONEROD_ENABLE
REGNO_P2POOL_ENABLE=$REGNO_P2POOL_ENABLE
REGNO_EXPLORER_ENABLE=$REGNO_EXPLORER_ENABLE
REGNO_MONEROD_PRUNE=$REGNO_MONEROD_PRUNE
REGNO_MONEROD_NETWORK=$REGNO_MONEROD_NETWORK
REGNO_MONEROD_PUBLIC=$REGNO_MONEROD_PUBLIC
"
}

print_default_config() {
echo "\
REGNO_TOR_ENABLE=yes
REGNO_MONEROD_ENABLE=yes
REGNO_P2POOL_ENABLE=yes
REGNO_EXPLORER_ENABLE=yes
REGNO_MONEROD_PRUNE=no
REGNO_MONEROD_NETWORK=mainnet
REGNO_MONEROD_PUBLIC=no
"
}

write_config() {
    echo "Writing updated configuration to $REGNO_CONFIG_PATH"
    print_config > "$REGNO_CONFIG_PATH"
}

write_default_config() {
    echo "Writing default configuration values to $REGNO_CONFIG_PATH"
    print_default_config > "$REGNO_CONFIG_PATH"
}

if ! [[ -f "$REGNO_CONFIG_PATH" ]]; then
    echo "No existing config found."
    write_default_config
fi

source_file() {
  if [ -f "$1" ]; then
    source "$1"
  else
    echo "Unable to find file $1" >&2
    exit 1
  fi
}

source_file "$DIR/docker/.env"
source_file "$DIR/docker/regno.conf"

help() {
cat <<-EOF
Regno management script (https://github.com/regno-node/regno)
Usage: ./regno.sh [command]

Commands:
  start       Start Regno containers using current config
  setup       Perform interactive setup
  stop        Stop containers
  restart     Restart containers
  build       Build all configured docker images from scratch
  clean       Clean up unused images/containers/networks
  reset       Remove all images/containers/networks/volumes, and reset config file
  update      Update Regno to latest version
  sync        Bring up any missing enabled containers & remove any running disabled containers

EOF
}

check_docker() {
    if ! [[ -x "$(command -v docker)" ]]; then
        echo "Command 'docker' not found. Please install docker, then retry." >&2
        return 1
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        echo "'docker-compose' not found. Please install docker-compose manually, then retry." >&2
        return 1
    fi

    docker version > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        if [ "$OSTYPE" = linux-gnu ]; then
            echo "Docker daemon not running. Attempting to start."
            systemctl start docker
            if [[ $? -ne 0 ]]; then echo "Failed to start docker, exiting..." >&2; exit 1; fi
        else
            echo "Docker daemon not running. Please start it and try again." >&2
        fi
    fi

    return 0
}

setup_enable_services() {
    title="Regno Setup - Services"
    $dialog --title "$title" --checklist --separate-output "Please select the services to enable:" 25 80 15 \
            "monerod" "Monero daemon" on \
            "tor" "Tor" on \
            "explorer" "Monero blockchain explorer" on \
            "p2pool" "P2Pool daemon" on 2>results
    dialogResult=$?
    if [[ $dialogResult ]]; then 
        REGNO_MONEROD_ENABLE=no
        REGNO_EXPLORER_ENABLE=no
        REGNO_P2POOL_ENABLE=no
        REGNO_TOR_ENABLE=no
        while read -r choice
        do
            case $choice in
                monerod ) REGNO_MONEROD_ENABLE=yes ;;
                explorer ) REGNO_EXPLORER_ENABLE=yes ;;
                p2pool ) REGNO_P2POOL_ENABLE=yes ;;
                tor ) REGNO_TOR_ENABLE=yes ;;
                * ) echo "invalid choice selected: $choice" >&2 ;;
            esac
        done < results
    fi
    return $dialogResult
}

setup_monerod_extra() {
    title="Regno Setup - monerod"
    $dialog --title "$title" --checklist --separate-output "Select extra monerod options:" 25 80 15 \
            "prune"       "Run a pruned node (saves disk space but contributes less to the Monero network)" off \
            "testnet"     "Run on testnet instead of mainnet (for testing)" off \
            "public_node" "Advertise to other users they can use this nodes as a remote node" off 2>results
    dialogResult=$?
    if [[ $dialogResult ]]; then
        REGNO_MONEROD_PRUNE=no
        REGNO_MONEROD_NETWORK=mainnet
        REGNO_MONEROD_PUBLIC=no
        while read -r choice
        do
            case $choice in
                prune ) REGNO_MONEROD_PRUNE=yes ;;
                testnet ) REGNO_MONEROD_NETWORK=testnet ;;
                public_node ) REGNO_MONEROD_PUBLIC=yes ;;
                * ) echo "invalid choice selected: $choice" >&2 ;;
            esac
        done < results
    fi
    return $dialogResult
}

get_yaml_base_files() {
    echo "-f docker-compose.yaml -f overrides/base.yaml"
}

get_yaml_build_files() {
    yamlFiles="-f docker-compose.yaml"
    if [[ "$REGNO_MONEROD_ENABLE" == "yes" || "$REGNO_EXPLORER_ENABLE" == "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/monerod-build.yaml"
    fi

    echo "$yamlFiles"
}

get_yaml_run_files() {
    yamlFiles="$yamlFiles -f docker-compose.yaml"

    if [[ "$REGNO_TOR_ENABLE" == "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/tor.yaml"
    fi

    if [[ "$REGNO_MONEROD_ENABLE" == "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/monerod.yaml"
    fi

    if [[ "$REGNO_P2POOL_ENABLE" == "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/p2pool.yaml"
    fi

    if [[ "$REGNO_EXPLORER_ENABLE" == "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/explorer.yaml"
    fi

    echo "$yamlFiles"
}

docker_build() {
    if ! check_docker; then return; fi
    # Run builds in order so we can make use of parallel building while also never using old base images in run files.
    yamlBaseFiles=$(get_yaml_base_files)
    echo "Starting build of all base images: $yamlBaseFiles"
    docker compose $yamlBaseFiles build --parallel "$@"
    if [[ $? -ne 0 ]]; then echo "Build failed. Aborting..." >&2 && exit 1; fi
    yamlBuildFiles=$(get_yaml_build_files)
    echo "Starting build of all build images: $yamlBuildFiles"
    docker compose $yamlBuildFiles build --parallel "$@"
    if [[ $? -ne 0 ]]; then echo "Build failed. Aborting..." >&2 && exit 1; fi
    yamlRunFiles=$(get_yaml_run_files)
    echo "Starting build of all run images: $yamlRunFiles"
    docker compose $yamlRunFiles build --parallel "$@"
    if [[ $? -ne 0 ]]; then echo "Build failed. Aborting..." >&2 && exit 1; fi
}

docker_up() {
    if ! check_docker; then return; fi
    yamlFiles=$(get_yaml_run_files)
    eval "docker compose $yamlFiles up -d --force-recreate --remove-orphans"
}

start() {
    echo "Starting Regno..."
    if ! check_docker; then return; fi
    docker_up
}

stop() {
    if ! check_docker; then return; fi
    yamlFiles=$(get_yaml_run_files)
    eval "docker compose $yamlFiles down"
}

restart() {
    if ! check_docker; then return; fi
    stop
    docker_up
}

sync_containers() {
    running_containers=$(docker compose -p regno ps -q)
    yamlRunFiles=$(get_yaml_run_files)
    echo "Bringing up any enabled containers."
    docker-compose $yamlRunFiles up -d
    enabled_containers=$(docker compose -p regno ps -q)
    obsolete_containers=$(comm -23 <(echo "$running_containers") <(echo "$enabled_containers"))

    if [ ! -z "$obsolete_containers" ]; then
      echo "Stopping all disabled containers."
      docker stop $obsolete_containers
      docker rm $obsolete_containers
    else
      echo "No disabled containers were running."
    fi
}

setup() {
    if [[ ! "$dialog" ]]; then
        echo "Neither 'whiptail' nor 'dialog' command was found. Please install one of them to perform setup." >&2
        exit 1
    fi

    setup_enable_services
    if [[ $? -ne 0 ]]; then echo "Setup cancelled. Configuration has NOT been updated." >&2 && exit 1; fi
    if [[ "$REGNO_MONEROD_ENABLE" == "yes" ]]; then
        setup_monerod_extra
        if [[ $? -ne 0 ]]; then echo "Setup cancelled. Configuration has NOT been updated." >&2 && exit 1; fi
    fi

    write_config
    docker_build --no-cache
    docker_up
}

# Clean-up (remove old docker images)
del_images_for() {
  # $1: image name
  # $2: most recent version of the image (do not delete this one)
  docker image ls | grep "$1" | sed "s/ \+/,/g" | cut -d"," -f2 | while read -r version ; do
    if [ "$2" != "$version" ]; then
      docker image rm -f "$1:$version"
    fi
  done
}

clean() {
    echo "Removing all unused Regno images, containers, and networks..."
    del_images_for regno/ubuntu "$REGNO_UBUNTU_VERSION"
    del_images_for regno/monerod-build "$REGNO_MONEROD_VERSION"
    del_images_for regno/monerod "$REGNO_MONEROD_VERSION"
    del_images_for regno/p2pool "$REGNO_P2POOL_VERSION"
    del_images_for regno/explorer "latest"
    docker network prune -f
    docker container prune -f
    docker image prune -f
}

reset() {
    echo "This will remove all Regno images, containers, networks, volumes, and config files."
    read -p "*** WARNING ***: This will result in losing your synced blockchain data! Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 1
    fi
    stop
    clean
    docker volume prune -f
    write_default_config
}

subcommand=$1; shift

case "$subcommand" in
    setup   ) setup;;
    build   ) docker_build --no-cache;;
    start   ) start;;
    stop    ) stop;;
    restart ) restart;;
    onion   ) onion;;
    clean   ) clean;;
    reset   ) reset;;
    sync    ) sync_containers;;
    *       ) help;;
esac
