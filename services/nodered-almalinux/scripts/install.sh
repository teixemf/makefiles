#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/certbot-lib.sh"

require_root
load_env
check_os

log "Installing base packages"
dnf install -y \
    ca-certificates curl openssl nginx firewalld \
    policycoreutils-python-utils httpd-tools tar gzip findutils

ensure_certbot_packages

ensure_nodejs_runtime

log "Installing Node-RED ${NODERED_VERSION} and bcryptjs"
npm install -g "node-red@${NODERED_VERSION}" bcryptjs@latest

ensure_service_account
"${SCRIPT_DIR}/configure.sh"

cert_dir="$(nginx_cert_dir)"
if [[ ! -s "${cert_dir}/privkey.pem" || ! -s "${cert_dir}/fullchain.pem" ]]; then
    "${SCRIPT_DIR}/cert-selfsigned.sh"
else
    warn "certificate already exists; it was not replaced ($(cert_kind))."
fi

log "Enabling services and firewall"
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --remove-port="${NODERED_PORT}/tcp" >/dev/null 2>&1 || true
firewall-cmd --reload

nginx -t
systemctl enable --now nginx
systemctl enable --now nodered
systemctl restart nodered
systemctl reload nginx

validation_status=0
if ! "${SCRIPT_DIR}/validate.sh"; then
    validation_status=1
fi
"${SCRIPT_DIR}/status.sh"
if (( validation_status != 0 )); then
    die "installation finished with validation failures."
fi
ok "installation complete: https://${FQDN}/"
