#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_runtime
load_secrets
cd "$NETBOX_APP"
runuser -u "$NETBOX_USER" -- "$NETBOX_PYTHON" manage.py check
