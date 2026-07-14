#!/usr/bin/env bash

set -euo pipefail

callmebot_send() {
    local message="$1"

    if [ -z "${CALLMEBOT_PHONE:-}" ]; then
        printf 'CALLMEBOT_PHONE is not configured.\n' >&2
        return 1
    fi

    if [ -z "${CALLMEBOT_APIKEY:-}" ]; then
        printf 'CALLMEBOT_APIKEY is not configured.\n' >&2
        return 1
    fi

    curl \
        --fail \
        --silent \
        --show-error \
        --get \
        --max-time "${HTTP_TIMEOUT:-10}" \
        --data-urlencode "phone=${CALLMEBOT_PHONE}" \
        --data-urlencode "text=${message}" \
        --data-urlencode "apikey=${CALLMEBOT_APIKEY}" \
        'https://api.callmebot.com/whatsapp.php'
}
