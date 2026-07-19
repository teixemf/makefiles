#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env

print_service_status() {
    local label="$1" unit="$2" state icon colour
    state="$(systemctl is-active "${unit}" 2>/dev/null || true)"
    case "${state}" in
        active)
            icon='✅'
            colour='1;32'
            ;;
        activating|reloading|deactivating)
            icon='⏳'
            colour='1;33'
            ;;
        inactive)
            icon='⏸️'
            colour='0;33'
            ;;
        failed)
            icon='❌'
            colour='1;31'
            ;;
        *)
            icon='❔'
            colour='0;37'
            state="${state:-desconhecido}"
            ;;
    esac
    display_row "${icon}" "${label}" "${state}" "${colour}"
}

"${SCRIPT_DIR}/versions.sh"

display_heading "📊 Estado resumido dos serviços"
print_service_status "Node-RED" nodered
print_service_status "Nginx" nginx
print_service_status "Firewalld" firewalld
print_service_status "Certbot timer" certbot-renew.timer
display_row "🔗" "URL" "https://${FQDN}/" '1;34'
