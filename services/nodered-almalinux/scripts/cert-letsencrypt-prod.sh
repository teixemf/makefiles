#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/acme-lib.sh"

require_root
load_env
issue_dns_cert prod
install_prod_timer
ok "certificado Let's Encrypt de PRODUÇÃO instalado e renovação automática activada."
