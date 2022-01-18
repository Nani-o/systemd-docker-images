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
    FILES=$(find . -name "*.Dockerfile" -maxdepth 1 | grep -e "${PATTERN}" | sort)
    echo "$FILES"
}

function _build {
    docker build -q -f ${DOCKERFILE} -t ${LOCAL_IMAGE} .
}

function _push {
    docker image tag ${LOCAL_IMAGE} ${REMOTE_IMAGE}
    docker image push -q ${REMOTE_IMAGE}
}

function _run {
    _build
    if ! container_exists ${CONTAINER_NAME}; then
        docker run -d -h ${CONTAINER_NAME} --name ${CONTAINER_NAME} ${LOCAL_IMAGE}
    fi
}

function _rm {
    if container_exists ${CONTAINER_NAME}; then
        docker rm -f ${CONTAINER_NAME}
    fi
}

function _rmi {
    id=$(docker images | grep -e "^${IMAGE_NAME} *${TAG}" | awk '{print $3}')
    [[ ! -z "${id}" ]] && docker rmi -f "${id}"
}

function _purge {
    _rm
    _rmi
}

function execute {
    ACTION="${1}"
    DOCKERFILE="${2}"
    IFS=- read DISTRO TAG <<< "$(basename "${DOCKERFILE}" | sed -E 's/([a-z]*)([0-9]*.*).Dockerfile/\1-\2/g')"
    IMAGE_NAME="nani-o/systemd-${DISTRO}"
    LOCAL_IMAGE="${IMAGE_NAME}:${TAG}"
    REMOTE_IMAGE="ghcr.io/${LOCAL_IMAGE}"
    CONTAINER_NAME="systemd-${DISTRO}-${TAG}"
    "${ACTION}"
}

function main {
    files "${PATTERN}" | xargs -L 1 -P 0 -I {} bash -c "execute _${ACTION} {}"
}

export -f container_exists

export -f execute
export -f _build
export -f _push
export -f _run
export -f _rm
export -f _rmi
export -f _purge

is_binary_present docker

ACTION="$1"
PATTERN="$2"

if [[ -z "$ACTION" || "$ACTION" == "help" ]]; then
    show_help
elif [[ "$ACTION" == "build" || \
        "$ACTION" == "push" || \
        "$ACTION" == "run" || \
        "$ACTION" == "rm" || \
        "$ACTION" == "rmi" || \
        "$ACTION" == "purge" ]]; then
    shift
    main
else
    echo -e "$ACTION n'est pas une commande reconnue\n"
    show_help
fi

exit 0
