#!/usr/bin/env bash

set -u

SENTINEL_ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

SENTINEL_CONFIG="${SENTINEL_CONFIG:-/etc/empretel-sentinel/sentinel.conf}"

sentinel_error() {
    printf 'ERROR: %s\n' "$*" >&2
}

sentinel_warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

sentinel_load_config() {
    if [ ! -r "${SENTINEL_CONFIG}" ]; then
        sentinel_error "Cannot read configuration: ${SENTINEL_CONFIG}"
        return 1
    fi

    # shellcheck disable=SC1090
    source "${SENTINEL_CONFIG}"

    NODE_NAME="${NODE_NAME:-$(hostname -s)}"
    NOTIFY_PROVIDERS="${NOTIFY_PROVIDERS:-callmebot-whatsapp}"
    LOG_DIR="${LOG_DIR:-/var/log/empretel-sentinel}"
    STATE_DIR="${STATE_DIR:-/var/lib/empretel-sentinel}"
    HTTP_TIMEOUT="${HTTP_TIMEOUT:-10}"

    export \
        NODE_NAME \
        NOTIFY_PROVIDERS \
        LOG_DIR \
        STATE_DIR \
        HTTP_TIMEOUT

    mkdir -p "${LOG_DIR}" "${STATE_DIR}"
}

sentinel_timestamp() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

sentinel_event_id() {
    printf '%s-%04X\n' \
        "$(date '+%Y%m%d-%H%M%S')" \
        "$((RANDOM % 65536))"
}

sentinel_log() {
    local component="$1"
    shift

    mkdir -p "${LOG_DIR}"

    printf '%s [%s] %s\n' \
        "$(sentinel_timestamp)" \
        "${component}" \
        "$*" >> "${LOG_DIR}/${component}.log"
}

sentinel_service_dir() {
    local service_name="$1"

    printf '%s/services/%s\n' \
        "${SENTINEL_ROOT}" \
        "${service_name}"
}

sentinel_service_config() {
    local service_name="$1"

    printf '/etc/empretel-sentinel/services/%s.conf\n' \
        "${service_name}"
}

sentinel_load_service_config() {
    local service_name="$1"
    local config_file

    config_file="$(sentinel_service_config "${service_name}")"

    if [ -r "${config_file}" ]; then
        set -a

        # shellcheck disable=SC1090
        source "${config_file}"

        set +a
    fi
}

sentinel_validate_service_name() {
    local service_name="$1"

    if [[ ! "${service_name}" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        sentinel_error "Invalid service name: ${service_name}"
        return 1
    fi
}

sentinel_status_name() {
    local status="$1"

    case "${status}" in
        0)
            printf 'OK\n'
            ;;
        1)
            printf 'WARNING\n'
            ;;
        2)
            printf 'CRITICAL\n'
            ;;
        3)
            printf 'UNKNOWN\n'
            ;;
        *)
            printf 'INVALID\n'
            ;;
    esac
}

sentinel_milliseconds() {
    date '+%s%3N'
}

sentinel_elapsed() {
    local started_at="$1"
    local finished_at="$2"
    local elapsed

    elapsed="$((finished_at - started_at))"

    printf '%d.%03d s' \
        "$((elapsed / 1000))" \
        "$((elapsed % 1000))"
}

sentinel_slug() {
    printf '%s' "$1" |
        tr '[:upper:]' '[:lower:]' |
        sed 's/[^a-z0-9._-]/_/g'
}

sentinel_fingerprint() {
    printf '%s' "$*" |
        sha256sum |
        awk '{print $1}'
}

sentinel_state_value() {
    local state_file="$1"
    local key="$2"

    [ -r "${state_file}" ] || return 0

    awk -F= -v key="${key}" '
        $1 == key {
            sub(/^[^=]*=/, "")
            print
            exit
        }
    ' "${state_file}"
}
