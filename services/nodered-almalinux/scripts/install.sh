#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/certbot-lib.sh"

require_root
load_env
check_os

log "A instalar pacotes de base"
dnf install -y \
    ca-certificates curl openssl nginx firewalld \
    policycoreutils-python-utils httpd-tools tar gzip findutils

ensure_certbot_packages

ensure_nodejs_runtime

log "A instalar Node-RED ${NODERED_VERSION} e bcryptjs"
install_global_node_red

ensure_service_account
"${SCRIPT_DIR}/configure.sh"

cert_dir="$(nginx_cert_dir)"
if [[ ! -s "${cert_dir}/privkey.pem" || ! -s "${cert_dir}/fullchain.pem" ]]; then
    "${SCRIPT_DIR}/cert-selfsigned.sh"
else
    warn "certificado já existente; não foi substituído ($(cert_kind))."
fi

log "A activar serviços e firewall"
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
    die "a instalação terminou com falhas na validação."
fi
ok "instalação concluída: https://${FQDN}/"
