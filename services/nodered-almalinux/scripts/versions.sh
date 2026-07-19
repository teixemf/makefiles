#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env

# shellcheck disable=SC1091
source /etc/os-release

node_version="$(node --version 2>/dev/null || printf 'não instalado')"
npm_version="$(npm --version 2>/dev/null || printf 'não instalado')"
node_red_version_output="$(node-red --version 2>/dev/null || printf 'não instalado')"
node_red_version="$(first_output_line "${node_red_version_output}")"
nginx_version="$(nginx -v 2>&1 || printf 'não instalado')"
openssl_version="$(openssl version 2>/dev/null || printf 'não instalado')"
certbot_version="$(certbot --version 2>/dev/null || printf 'não instalado')"
certificate_kind="$(cert_kind)"
version_colour='0;36'

display_heading "🧩 Versões e plataforma"
display_row "💻" "Sistema operativo" "${PRETTY_NAME:-desconhecido}" '0;37'
display_row "🟢" "Node.js" "${node_version}" "${version_colour}"
display_row "📦" "npm" "${npm_version}" "${version_colour}"
display_row "🔀" "Node-RED" "${node_red_version}" "${version_colour}"
display_row "🌐" "Nginx" "${nginx_version}" "${version_colour}"
display_row "🔑" "OpenSSL" "${openssl_version}" "${version_colour}"
display_row "🔄" "Certbot" "${certbot_version}" "${version_colour}"

case "${certificate_kind}" in
    letsencrypt-prod)
        display_row "🔒" "Certificado" "${certificate_kind}" '1;32'
        ;;
    letsencrypt-staging|auto-assinado)
        display_row "🧪" "Certificado" "${certificate_kind}" '1;33'
        ;;
    ausente)
        display_row "❌" "Certificado" "${certificate_kind}" '1;31'
        ;;
    *)
        display_row "❔" "Certificado" "${certificate_kind}" '0;37'
        ;;
esac
