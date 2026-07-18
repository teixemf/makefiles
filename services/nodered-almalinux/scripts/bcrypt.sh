#!/usr/bin/env bash
set -Eeuo pipefail

password=''
trap 'unset password' EXIT

[[ -r /dev/tty && -w /dev/tty ]] \
    || { echo "ERRO: este alvo precisa de um terminal interactivo." >&2; exit 1; }
command -v node >/dev/null 2>&1 \
    || { echo "ERRO: node não está instalado. Execute primeiro make install." >&2; exit 1; }

npm_root="$(npm root -g)"
[[ -r "${npm_root}/bcryptjs/package.json" ]] \
    || { echo "ERRO: bcryptjs não está instalado. Execute primeiro make install." >&2; exit 1; }

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

printf '%s' "${password}" | NODE_PATH="${npm_root}" node -e '
const fs = require("fs");
const bcrypt = require("bcryptjs");
process.stdout.write(`${bcrypt.hashSync(fs.readFileSync(0, "utf8"), 10)}\n`);
'
