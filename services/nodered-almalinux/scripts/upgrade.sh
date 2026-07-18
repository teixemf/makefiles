#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/certbot-lib.sh"

require_root
load_env
check_os

"${SCRIPT_DIR}/backup.sh"

log "A actualizar dependências RPM"
dnf upgrade -y \
    ca-certificates curl openssl nginx firewalld \
    policycoreutils-python-utils httpd-tools tar gzip findutils

ensure_certbot_packages
dnf upgrade -y certbot "$(certbot_plugin_package)"

ensure_nodesource_repo
dnf install -y nodejs --setopt=nodesource-nodejs.module_hotfixes=1 --allowerasing
dnf upgrade -y nodejs --setopt=nodesource-nodejs.module_hotfixes=1

log "A actualizar Node-RED e bcryptjs"
systemctl stop nodered 2>/dev/null || true
trap 'systemctl start nodered >/dev/null 2>&1 || true' ERR
npm install -g "node-red@${NODERED_VERSION}" bcryptjs@latest
npm rebuild -g node-red || warn "npm rebuild global devolveu erro."

if [[ -f "${NODERED_HOME}/package.json" ]]; then
    runuser -u "${NODERED_USER}" -- \
        env HOME="${NODERED_HOME}" npm --prefix "${NODERED_HOME}" rebuild \
        || warn "npm rebuild do userDir devolveu erro."
fi

if [[ "${UPGRADE_PALETTE_NODES}" == "true" ]]; then
    "${SCRIPT_DIR}/upgrade-nodes.sh"
fi

"${SCRIPT_DIR}/configure.sh"
nginx -t
systemctl daemon-reload
systemctl restart nodered
systemctl restart nginx

"${SCRIPT_DIR}/validate.sh"
trap - ERR
ok "upgrade concluído."
