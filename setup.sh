#!/bin/bash

function is_binary_present {
    which $1 >/dev/null 2>&1
    if [[ "$?" != "0" ]]; then
        echo "La commande $1 est manquante"
        exit 1
     fi
}

function container_exists {
    container_name=$1
    container_id=$(docker ps -a -q -f name=${container_name})
    if [[ $container_id == "" ]]; then
        return 1
    else
        return 0
    fi
}

function show_help {
    echo "Description:
  Ce script permet de build les Dockerfile present dans ce repo

Usage:
  ./setup.sh [command]

Available Commands:
  help        Affiche cette aide
  build       Build les images Docker
  push        Push les images
  run         Run les images
  rm          Supprime les containers
  rmi         Supprime les images
"
}

function files {
    PATTERN="${1:-.*}"
    FILES=$(find . -name "*.Dockerfile" -maxdepth 1 | grep -e "${PATTERN}")
    echo "$FILES"
}

function build {
    for DOCKERFILE in $1; do
        IFS=- read distro version <<< "$(basename "${DOCKERFILE}" | sed -E 's/([a-z]*)([0-9]*.*).Dockerfile/\1-\2/g')"
        docker build -f ${DOCKERFILE} -t nanio/systemd-${distro}:${version} .
    done
}

function push {
    for DOCKERFILE in $1; do
        IFS=- read distro version <<< "$(basename "${DOCKERFILE}" | sed -E 's/([a-z]*)([0-9]*.*).Dockerfile/\1-\2/g')"
        docker image tag nanio/systemd-${distro}:${version} ghcr.io/nani-o/systemd-${distro}:${version}
        docker image push ghcr.io/nani-o/systemd-${distro}:${version}
    done
}

function rmi {
    for DOCKERFILE in $1; do
        IFS=- read distro version <<< "$(basename "${DOCKERFILE}" | sed -E 's/([a-z]*)([0-9]*.*).Dockerfile/\1-\2/g')"
        id=$(docker images | grep -e "nanio/systemd-${distro} *${version}" | awk '{print $3}')
        [[ ! -z "${id}" ]] && docker rmi -f "${id}"
    done
}

function run {
    for DOCKERFILE in $1; do
        IFS=- read distro version <<< "$(basename "${DOCKERFILE}" | sed -E 's/([a-z]*)([0-9]*.*).Dockerfile/\1-\2/g')"
        name="test-${distro}-${version}"
        docker run -d -h ${name} --name ${name} nanio/systemd-${distro}:${version}
    done
}

function remove {
    for DOCKERFILE in $1; do
        IFS=- read distro version <<< "$(basename "${DOCKERFILE}" | sed -E 's/([a-z]*)([0-9]*.*).Dockerfile/\1-\2/g')"
        name="test-${distro}-${version}"
        if container_exists $name; then
            docker rm -f ${name}
        fi
    done
}

is_binary_present docker

ACTION="$1"

if [[ -z "$ACTION" || "$ACTION" == "help" ]]; then
    show_help
elif [[ "$ACTION" == "build" ]]; then
    shift
    build "$(files "${1}")"
elif [[ "$ACTION" == "rmi" ]]; then
    shift
    rmi "$(files "${1}")"
elif [[ "$ACTION" == "run" ]]; then
    shift
    run "$(files "${1}")"
elif [[ "$ACTION" == "rm" ]]; then
    shift
    remove "$(files "${1}")"
elif [[ "$ACTION" == "push" ]]; then
    shift
    push "$(files "${1}")"
else
    echo -e "$ACTION n'est pas une commande reconnue\n"
    show_help
fi

exit 0
