#!/usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf 'ERROR: uninstall.sh must be executed as root.\n' >&2
    exit 1
fi

rm -f \
    /usr/local/sbin/empretel-sentinel \
    /usr/local/sbin/empretel-notify \
    /usr/local/sbin/empretel-recover

printf '%s\n' \
    'EMPRETEL Sentinel command links were removed.'

printf '%s\n' \
    'Configuration, logs and state were preserved.'
