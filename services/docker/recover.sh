#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

DOCKER_SYSTEMD_SERVICE="${DOCKER_SYSTEMD_SERVICE:-docker}"
DOCKER_COMMAND="${DOCKER_COMMAND:-docker}"
DOCKER_RECOVERY_TIMEOUT="${DOCKER_RECOVERY_TIMEOUT:-60}"
DOCKER_RECOVERY_LOCK="${DOCKER_RECOVERY_LOCK:-/run/empretel-sentinel-docker-recover.lock}"

if ! command -v flock >/dev/null 2>&1; then
    printf 'flock is required for Docker recovery.'
    exit 3
fi

exec 9>"${DOCKER_RECOVERY_LOCK}"

if ! flock -n 9; then
    printf 'Another Docker recovery is already running.'
    exit 2
fi

if ! command -v systemctl >/dev/null 2>&1; then
    printf 'systemctl is not available.'
    exit 3
fi

if ! command -v "${DOCKER_COMMAND}" >/dev/null 2>&1; then
    printf 'Docker command not found: %s.' "${DOCKER_COMMAND}"
    exit 3
fi

firewall_output="$("${SCRIPT_DIR}/firewall.sh" 2>&1)"
firewall_status=$?

if [ "${firewall_status}" -ne 0 ]; then
    printf 'Docker firewall repair failed: %s' "${firewall_output}"

    if [ "${firewall_status}" -eq 3 ]; then
        exit 3
    fi

    exit 1
fi

if "${SCRIPT_DIR}/monitor.sh" >/dev/null 2>&1; then
    printf 'Docker recovered by repairing firewall rules: %s' \
        "${firewall_output}"
    exit 0
fi

if systemctl is-active --quiet "${DOCKER_SYSTEMD_SERVICE}"; then
    if ! systemctl restart "${DOCKER_SYSTEMD_SERVICE}"; then
        printf 'Failed to restart Docker service %s.' \
            "${DOCKER_SYSTEMD_SERVICE}"
        exit 1
    fi

    recovery_action="restarted"
else
    if ! systemctl start "${DOCKER_SYSTEMD_SERVICE}"; then
        printf 'Failed to start Docker service %s.' \
            "${DOCKER_SYSTEMD_SERVICE}"
        exit 1
    fi

    recovery_action="started"
fi

recovery_started_at="$(date +%s)"

while true; do
    elapsed="$(( $(date +%s) - recovery_started_at ))"

    if "${SCRIPT_DIR}/firewall.sh" >/dev/null 2>&1 &&
       "${SCRIPT_DIR}/monitor.sh" >/dev/null 2>&1
    then
        printf 'Docker %s and verified healthy after %s second(s).' \
            "${recovery_action}" \
            "${elapsed}"
        exit 0
    fi

    if [ "${elapsed}" -ge "${DOCKER_RECOVERY_TIMEOUT}" ]; then
        break
    fi

    sleep 1
done

monitor_output="$("${SCRIPT_DIR}/monitor.sh" 2>&1)"
monitor_status=$?

printf 'Docker was %s, but verification failed after %s seconds: %s' \
    "${recovery_action}" \
    "${DOCKER_RECOVERY_TIMEOUT}" \
    "${monitor_output}"

if [ "${monitor_status}" -eq 3 ]; then
    exit 3
fi

exit 1
