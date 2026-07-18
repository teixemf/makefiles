#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/certbot-lib.sh"

require_root
load_env
check_os
issue_dns_cert prod
enable_certbot_timer
ok "Production Let's Encrypt certificate installed and automatic renewal enabled."
