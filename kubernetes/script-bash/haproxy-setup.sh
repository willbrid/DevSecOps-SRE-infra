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
    readonly MAJOR_VERSION="${version%.*}"
    readonly HAPROXY_DIST_NAME="haproxy-$version"
    readonly HAPROXY_DIST="$HAPROXY_DIST_NAME.tar.gz"
    readonly HAPROXY_TMP_ROOT="$(mktemp -dt haproxy-installer-XXXXXXX)"
    readonly DOWNLOAD_URL="https://www.haproxy.org/download/$MAJOR_VERSION/src/$HAPROXY_DIST"
    
    if [ "${HAS_CURL}" == "true" ]; then
        curl -SsL "$DOWNLOAD_URL" -o "$HAPROXY_TMP_ROOT/$HAPROXY_DIST"
    elif [ "${HAS_WGET}" == "true" ]; then
        wget -q -O "$HAPROXY_TMP_ROOT/$HAPROXY_DIST" "$DOWNLOAD_URL"
    fi

    tar Czxvf $HAPROXY_TMP_ROOT $HAPROXY_TMP_ROOT/$HAPROXY_DIST > /dev/null
    make -C $HAPROXY_TMP_ROOT/$HAPROXY_DIST_NAME TARGET=linux-glibc USE_LUA=1 USE_OPENSSL=1 USE_PCRE=1 USE_ZLIB=1 USE_SYSTEMD=1 USE_PROMEX=1 > /dev/null
    make -C $HAPROXY_TMP_ROOT/$HAPROXY_DIST_NAME install-bin > /dev/null

    if ! command -v /usr/local/sbin/haproxy &> /dev/null; then
        exit 1
    fi

    echo -e "\nInstallation de haproxy : OK\n"
}

configure_haproxy() {
    readonly BIGEST_UID=$(awk -F: '$3 ~ /^[0-9]{4}$/ {print $3}' /etc/passwd | sort -n | tail -n 1)
    readonly BIGEST_GID=$(awk -F: '$4 ~ /^[0-9]{4}$/ {print $4}' /etc/passwd | sort -n | tail -n 1)
    readonly HAPROXY_UID=$(expr "$BIGEST_UID" + 1)
    readonly HAPROXY_GID=$(expr "$BIGEST_GID" + 1)

    readonly HAPROXY_HOME="/var/lib/haproxy"
    readonly HAPROXY_CONFIG_HOME="/etc/haproxy"
    readonly HAPROXY_CONFIG_FILE="$HAPROXY_CONFIG_HOME/haproxy.cfg"
    readonly HAPROXY_SYSTEMD_FILE="/etc/systemd/system/haproxy.service"

    # Créer un utilisateur haproxy
    groupadd -g $HAPROXY_GID haproxy
    useradd -g $HAPROXY_GID -u $HAPROXY_UID -m -d $HAPROXY_HOME -s /sbin/nologin -c haproxy haproxy

    mkdir -p $HAPROXY_CONFIG_HOME

    cat << EOF | tee $HAPROXY_CONFIG_FILE
global
  zero-warning
  maxconn 2000
  chroot $HAPROXY_HOME
  user haproxy
  group haproxy
  daemon
  hard-stop-after 5m
  log stderr local0 info

defaults tcp
  mode tcp
  option tcplog
  log global
  timeout client 30s
  timeout server 30s
  timeout connect 10s
EOF

    chown -R haproxy:haproxy $HAPROXY_CONFIG_HOME

    cat << EOF | tee $HAPROXY_SYSTEMD_FILE
[Unit]
Description=HAProxy $version
After=syslog.target network.target

[Service]
Type=notify
ExecStart=/usr/local/sbin/haproxy -f $HAPROXY_CONFIG_FILE -p /var/run/haproxy.pid -Ws
ExecReload=/bin/kill -USR2 \$MAINPID
ExecStop=/bin/kill -USR1 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    setsebool -P haproxy_connect_any 1
    systemctl daemon-reload
    systemctl enable --now haproxy

    if ! systemctl is-active --quiet haproxy; then
        exit 1
    fi

    echo -e "\nConfiguration de base de haproxy : OK\n"
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
configure_haproxy
cleanup

exit 0