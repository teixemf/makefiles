#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env

printf '%-28s %s\n' \
    "Node-RED:" "$(systemctl is-active nodered 2>/dev/null || true)" \
    "Nginx:" "$(systemctl is-active nginx 2>/dev/null || true)" \
    "Firewalld:" "$(systemctl is-active firewalld 2>/dev/null || true)" \
    "Certbot timer:" "$(systemctl is-active certbot-renew.timer 2>/dev/null || true)" \
    "Certificado:" "$(cert_kind)" \
    "URL:" "https://${FQDN}/"

systemctl --no-pager --full status nodered nginx certbot-renew.timer 2>/dev/null || true
