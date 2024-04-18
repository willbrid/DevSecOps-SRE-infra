#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour installer haproxy dans l'intervalle 
#   de version 2.6 à 2.9 sur une machine vagrant Rocky linux 8. Il active aussi
#   l'exporteur prometheus intégré.
#
# Utilisation :
#   sudo ./haproxy-setup.sh [options]
#
# Options :
#   -h, --help         Afficher cette aide
#   --version          La version de haproxy à installer (Entre 2.6 et 2.9)

# Initialisation des variables
default_version="2.6.17"
version="$default_version"
download_url=""

readonly VERSION_VALIDATION="^2\.[6-9]\.[0-50]+$"
readonly HAS_CURL="$(type "curl" &> /dev/null && echo true || echo false)"
readonly HAS_WGET="$(type "wget" &> /dev/null && echo true || echo false)"

# Vérification de l'exécution en mode root
check_if_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script doit être exécuté en tant que root."
        exit 1
    fi
}

# Définition de la fonction d'aide
display_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help         Afficher cette aide"
    echo "  --version          La version de haproxy à installer (Entre 2.6 et 2.9, par défaut $default_version)"
}

verify_options() {
    if [ "$version" != "$default_version" ]; then
      if ! [[ $version =~ $VERSION_VALIDATION ]]; then
        echo "Erreur: $version n'est pas sous le format x.y.z où x, y et z sont des nombres avec 2.6 <= x.y <= 2.9)."
        exit 1
      fi
    fi
}

check_dependency() {
    if [ "$HAS_CURL" != "true" ] && [ "$HAS_WGET" != "true" ] ; then
        echo "Erreur: veuillez installer curl ou wget."
        exit 1
    fi
}

setup_prerequisites() {
    dnf -q config-manager --enable powertools
    dnf -q install -y gcc openssl-devel readline-devel systemd-devel make pcre-devel tar lua lua-devel > /dev/null

    echo -e "\nInstallation des dépendances de haproxy : OK\n"
}

install_haproxy() {
    MAJOR_VERSION="${version%.*}"
    HAPROXY_DIST="haproxy-$version.tar.gz"
    HAPROXY_TMP_ROOT="$(mktemp -dt haproxy-installer-XXXXXXX)"
    DOWNLOAD_URL="https://www.haproxy.org/download/$MAJOR_VERSION/src/$HAPROXY_DIST"
    
    if [ "${HAS_CURL}" == "true" ]; then
        curl -SsL "$DOWNLOAD_URL" -o "$HAPROXY_TMP_ROOT/$HAPROXY_DIST"
    elif [ "${HAS_WGET}" == "true" ]; then
        wget -q -O "$HAPROXY_TMP_ROOT/$HAPROXY_DIST" "$DOWNLOAD_URL"
    fi

    echo -e "\nInstallation de haproxy : OK\n"
}

# Nettoyage du répertoire temporaire d'installation de haproxy
cleanup() {
  if [[ -d "${HAPROXY_TMP_ROOT:-}" ]]; then
    rm -rf "$HAPROXY_TMP_ROOT"
  fi
}

# fail_trap est exécuté si une erreur se produit.
fail_trap() {
    local result=$?
    
    if [ "$result" != "0" ]; then
        echo -e "\nEchec d'installation de haproxy."
    fi
    cleanup

    exit $result
}


# Execution

# Arrêter l'exécution en cas d'erreur
trap "fail_trap" EXIT
set -e

check_if_root

# Traitement des options avec getopts
while getopts ":h-:" opt; do
    case ${opt} in
        h)
          display_help
          exit 0
          ;;
        -)
            case "${OPTARG}" in
                version=*)
                  version="${OPTARG#*=}"
                  ;;
                help)
                  display_help
                  exit 0
                  ;;
                *)
                  echo "Option invalide: --${OPTARG}"
                  exit 1
                  ;;
            esac
            ;;
        \?)
            echo "Option invalide: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

verify_options
check_dependency
setup_prerequisites
install_haproxy
cleanup

exit 0