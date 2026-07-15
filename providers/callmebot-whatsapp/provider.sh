#!/usr/bin/env bash

set -u

PROVIDER_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

source "${PROVIDER_DIR}/../callmebot-common.sh"

provider_validate() {
    [ -n "${CALLMEBOT_PHONE:-}" ] || {
        printf 'CALLMEBOT_PHONE is not configured.'
        return 1
    }

    [ -n "${CALLMEBOT_APIKEY:-}" ] || {
        printf 'CALLMEBOT_APIKEY is not configured.'
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
            'https://api.callmebot.com/whatsapp.php' \
            --data-urlencode "phone=${CALLMEBOT_PHONE}" \
            --data-urlencode "text=${message}" \
            --data-urlencode "apikey=${CALLMEBOT_APIKEY}"
    )" || return 1

    if grep -qiE 'queued|message to:' <<< "${response}"; then
        printf 'Message queued.'
    else
        printf 'Request accepted.'
    fi
}
