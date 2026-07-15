#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

if [ "$(id -u)" -ne 0 ]; then
    printf 'ERROR: install.sh must be executed as root.\n' >&2
    exit 1
fi

for dependency in bash curl; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
        printf 'ERROR: missing dependency: %s\n' "${dependency}" >&2
        exit 1
    fi
done

install -d -m 755 /etc/empretel-sentinel
install -d -m 755 /etc/empretel-sentinel/services
install -d -m 755 /var/log/empretel-sentinel
install -d -m 755 /var/lib/empretel-sentinel

if [ ! -e /etc/empretel-sentinel/sentinel.conf ]; then
    install \
        -m 600 \
        "${BASE_DIR}/config/sentinel.conf.example" \
        /etc/empretel-sentinel/sentinel.conf

    printf '%s\n' \
        'Created /etc/empretel-sentinel/sentinel.conf'
fi

for service_config_example in \
    "${BASE_DIR}"/services/*/service.conf.example
do
    [ -f "${service_config_example}" ] || continue

    service_name="$(
        basename "$(dirname "${service_config_example}")"
    )"

    service_config="/etc/empretel-sentinel/services/${service_name}.conf"

    if [ ! -e "${service_config}" ]; then
        install \
            -m 600 \
            "${service_config_example}" \
            "${service_config}"

        printf 'Created %s\n' "${service_config}"
    fi
done

ln -sfn \
    "${BASE_DIR}/bin/empretel-sentinel" \
    /usr/local/sbin/empretel-sentinel

ln -sfn \
    "${BASE_DIR}/bin/empretel-notify" \
    /usr/local/sbin/empretel-notify

ln -sfn \
    "${BASE_DIR}/bin/empretel-recover" \
    /usr/local/sbin/empretel-recover

printf '%s\n' \
    'EMPRETEL Sentinel installed successfully.'
