#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

command -v openssl >/dev/null || die "openssl is not installed."
cert_dir="$(nginx_cert_dir)"
install -d -o root -g root -m 0700 "${cert_dir}"

log "Generating a self-signed TLS certificate for ${FQDN}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
    -days "${SELF_SIGNED_DAYS}" \
    -subj "/CN=${FQDN}" \
    -addext "subjectAltName=DNS:${FQDN}" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
    -addext "extendedKeyUsage=serverAuth" \
    -keyout "${tmp_dir}/privkey.pem" \
    -out "${tmp_dir}/fullchain.pem"

install_atomic "${tmp_dir}/privkey.pem" "${cert_dir}/privkey.pem" 0600 root root
install_atomic "${tmp_dir}/fullchain.pem" "${cert_dir}/fullchain.pem" 0644 root root
restorecon -RF "${cert_dir}" 2>/dev/null || true

if systemctl is-active --quiet nginx; then
    nginx -t
    systemctl reload nginx
fi

ok "self-signed certificate installed."
