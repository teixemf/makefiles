#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env
restart_services
printf 'Restarted %s and %s.\n' "$NETBOX_SERVICE" "$NETBOX_RQ_SERVICE"
