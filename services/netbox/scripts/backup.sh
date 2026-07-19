#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_installation
: "${NETBOX_BACKUP_ROOT:?NETBOX_BACKUP_ROOT must be set}"
timestamp=$(date -u +%Y%m%dT%H%M%SZ); destination="$NETBOX_BACKUP_ROOT/$timestamp"
install -d -m 0700 "$destination"
trap 'printf "Backup interrupted; partial data remains in %s\n" "$destination" >&2' ERR
install -m 0600 "$NETBOX_APP/netbox/configuration.py" "$destination/configuration.py"
install -m 0600 "$NETBOX_SECRETS_FILE" "$destination/secrets.env"
[[ ! -f "$NETBOX_REQUIREMENTS" ]] || install -m 0600 "$NETBOX_REQUIREMENTS" "$destination/local_requirements.txt"
git -C "$NETBOX_DIR" rev-parse HEAD >"$destination/git-revision.txt"
load_secrets
if [[ -n ${NETBOX_DB_NAME:-} && -n ${NETBOX_DB_USER:-} && -n ${NETBOX_DB_PASSWORD:-} ]]; then
  PGPASSWORD="$NETBOX_DB_PASSWORD" pg_dump -h "${NETBOX_DB_HOST:-localhost}" -p "${NETBOX_DB_PORT:-5432}" -U "$NETBOX_DB_USER" -Fc "$NETBOX_DB_NAME" >"$destination/netbox-db.dump"
else
  die "NETBOX_DB_NAME, NETBOX_DB_USER, and NETBOX_DB_PASSWORD are required for a complete backup."
fi
chmod -R go-rwx "$destination"
find "$NETBOX_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +"${NETBOX_BACKUP_RETENTION_DAYS:-14}" -exec rm -rf -- {} +
printf 'Backup complete: %s\n' "$destination"
