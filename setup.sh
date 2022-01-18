#!/bin/bash

TXTRED=$(tput setaf 1)
TXTGREEN=$(tput setaf 2)
TXTBOLD=$(tput bold)
TXTNORMAL=$(tput sgr0)

function display_message {
    MSG="$1"
    STATE="$2"
    if [[ "$2" == "0" ]]; then
        DISPLAY="[${TXTBOLD}${TXTGREEN}OK${TXTNORMAL}] - $MSG"
    else
        DISPLAY="[${TXTBOLD}${TXTRED}KO${TXTNORMAL}] - $MSG"
    fi
    echo -e "${DISPLAY}"
}

function is_binary_present {
    which $1 >/dev/null 2>&1
    if [[ "$?" != "0" ]]; then
        echo "La commande $1 est manquante"
        exit 1
     fi
}

function start {
    create_containers
    docker exec --user ansible -w /home/ansible/workdir/ -it ansible bash -l
}

function create_containers {
    download_images
    create_network ansible101 10.0.101.0/24
    create_container ansible 10.0.101.123 nanio/ansible101:controller
    create_container node1 10.0.101.10 nanio/ansible101:node
    create_container node2 10.0.101.20 nanio/ansible101:node
    create_container node3 10.0.101.30 nanio/ansible101:node
}

function create_network {
    network_name=$1
    network_subnet=$2
    docker network inspect ${network_name} >/dev/null 2>&1
    if [[ "$?" != "0" ]]; then
        docker network create --subnet="${network_subnet}" "${network_name}" >/dev/null 2>&1
        display_message "Création du network $network_name" $?
    else
        display_message "Le network ${network_name} est déjà présent" 0
    fi
}

function create_container {
    container_name=$1
    container_ip=$2
    container_image=$3
    container_id="$(docker ps -a -q -f name=${container_name})"
    if [[ $container_id == "" ]]; then
        docker run -d -h "${container_name}" --name "${container_name}" --net ansible101 --ip "${container_ip}" --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro "${container_image}" >/dev/null 2>&1
        display_message "Création de $container_name" $?
    else
        is_running=$(docker inspect -f '{{.State.Running}}' $container_id)
        if [[ "$is_running" == "false" ]]; then
            docker start ${container_id} >/dev/null 2>&1
            display_message "Démarrage de $container_name" $?
        else
            display_message "Le container ${container_name} est déjà présent" 0
        fi
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

function stop_containers {
    for container in ansible node1 node2 node3; do
        if container_exists $container; then
            docker stop $container >/dev/null 2>&1
            display_message "Arrêt de $container" $?
        fi
    done
}

function download_images {
    docker pull nanio/ansible101:controller >/dev/null 2>&1
    display_message "L'image ansible a été téléchargée" $?
    docker pull nanio/ansible101:node >/dev/null 2>&1
    display_message "L'image des noeuds a été téléchargée" $?
}

function delete_containers {
    for container in ansible node1 node2 node3; do
        if container_exists $container; then
            docker rm --force $container >/dev/null 2>&1
            display_message "Suppression de $container" $?
        fi
    done
    NETWORK=$(docker network ls | grep ansible101)
    if [[ "$NETWORK" != "" ]]; then
        docker network rm ansible101 >/dev/null 2>&1
        display_message "Suppression du network" $?
    fi
    IMAGES=$(docker images | grep "nanio/ansible101" | awk '{print $3}')
    if [[ "$IMAGES" != "" ]]; then
        docker rmi $IMAGES >/dev/null 2>&1
        display_message "Suppression des images" $?
    fi
}

function show_help {
    echo "Description:
  Ce script permet de charger un environment pour réaliser des labs Ansible

Usage:
  ./ansible101 [command]

Available Commands:
  help        Affiche cette aide
  start       Déploie les containers pour le lab
  download    Télécharge les images pour le lab
  delete      Supprime les containers
  stop        Quitte et nettoie l'environnement de lab"
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
else
    echo -e "$ACTION n'est pas une commande reconnue\n"
    show_help
fi

exit 0
