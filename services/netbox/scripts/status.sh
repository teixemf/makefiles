#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env
"$(dirname -- "$0")/versions.sh"

display_heading "📊 NetBox service status"
for unit in "$NETBOX_SERVICE" "$NETBOX_RQ_SERVICE" "${NETBOX_HOUSEKEEPING_SERVICE:-}" postgresql redis-server; do
  [[ -n "$unit" ]] || continue
  print_service_status "$unit" "$unit"
done
