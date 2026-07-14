#!/usr/bin/env bash

set -u

EXAMPLE_RECOVERY_RESULT="${EXAMPLE_RECOVERY_RESULT:-success}"

case "${EXAMPLE_RECOVERY_RESULT}" in
    success)
        printf 'Example service recovered successfully.'
        exit 0
        ;;
    failed)
        printf 'Example service recovery failed.'
        exit 1
        ;;
    not_applicable)
        printf 'Example service does not require recovery.'
        exit 2
        ;;
    *)
        printf 'Example recovery result is unknown: %s' \
            "${EXAMPLE_RECOVERY_RESULT}"
        exit 3
        ;;
esac
