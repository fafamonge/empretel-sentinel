#!/usr/bin/env bash

set -u

DOCKER_IPTABLES_COMMAND="${DOCKER_IPTABLES_COMMAND:-iptables}"
DOCKER_FIREWALL_INTERFACE_PATTERN="${DOCKER_FIREWALL_INTERFACE_PATTERN:-br+}"

if ! command -v "${DOCKER_IPTABLES_COMMAND}" >/dev/null 2>&1; then
    printf 'iptables command not found: %s.' "${DOCKER_IPTABLES_COMMAND}"
    exit 3
fi

if "${DOCKER_IPTABLES_COMMAND}" \
    -C OUTPUT \
    -o "${DOCKER_FIREWALL_INTERFACE_PATTERN}" \
    -j ACCEPT \
    >/dev/null 2>&1
then
    printf 'Docker bridge OUTPUT rule already exists.'
    exit 0
fi

if ! "${DOCKER_IPTABLES_COMMAND}" \
    -I OUTPUT 1 \
    -o "${DOCKER_FIREWALL_INTERFACE_PATTERN}" \
    -j ACCEPT
then
    printf 'Failed to add Docker bridge OUTPUT rule.'
    exit 1
fi

if ! "${DOCKER_IPTABLES_COMMAND}" \
    -C OUTPUT \
    -o "${DOCKER_FIREWALL_INTERFACE_PATTERN}" \
    -j ACCEPT \
    >/dev/null 2>&1
then
    printf 'Docker bridge OUTPUT rule could not be verified.'
    exit 1
fi

printf 'Docker bridge OUTPUT rule added successfully.'
exit 0
