#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_runtime
[[ -r "$NETBOX_REQUIREMENTS" ]] || die "Missing requirements file: $NETBOX_REQUIREMENTS"
installed=$(mktemp); outdated=$(mktemp)
trap 'rm -f "$installed" "$outdated"' EXIT
"$NETBOX_PIP" list --format=json >"$installed"
"$NETBOX_PIP" list --outdated --format=json >"$outdated"
printf 'Plugin update status:\n'
"$(dirname -- "$0")/check_plugin_updates.py" "$NETBOX_REQUIREMENTS" "$installed" "$outdated"
confirm "Proceed with plugin upgrade from $NETBOX_REQUIREMENTS?"
"$(dirname -- "$0")/backup.sh"
"$NETBOX_PIP" install --upgrade -r "$NETBOX_REQUIREMENTS"
load_secrets
export NETBOX_DB_PASSWORD NETBOX_DB_NAME NETBOX_DB_USER NETBOX_DB_HOST NETBOX_DB_PORT
cd "$NETBOX_DIR"
PYTHON="$NETBOX_PYTHON" ./upgrade.sh
restart_services
"$(dirname -- "$0")/validate.sh"
