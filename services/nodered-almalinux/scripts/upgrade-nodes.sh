#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
[[ -f "${NODERED_HOME}/package.json" ]] || die "não existe ${NODERED_HOME}/package.json."

"${SCRIPT_DIR}/backup.sh"
log "A actualizar nós adicionais da palette"
systemctl stop nodered 2>/dev/null || true
trap 'systemctl start nodered >/dev/null 2>&1 || true' ERR
runuser -u "${NODERED_USER}" -- \
    env HOME="${NODERED_HOME}" npm --prefix "${NODERED_HOME}" update --omit=dev
runuser -u "${NODERED_USER}" -- \
    env HOME="${NODERED_HOME}" npm --prefix "${NODERED_HOME}" rebuild
systemctl start nodered
trap - ERR
ok "nós adicionais actualizados."
