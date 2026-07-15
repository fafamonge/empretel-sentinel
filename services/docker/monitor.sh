#!/usr/bin/env bash

set -u

DOCKER_SYSTEMD_SERVICE="${DOCKER_SYSTEMD_SERVICE:-docker}"
DOCKER_COMMAND="${DOCKER_COMMAND:-docker}"
DOCKER_REQUIRE_RUNNING_CONTAINERS="${DOCKER_REQUIRE_RUNNING_CONTAINERS:-1}"
DOCKER_EXPECTED_CONTAINERS="${DOCKER_EXPECTED_CONTAINERS:-}"
DOCKER_REQUIRE_NAT_RULES="${DOCKER_REQUIRE_NAT_RULES:-1}"
DOCKER_IPTABLES_COMMAND="${DOCKER_IPTABLES_COMMAND:-iptables}"
DOCKER_HEALTH_URL="${DOCKER_HEALTH_URL:-}"
DOCKER_HEALTH_INSECURE="${DOCKER_HEALTH_INSECURE:-0}"
DOCKER_HEALTH_CONNECT_TIMEOUT="${DOCKER_HEALTH_CONNECT_TIMEOUT:-5}"
DOCKER_HEALTH_MAX_TIME="${DOCKER_HEALTH_MAX_TIME:-10}"

trim_value() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "${value}"
}

if ! command -v systemctl >/dev/null 2>&1; then
    printf 'systemctl is not available.'
    exit 3
fi

if ! command -v "${DOCKER_COMMAND}" >/dev/null 2>&1; then
    printf 'Docker command not found: %s.' "${DOCKER_COMMAND}"
    exit 3
fi

if ! systemctl is-active --quiet "${DOCKER_SYSTEMD_SERVICE}"; then
    printf 'Docker service %s is not active.' "${DOCKER_SYSTEMD_SERVICE}"
    exit 2
fi

if ! "${DOCKER_COMMAND}" info >/dev/null 2>&1; then
    printf 'Docker daemon is active but does not respond.'
    exit 2
fi

RUNNING_COUNT="$(
    "${DOCKER_COMMAND}" ps -q 2>/dev/null |
    awk 'NF { count++ } END { print count + 0 }'
)"

if [ "${DOCKER_REQUIRE_RUNNING_CONTAINERS}" = "1" ] &&
   [ "${RUNNING_COUNT}" -eq 0 ]; then
    printf 'Docker is running, but no containers are active.'
    exit 2
fi

if [ -n "${DOCKER_EXPECTED_CONTAINERS}" ]; then
    IFS=',' read -r -a expected_containers <<< "${DOCKER_EXPECTED_CONTAINERS}"

    for container_name in "${expected_containers[@]}"; do
        container_name="$(trim_value "${container_name}")"

        [ -n "${container_name}" ] || continue

        container_running="$(
            "${DOCKER_COMMAND}" inspect \
                --format '{{.State.Running}}' \
                "${container_name}" \
                2>/dev/null
        )" || {
            printf 'Expected container does not exist: %s.' "${container_name}"
            exit 2
        }

        if [ "${container_running}" != "true" ]; then
            printf 'Expected container is not running: %s.' "${container_name}"
            exit 2
        fi
    done
fi

if [ "${DOCKER_REQUIRE_NAT_RULES}" = "1" ]; then
    if ! command -v "${DOCKER_IPTABLES_COMMAND}" >/dev/null 2>&1; then
        printf 'iptables command not found: %s.' "${DOCKER_IPTABLES_COMMAND}"
        exit 3
    fi

    docker_nat_rules="$(
        "${DOCKER_IPTABLES_COMMAND}" -t nat -S DOCKER 2>/dev/null
    )" || {
        printf 'Docker NAT chain is unavailable.'
        exit 2
    }

    if ! grep -q '^-A DOCKER ' <<< "${docker_nat_rules}"; then
        printf 'Docker NAT chain has no published-port rules.'
        exit 2
    fi
fi

if [ -n "${DOCKER_HEALTH_URL}" ]; then
    curl_options=(
        --fail
        --silent
        --show-error
        --output /dev/null
        --connect-timeout "${DOCKER_HEALTH_CONNECT_TIMEOUT}"
        --max-time "${DOCKER_HEALTH_MAX_TIME}"
    )

    if [ "${DOCKER_HEALTH_INSECURE}" = "1" ]; then
        curl_options+=(--insecure)
    fi

    if ! curl "${curl_options[@]}" "${DOCKER_HEALTH_URL}"; then
        printf 'Docker-dependent health endpoint failed: %s.' \
            "${DOCKER_HEALTH_URL}"
        exit 2
    fi
fi

printf 'Docker is healthy; %s container(s) running.' "${RUNNING_COUNT}"
exit 0
