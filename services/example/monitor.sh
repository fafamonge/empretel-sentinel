#!/usr/bin/env bash

set -u

EXAMPLE_STATUS="${EXAMPLE_STATUS:-ok}"

case "${EXAMPLE_STATUS}" in
    ok)
        printf 'Example service is healthy.'
        exit 0
        ;;
    warning)
        printf 'Example service reports degraded conditions.'
        exit 1
        ;;
    critical)
        printf 'Example service is unavailable.'
        exit 2
        ;;
    *)
        printf 'Example service state is unknown: %s' "${EXAMPLE_STATUS}"
        exit 3
        ;;
esac
