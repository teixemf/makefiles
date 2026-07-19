#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env

"${SCRIPT_DIR}/status.sh"

display_heading "🔎 Estado detalhado do systemd"
SYSTEMD_COLORS=1 systemctl --no-pager --full status \
    nodered nginx firewalld certbot-renew.timer 2>/dev/null || true
