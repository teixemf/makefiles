#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

failures=0
node_red_ready=false
check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ok "${description}"
    else
        warn "FALHOU: ${description}"
        failures=$((failures + 1))
    fi
}

check "conta de serviço existe" id "${NODERED_USER}"
shell="$(getent passwd "${NODERED_USER}" | cut -d: -f7 || true)"
if [[ "${shell}" == "/sbin/nologin" || "${shell}" == "/usr/sbin/nologin" ]]; then
    ok "conta de serviço sem login"
else
    warn "FALHOU: shell da conta é '${shell}'"
    failures=$((failures + 1))
fi

check "configuração Nginx válida" nginx -t
check "serviço Nginx activo" systemctl is-active --quiet nginx

for ((attempt = 1; attempt <= 30; attempt++)); do
    if systemctl is-active --quiet nodered \
        && ss -lntH "( sport = :${NODERED_PORT} )" 2>/dev/null \
        | grep -q "${NODERED_BIND}:${NODERED_PORT}"; then
        node_red_ready=true
        break
    fi
    sleep 1
done

if [[ "${node_red_ready}" == true ]]; then
    ok "serviço Node-RED activo"
    ok "Node-RED escuta em ${NODERED_BIND}:${NODERED_PORT}"
else
    warn "FALHOU: Node-RED não ficou operacional em 30 segundos"
    systemctl --no-pager --full status nodered || true
    journalctl -u nodered.service -b -n 100 --no-pager || true
    failures=$((failures + 1))
fi

if ss -lntH "( sport = :${NODERED_PORT} )" 2>/dev/null | grep -Eq '0\.0\.0\.0|\[::\]'; then
    warn "FALHOU: porta ${NODERED_PORT} exposta em todas as interfaces"
    failures=$((failures + 1))
else
    ok "porta ${NODERED_PORT} não exposta publicamente"
fi

if [[ "${node_red_ready}" == true ]]; then
    auth_json="$(curl -fsS "http://${NODERED_BIND}:${NODERED_PORT}/auth/login" 2>/dev/null || true)"
    if grep -q '"type"[[:space:]]*:[[:space:]]*"credentials"' <<<"${auth_json}"; then
        ok "adminAuth activo"
    else
        warn "FALHOU: /auth/login não indica autenticação por credenciais"
        failures=$((failures + 1))
    fi

    if curl -kfsS --resolve "${FQDN}:443:127.0.0.1" "https://${FQDN}/auth/login" \
        | grep -q '"credentials"'; then
        ok "HTTPS/reverse proxy funcional"
    else
        warn "FALHOU: teste HTTPS local"
        failures=$((failures + 1))
    fi
else
    warn "IGNORADO: autenticação e HTTPS porque Node-RED não está disponível"
fi

cert="$(nginx_cert_dir)/fullchain.pem"
if [[ -r "${cert}" ]]; then
    certificate_kind="$(cert_kind)"
    ok "certificado presente (${certificate_kind})"
    openssl x509 -in "${cert}" -noout -subject -issuer -dates
    if [[ "${certificate_kind}" == "letsencrypt-prod" ]]; then
        check "timer de renovação Certbot activo" systemctl is-active --quiet certbot-renew.timer
        check "configuração de renovação Certbot presente" \
            test -r "${CERTBOT_CONFIG_DIR}/renewal/${FQDN}.conf"
    fi
else
    warn "FALHOU: certificado ausente"
    failures=$((failures + 1))
fi

if systemctl is-active --quiet firewalld; then
    services="$(firewall-cmd --list-services 2>/dev/null || true)"
    grep -qw http <<<"${services}" && grep -qw https <<<"${services}" \
        && ok "firewall permite HTTP/HTTPS" \
        || { warn "FALHOU: HTTP/HTTPS não estão ambos permitidos na firewall"; failures=$((failures + 1)); }
else
    warn "firewalld não está activo"
fi

if (( failures > 0 )); then
    die "${failures} validação(ões) falharam."
fi
ok "todas as validações passaram."
