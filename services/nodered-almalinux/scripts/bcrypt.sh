#!/usr/bin/env bash
set -Eeuo pipefail

password=''
trap 'unset password' EXIT

[[ -r /dev/tty && -w /dev/tty ]] \
    || { echo "ERRO: este alvo precisa de um terminal interactivo." >&2; exit 1; }

if ! command -v htpasswd >/dev/null 2>&1; then
    command -v dnf >/dev/null 2>&1 \
        || { echo "ERRO: falta htpasswd e dnf não está disponível para o instalar." >&2; exit 1; }
    echo 'htpasswd não está instalado; a instalar httpd-tools.' >&2
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
read -r -s -p 'Repita a password: ' confirmation </dev/tty
printf '\n' >/dev/tty

if [[ "${password}" != "${confirmation}" ]]; then
    unset confirmation
    echo 'ERRO: as passwords não coincidem.' >&2
    exit 1
fi
unset confirmation
[[ -n "${password}" ]] || { echo 'ERRO: a password não pode estar vazia.' >&2; exit 1; }

record="$(printf '%s\n' "${password}" | htpasswd -nB -C 10 -i nodered)"
hash="${record#*:}"
[[ "${hash}" =~ ^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$ ]] \
    || { echo 'ERRO: htpasswd não devolveu um bcrypt válido.' >&2; exit 1; }
printf '%s\n' "${hash}"
