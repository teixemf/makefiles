#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env

printf 'OS:          '; source /etc/os-release; printf '%s\n' "${PRETTY_NAME:-desconhecido}"
printf 'Node.js:     '; node --version 2>/dev/null || true
printf 'npm:         '; npm --version 2>/dev/null || true
printf 'Node-RED:    '; node-red --version 2>/dev/null || true
printf 'Nginx:       '; nginx -v 2>&1 || true
printf 'OpenSSL:     '; openssl version 2>/dev/null || true
printf 'Certbot:     '; certbot --version 2>/dev/null || printf 'not installed\n'
printf 'Certificado: %s\n' "$(cert_kind)"
