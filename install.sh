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

CONFIG_FILE="/etc/empretel-sentinel/sentinel.conf"
LATEST_CONFIG_VERSION="2"

INSTALL_CREATED=0
INSTALL_MIGRATED=0
INSTALL_UPDATED=0

if [ ! -e "${CONFIG_FILE}" ]; then
    install \
        -m 600 \
        "${BASE_DIR}/config/sentinel.conf.example" \
        "${CONFIG_FILE}"

    INSTALL_CREATED=1

else
    installed_config_version="$(
        awk -F= '
            $1 == "CONFIG_VERSION" {
                gsub(/["[:space:]]/, "", $2)
                print $2
                exit
            }
        ' "${CONFIG_FILE}"
    )"

    installed_config_version="${installed_config_version:-1}"

    if [[ ! "${installed_config_version}" =~ ^[0-9]+$ ]]; then
        printf 'Invalid CONFIG_VERSION in %s: %s\n' \
            "${CONFIG_FILE}" \
            "${installed_config_version}" >&2
        exit 1
    fi

    if [ "${installed_config_version}" -lt "${LATEST_CONFIG_VERSION}" ]; then

        if ! grep -q '^# BEGIN OPTIONAL PROVIDERS$' "${CONFIG_FILE}"; then
            cat \
                "${BASE_DIR}/config/optional-providers.conf.example" \
                >> "${CONFIG_FILE}"
        fi

        if grep -q '^CONFIG_VERSION=' "${CONFIG_FILE}"; then
            sed -i \
                "s/^CONFIG_VERSION=.*/CONFIG_VERSION=\"${LATEST_CONFIG_VERSION}\"/" \
                "${CONFIG_FILE}"
        else
            tmp="$(mktemp)"

            {
                printf 'CONFIG_VERSION="%s"\n\n' \
                    "${LATEST_CONFIG_VERSION}"
                cat "${CONFIG_FILE}"
            } > "${tmp}"

            install -m 600 "${tmp}" "${CONFIG_FILE}"
            rm -f "${tmp}"
        fi

        INSTALL_MIGRATED=1
    fi
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

        INSTALL_UPDATED=1
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

if [ "${INSTALL_CREATED}" -eq 1 ]; then
    echo "EMPRETEL Sentinel installed successfully."
elif [ "${INSTALL_MIGRATED}" -eq 1 ]; then
    echo "EMPRETEL Sentinel configuration upgraded successfully."
elif [ "${INSTALL_UPDATED}" -eq 1 ]; then
    echo "EMPRETEL Sentinel updated successfully."
else
    echo "EMPRETEL Sentinel is already up to date."
fi
