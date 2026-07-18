#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

failures=0
check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ok "${description}"
    else
        warn "FAILED: ${description}"
        failures=$((failures + 1))
    fi
}

check "service account exists" id "${NODERED_USER}"
shell="$(getent passwd "${NODERED_USER}" | cut -d: -f7 || true)"
if [[ "${shell}" == "/sbin/nologin" || "${shell}" == "/usr/sbin/nologin" ]]; then
    ok "service account has no login shell"
else
    warn "FAILED: account shell is '${shell}'"
    failures=$((failures + 1))
fi

check "valid Nginx configuration" nginx -t
check "Node-RED service is active" systemctl is-active --quiet nodered
check "Nginx service is active" systemctl is-active --quiet nginx

if ss -lntH "( sport = :${NODERED_PORT} )" 2>/dev/null | grep -q "${NODERED_BIND}:${NODERED_PORT}"; then
    ok "Node-RED escuta em ${NODERED_BIND}:${NODERED_PORT}"
else
    warn "FAILED: Node-RED is not listening on the expected address"
    failures=$((failures + 1))
fi

if ss -lntH "( sport = :${NODERED_PORT} )" 2>/dev/null | grep -Eq '0\.0\.0\.0|\[::\]'; then
    warn "FAILED: port ${NODERED_PORT} is exposed on all interfaces"
    failures=$((failures + 1))
else
    ok "port ${NODERED_PORT} is not publicly exposed"
fi

auth_json="$(curl -fsS "http://${NODERED_BIND}:${NODERED_PORT}/auth/login" 2>/dev/null || true)"
if grep -q '"type"[[:space:]]*:[[:space:]]*"credentials"' <<<"${auth_json}"; then
    ok "adminAuth activo"
else
    warn "FAILED: /auth/login does not indicate credential authentication"
    failures=$((failures + 1))
fi

if curl -kfsS --resolve "${FQDN}:443:127.0.0.1" "https://${FQDN}/auth/login" \
    | grep -q '"credentials"'; then
    ok "HTTPS/reverse proxy funcional"
else
    warn "FAILED: local HTTPS test"
    failures=$((failures + 1))
fi

cert="$(nginx_cert_dir)/fullchain.pem"
if [[ -r "${cert}" ]]; then
    certificate_kind="$(cert_kind)"
    ok "certificado presente (${certificate_kind})"
    openssl x509 -in "${cert}" -noout -subject -issuer -dates
    if [[ "${certificate_kind}" == "letsencrypt-prod" ]]; then
        check "Certbot renewal timer is active" systemctl is-active --quiet certbot-renew.timer
        check "Certbot renewal configuration exists" \
            test -r "${CERTBOT_CONFIG_DIR}/renewal/${FQDN}.conf"
    fi
else
    warn "FAILED: certificate is missing"
    failures=$((failures + 1))
fi

if systemctl is-active --quiet firewalld; then
    services="$(firewall-cmd --list-services 2>/dev/null || true)"
    grep -qw http <<<"${services}" && grep -qw https <<<"${services}" \
        && ok "firewall allows HTTP/HTTPS" \
        || { warn "FAILED: HTTP/HTTPS are not both allowed by the firewall"; failures=$((failures + 1)); }
else
    warn "firewalld is not active"
fi

if (( failures > 0 )); then
    die "${failures} validation(s) failed."
fi
ok "all validations passed."
