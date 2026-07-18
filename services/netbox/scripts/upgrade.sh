#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_runtime
git -C "$NETBOX_DIR" fetch --tags
target=${VERSION:-$(stable_tags | head -n1)}
[[ -n "$target" ]] || die "No stable NetBox tag was found."
git -C "$NETBOX_DIR" rev-parse --verify --quiet "$target^{commit}" >/dev/null || die "Version/tag not found: $target"
current=$(git -C "$NETBOX_DIR" describe --tags --abbrev=0 2>/dev/null || printf unknown)
printf 'Current version: %s\nTarget version:  %s\n' "$current" "$target"
confirm "Proceed with NetBox upgrade to $target?"
"$(dirname -- "$0")/backup.sh"
git -C "$NETBOX_DIR" checkout --detach "$target"
load_secrets
export NETBOX_DB_PASSWORD NETBOX_DB_NAME NETBOX_DB_USER NETBOX_DB_HOST NETBOX_DB_PORT
cd "$NETBOX_DIR"
PYTHON="$NETBOX_SYSTEM_PYTHON" ./upgrade.sh
restart_services
"$(dirname -- "$0")/validate.sh"
