#!/usr/bin/env bash

set -u

provider_validate() {
    local required=(
        SMTP_HOST
        SMTP_PORT
        SMTP_FROM_ADDRESS
        SMTP_FROM
        SMTP_TO
    )
    local variable_name

    for variable_name in "${required[@]}"; do
        if [ -z "${!variable_name:-}" ]; then
            printf '%s is not configured.' "${variable_name}"
            return 1
        fi
    done

    case "${SMTP_SECURITY:-starttls}" in
        starttls|tls|none)
            ;;
        *)
            printf 'Unsupported SMTP_SECURITY: %s.' \
                "${SMTP_SECURITY}"
            return 1
            ;;
    esac

    if [ -n "${SMTP_USERNAME:-}" ] &&
       [ -z "${SMTP_PASSWORD:-}" ]; then
        printf 'SMTP_PASSWORD is required when SMTP_USERNAME is configured.'
        return 1
    fi

    local timeout_name
    local timeout_value

    for timeout_name in         SMTP_CONNECT_TIMEOUT         SMTP_TIMEOUT         SMTP_LOW_SPEED_LIMIT         SMTP_LOW_SPEED_TIME
    do
        timeout_value="${!timeout_name:-}"

        [ -n "${timeout_value}" ] || continue

        if [[ ! "${timeout_value}" =~ ^[1-9][0-9]*$ ]]; then
            printf '%s must be a positive integer.' "${timeout_name}"
            return 1
        fi
    done

    printf 'Configuration valid.'
}

smtp_url() {
    case "${SMTP_SECURITY:-starttls}" in
        tls)
            printf 'smtps://%s:%s' "${SMTP_HOST}" "${SMTP_PORT}"
            ;;
        starttls|none)
            printf 'smtp://%s:%s' "${SMTP_HOST}" "${SMTP_PORT}"
            ;;
    esac
}

provider_send() {
    local subject="$1"
    local message="$2"
    local detail_file="${3:-}"
    local boundary
    local mail_file
    local smtp_endpoint
    local recipient
    local -a curl_options
    local -a recipients

    boundary="sentinel-$(date +%s)-${RANDOM}"
    mail_file="$(mktemp /tmp/empretel-sentinel-mail.XXXXXX)"

    trap 'rm -f "${mail_file}"' RETURN

    {
        printf 'From: %s\r\n' "${SMTP_FROM}"
        printf 'To: %s\r\n' "${SMTP_TO}"
        printf 'Subject: %s\r\n' "${subject}"
        printf 'Date: %s\r\n' "$(LC_ALL=C date -R)"
        printf 'MIME-Version: 1.0\r\n'

        if [ -n "${detail_file}" ] && [ -r "${detail_file}" ]; then
            printf 'Content-Type: multipart/mixed; boundary="%s"\r\n' \
                "${boundary}"
            printf '\r\n'

            printf -- '--%s\r\n' "${boundary}"
            printf 'Content-Type: text/plain; charset=UTF-8\r\n'
            printf 'Content-Transfer-Encoding: 8bit\r\n'
            printf '\r\n'
            printf '%s\r\n' "${message}"
            printf '\r\n'

            printf -- '--%s\r\n' "${boundary}"
            printf 'Content-Type: text/plain; name="%s"\r\n' \
                "$(basename "${detail_file}")"
            printf 'Content-Disposition: attachment; filename="%s"\r\n' \
                "$(basename "${detail_file}")"
            printf 'Content-Transfer-Encoding: base64\r\n'
            printf '\r\n'
            base64 "${detail_file}"
            printf '\r\n'
            printf -- '--%s--\r\n' "${boundary}"
        else
            printf 'Content-Type: text/plain; charset=UTF-8\r\n'
            printf 'Content-Transfer-Encoding: 8bit\r\n'
            printf '\r\n'
            printf '%s\r\n' "${message}"
        fi
    } > "${mail_file}"

    smtp_endpoint="$(smtp_url)"

    curl_options=(
        --fail
        --silent
        --show-error
        --url "${smtp_endpoint}"
        --mail-from "${SMTP_FROM_ADDRESS}"
        --upload-file "${mail_file}"
        --connect-timeout "${SMTP_CONNECT_TIMEOUT:-5}"
        --max-time "${SMTP_TIMEOUT:-20}"
        --speed-limit "${SMTP_LOW_SPEED_LIMIT:-1}"
        --speed-time "${SMTP_LOW_SPEED_TIME:-10}"
    )

    if [ "${SMTP_SECURITY:-starttls}" = "starttls" ]; then
        curl_options+=(--ssl-reqd)
    fi

    if [ "${SMTP_TLS_INSECURE:-0}" = "1" ]; then
        curl_options+=(--insecure)
    fi

    if [ -n "${SMTP_USERNAME:-}" ]; then
        curl_options+=(
            --user "${SMTP_USERNAME}:${SMTP_PASSWORD}"
        )
    fi

    IFS=',' read -r -a recipients <<< "${SMTP_TO}"

    for recipient in "${recipients[@]}"; do
        recipient="${recipient#"${recipient%%[![:space:]]*}"}"
        recipient="${recipient%"${recipient##*[![:space:]]}"}"

        [ -n "${recipient}" ] || continue
        curl_options+=(--mail-rcpt "${recipient}")
    done

    curl "${curl_options[@]}" >/dev/null || return 1

    printf 'Email accepted by SMTP server.'
}
