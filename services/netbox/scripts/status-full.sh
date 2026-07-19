#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env

"$(dirname -- "$0")/status.sh"

display_heading "🔎 Detailed systemd status"
units=("$NETBOX_SERVICE" "$NETBOX_RQ_SERVICE")
[[ -n "${NETBOX_HOUSEKEEPING_SERVICE:-}" ]] && units+=("$NETBOX_HOUSEKEEPING_SERVICE")
units+=(postgresql redis-server)
SYSTEMD_COLORS=1 systemctl --no-pager --full status "${units[@]}" 2>/dev/null || true
