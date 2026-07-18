#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/acme-lib.sh"

require_root
load_env
issue_dns_cert staging
ok "certificado Let's Encrypt STAGING instalado. Não é confiável para browsers."
