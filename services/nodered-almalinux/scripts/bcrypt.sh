#!/usr/bin/env bash
set -Eeuo pipefail

password=''
trap 'unset password' EXIT

[[ -r /dev/tty && -w /dev/tty ]] \
    || { echo "ERRO: este alvo precisa de um terminal interactivo." >&2; exit 1; }

if ! command -v htpasswd >/dev/null 2>&1; then
    command -v dnf >/dev/null 2>&1 \
        || { echo "ERROR: htpasswd is missing and dnf is unavailable to install it." >&2; exit 1; }
    echo 'htpasswd is not installed; installing httpd-tools.' >&2
    if [[ ${EUID} -eq 0 ]]; then
        dnf install -y httpd-tools >/dev/null
    elif command -v sudo >/dev/null 2>&1; then
        sudo dnf install -y httpd-tools >/dev/null
    else
        echo 'ERRO: execute como root ou instale/configure sudo.' >&2
        exit 1
    fi
fi

read -r -s -p 'Password: ' password </dev/tty
printf '\n' >/dev/tty
read -r -s -p 'Repeat the password: ' confirmation </dev/tty
printf '\n' >/dev/tty

if [[ "${password}" != "${confirmation}" ]]; then
    unset confirmation
    echo 'ERROR: passwords do not match.' >&2
    exit 1
fi
unset confirmation
[[ -n "${password}" ]] || { echo 'ERROR: password cannot be empty.' >&2; exit 1; }

record="$(printf '%s\n' "${password}" | htpasswd -nB -C 10 -i nodered)"
hash="${record#*:}"
[[ "${hash}" =~ ^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$ ]] \
    || { echo 'ERROR: htpasswd did not return a valid bcrypt hash.' >&2; exit 1; }
printf '%s\n' "${hash}"
