#!/usr/bin/env bash

set -u

PROVIDER_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

source "${PROVIDER_DIR}/../callmebot-common.sh"

provider_validate() {
    [ -n "${CALLMEBOT_TELEGRAM_USERS:-}" ] || {
        printf 'CALLMEBOT_TELEGRAM_USERS is not configured.'
        return 1
    }

    printf 'Configuration valid.'
}

provider_send() {
    local subject="$1"
    local message="$2"
    local detail_file="${3:-}"
    local response

    response="$(
        callmebot_request \
            'https://api.callmebot.com/text.php' \
            --data-urlencode "user=${CALLMEBOT_TELEGRAM_USERS}" \
            --data-urlencode "text=${message}" \
            --data-urlencode 'html=no' \
            --data-urlencode 'links=no'
    )" || return 1

    printf 'Request accepted.'
}
