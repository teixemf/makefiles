#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env
for unit in "$NETBOX_SERVICE" "$NETBOX_RQ_SERVICE" "${NETBOX_HOUSEKEEPING_SERVICE:-}" postgresql redis-server; do
  [[ -n "$unit" ]] || continue
  if systemctl is-active --quiet "$unit"; then printf '  %s: active\n' "$unit"; else printf '  %s: inactive or unavailable\n' "$unit"; fi
done
