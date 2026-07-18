#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
[[ -f "${NODERED_HOME}/package.json" ]] || die "${NODERED_HOME}/package.json does not exist."

"${SCRIPT_DIR}/backup.sh"
log "Upgrading additional palette nodes"
systemctl stop nodered 2>/dev/null || true
trap 'systemctl start nodered >/dev/null 2>&1 || true' ERR
runuser -u "${NODERED_USER}" -- \
    env HOME="${NODERED_HOME}" npm --prefix "${NODERED_HOME}" update --omit=dev
runuser -u "${NODERED_USER}" -- \
    env HOME="${NODERED_HOME}" npm --prefix "${NODERED_HOME}" rebuild
systemctl start nodered
trap - ERR
ok "additional nodes upgraded."
