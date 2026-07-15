#!/usr/bin/env bash

set -u

callmebot_request() {
    local endpoint="$1"
    shift

    curl \
        --fail \
        --silent \
        --show-error \
        --get \
        --max-time "${HTTP_TIMEOUT:-10}" \
        "$@" \
        "${endpoint}"
}
