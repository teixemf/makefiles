#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
check_os
"${SCRIPT_DIR}/backup.sh"
log "Running a complete AlmaLinux upgrade"
dnf upgrade -y
"${SCRIPT_DIR}/upgrade.sh"
