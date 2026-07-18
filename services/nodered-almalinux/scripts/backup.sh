#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

install -d -o root -g root -m 0700 "${BACKUP_ROOT}"
stamp="$(date +%Y%m%d-%H%M%S)"
archive="${BACKUP_ROOT}/nodered-${stamp}.tar.gz"

paths=()
for path in \
    "${ENV_FILE}" \
    "${NODERED_HOME}" \
    /etc/node-red \
    "/etc/nginx/tls/${FQDN}" \
    /etc/nginx/conf.d/nodered.conf \
    "${CERTBOT_CONFIG_DIR}" \
    "${CERTBOT_WORK_DIR}" \
    "${CERTBOT_STAGING_CONFIG_DIR}" \
    "${CERTBOT_STAGING_WORK_DIR}" \
    "${CERTBOT_DEPLOY_HOOK}" \
    /etc/systemd/system/nodered.service \
    /etc/sysconfig/certbot
do
    [[ -e "${path}" ]] && paths+=("${path#/}")
done

if (( ${#paths[@]} == 0 )); then
    warn "there are no files to include in the backup yet."
    exit 0
fi

( cd / && tar -czf "${archive}" "${paths[@]}" )
chmod 0600 "${archive}"

find "${BACKUP_ROOT}" -maxdepth 1 -type f -name 'nodered-*.tar.gz' \
    -mtime "+${BACKUP_RETENTION_DAYS}" -delete

ok "backup created: ${archive}"
