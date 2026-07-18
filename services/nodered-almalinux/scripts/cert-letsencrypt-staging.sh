#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/certbot-lib.sh"

require_root
load_env
check_os
issue_dns_cert staging
ok "STAGING Let's Encrypt issuance validated; the certificate served by Nginx was not changed."
