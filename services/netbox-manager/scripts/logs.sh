#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env
exec journalctl -fu "$NETBOX_SERVICE" -u "$NETBOX_RQ_SERVICE"
