#!/bin/bash

if [ ! -d "docker/monerod" ]; then
    echo "regno.sh must run in the `regno` dir - aborting."
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
read dialog <<< "$(which whiptail dialog 2> /dev/null)"
REGNO_CONFIG_PATH="$DIR/docker/regno.conf"

# Make sure we run from the regno/docker dir.
# If we don't do this, we run into very weird issues regarding docker-compose
# and build args not being passed correctly to the override compose files' Dockerfiles.
cd "$(dirname "${BASH_SOURCE[0]}")/docker"

if [[ ! -f /var/run/docker.sock ]]; then
    echo "Docker daemon not running. Attempting to start."
    systemctl start docker
    if [[ ! $? ]]; then echo "Failed to start docker, exiting..."; exit 1; fi
fi

source_file() {
  if [ -f "$1" ]; then
    source "$1"
  else
    echo "Unable to find file $1"
  fi
}

source_file "$DIR/docker/.env"
source_file "$DIR/docker/regno.conf"

help() {
cat <<-EOF
Regno management script (https://github.com/regno-node/regno)
Usage: ./regno.sh [command] [options]

Options:
  --help, -h  Display help text

Commands:
  setup       Perform interactive setup
  build       Build Regno docker images based on configuration
  start       Start Regno
  stop        Stop Regno
  restart     Restart Regno
  update      Update Regno to latest version
EOF
}

check_docker() {
    if ! [[ -x "$(command -v docker)" ]]; then
        echo "'docker' not found. Please install docker manually, then retry."
        return 1
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        echo "'docker-compose' not found. Please install docker-compose manually, then retry."
        return 1
    fi
    return 0
}

print_config() {
echo "\
REGNO_DOCKER_INSTALL=$REGNO_DOCKER_INSTALL
REGNO_TOR_ENABLE=$REGNO_TOR_ENABLE
REGNO_MONEROD_NETWORK=$REGNO_MONEROD_NETWORK
REGNO_MONEROD_ENABLE=$REGNO_MONEROD_ENABLE
REGNO_P2POOL_ENABLE=$REGNO_P2POOL_ENABLE
REGNO_EXPLORER_ENABLE=$REGNO_EXPLORER_ENABLE
"
}

write_config() {
    echo "Saving configuration to $REGNO_CONFIG_PATH"
    print_config > "$REGNO_CONFIG_PATH"
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
        while read choice
        do
            case $choice in
                monerod ) REGNO_MONEROD_ENABLE=yes ;;
                explorer ) REGNO_EXPLORER_ENABLE=yes ;;
                p2pool ) REGNO_P2POOL_ENABLE=yes ;;
                tor ) REGNO_TOR_ENABLE=yes ;;
                * ) echo "invalid choice selected: $choice" ;;
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

    if [[ "$MONEROD_ENABLE" -eq "yes" || "$EXPLORER_ENABLE" -eq "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/monerod-build.yaml"
    fi

    echo "$yamlFiles"
}

get_yaml_run_files() {
    yamlFiles="$yamlFiles -f docker-compose.yaml"

    if [[ "$MONEROD_ENABLE" -eq "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/monerod.yaml"
    fi

    if [[ "$P2POOL_ENABLE" -eq "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/p2pool.yaml"
    fi

    if [[ "$EXPLORER_ENABLE" -eq "yes" ]]; then
        yamlFiles="$yamlFiles -f overrides/explorer.yaml"
    fi

    echo "$yamlFiles"
}

docker_build() {
    if [[ check_docker -ne 0 ]] ; then return; fi
    # Run builds in order so we can make use of cache while never using old base images in run files.
    yamlBaseFiles=$(get_yaml_base_files)
    echo "Starting build of all base images: $yamlBaseFiles"
    docker-compose $yamlBaseFiles build #--no-cache
    if [[ $? -ne 0 ]]; then echo "Build failed. Aborting..." && exit 1; fi
    yamlBuildFiles=$(get_yaml_build_files)
    echo "Starting build of all build images: $yamlBuildFiles"
    docker-compose $yamlBuildFiles build #--no-cache
    if [[ $? -ne 0 ]]; then echo "Build failed. Aborting..." && exit 1; fi
    yamlRunFiles=$(get_yaml_run_files)
    echo "Starting build of all run images: $yamlRunFiles"
    docker-compose $yamlRunFiles build --no-cache
    if [[ $? -ne 0 ]]; then echo "Build failed. Aborting..." && exit 1; fi
}

docker_up() {
    if [[ check_docker -ne 0 ]] ; then return; fi
    yamlFiles=$(get_yaml_run_files)
    eval "docker-compose $yamlFiles up -d --force-recreate --remove-orphans"
}

start() {
    if [[ check_docker -ne 0 ]] ; then return; fi
    isRunning=$(docker inspect --format="{{.State.Running}}" regno/monerod:$REGNO_MONEROD_VERSION 2> /dev/null)

    if [ $? -eq 1 ] || [ "$isRunning" == "false" ]; then
        echo "Starting Regno."
        docker_up
    else
        echo "Regno is already running."
    fi
}

stop() {
    if [[ check_docker -ne 0 ]] ; then return; fi
    yamlFiles=$(get_yaml_run_files)
    eval "docker-compose $yamlFiles stop"
}

restart() {
    if check_docker; then return; fi
    stop
    docker_up
}

setup() {
    if ! [[ "$dialog" ]]; then
        echo "Neither 'whiptail' nor 'dialog' found. Install one of them to perform setup." >&2
        exit 1
    fi

    setup_enable_services
    if [[ ! $? ]]; then echo "Setup cancelled. Configuration has NOT been updated." && exit 1; fi

    write_config
    docker_build
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
  del_images_for regno/ubuntu "$REGNO_UBUNTU_VERSION"
  del_images_for regno/monerod-build "$REGNO_MONEROD_VERSION"
  del_images_for regno/monerod "$REGNO_MONEROD_VERSION"
  del_images_for regno/p2pool "$REGNO_P2POOL_VERSION"
  del_images_for regno/explorer "latest"
  docker container prune -f
  docker volume prune -f
  docker image prune -f
}

while getopts ":h" opt; do
    case ${opt} in
        h )
            help
            exit 0
            ;;
        \? )
    esac
done

subcommand=$1; shift

case "$subcommand" in
    setup   ) setup;;
    build   ) docker_build;;
    start   ) start;;
    stop    ) docker_stop;;
    restart ) docker_restart;;
    onion   ) onion;;
    clean   ) clean;;
    *       ) help;;
esac
