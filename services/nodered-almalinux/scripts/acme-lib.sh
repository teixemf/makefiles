#!/usr/bin/env bash
set -Eeuo pipefail

checkout_acme_ref() {
    git -C "${ACME_HOME}" fetch --tags --prune origin
    if git -C "${ACME_HOME}" show-ref --verify --quiet "refs/remotes/origin/${ACME_GIT_REF}"; then
        git -C "${ACME_HOME}" checkout -q -B "${ACME_GIT_REF}" "origin/${ACME_GIT_REF}"
    else
        git -C "${ACME_HOME}" checkout -q --detach "${ACME_GIT_REF}"
    fi
}

ensure_acme_checkout() {
    command -v git >/dev/null || die "git não está instalado."
    if [[ -d "${ACME_HOME}/.git" ]]; then
        log "A actualizar acme.sh"
        checkout_acme_ref
    elif [[ -e "${ACME_HOME}" ]]; then
        die "${ACME_HOME} já existe mas não é um checkout Git do acme.sh."
    else
        log "A instalar acme.sh em ${ACME_HOME}"
        install -d -o root -g root -m 0700 "$(dirname "${ACME_HOME}")"
        git clone --depth 1 --branch "${ACME_GIT_REF}" \
            https://github.com/acmesh-official/acme.sh.git "${ACME_HOME}"
    fi
    chmod 0700 "${ACME_HOME}"
    chmod 0755 "${ACME_HOME}/acme.sh"
}

acme_paths() {
    ACME_ENV_NAME="$1"
    ACME_CONFIG_HOME="${ACME_CONFIG_ROOT}/${ACME_ENV_NAME}"
    ACME_CERT_HOME="${ACME_CERT_ROOT}/${ACME_ENV_NAME}"
    install -d -o root -g root -m 0700 \
        "${ACME_CONFIG_HOME}" "${ACME_CERT_HOME}" "$(nginx_cert_dir)"
    export ACME_ENV_NAME ACME_CONFIG_HOME ACME_CERT_HOME
}

issue_dns_cert() {
    local environment="$1"
    [[ -n "${ACME_EMAIL}" && "${ACME_EMAIL}" != "admin@example.com" ]] \
        || die "defina ACME_EMAIL no .env."
    [[ "${ACME_DNS_PROVIDER}" =~ ^dns_[A-Za-z0-9_]+$ ]] \
        || die "ACME_DNS_PROVIDER inválido."

    ensure_acme_checkout
    acme_paths "${environment}"

    local -a server_args ecc_args
    if [[ "${environment}" == "staging" ]]; then
        server_args=(--server letsencrypt --staging)
    else
        server_args=(--server letsencrypt)
    fi

    ecc_args=()
    acme_is_ecc && ecc_args=(--ecc)

    log "A emitir certificado ${environment} por DNS-01 (${ACME_DNS_PROVIDER})"
    acme_cmd "${ACME_CONFIG_HOME}" "${ACME_CERT_HOME}" \
        --register-account -m "${ACME_EMAIL}" "${server_args[@]}"

    acme_cmd "${ACME_CONFIG_HOME}" "${ACME_CERT_HOME}" \
        --issue \
        "${server_args[@]}" \
        --dns "${ACME_DNS_PROVIDER}" \
        --dnssleep "${ACME_DNS_SLEEP}" \
        --keylength "${ACME_KEY_LENGTH}" \
        -d "${FQDN}" \
        --force

    local cert_dir
    cert_dir="$(nginx_cert_dir)"
    install -o root -g root -m 0600 /dev/null "${cert_dir}/privkey.pem"
    install -o root -g root -m 0644 /dev/null "${cert_dir}/fullchain.pem"

    acme_cmd "${ACME_CONFIG_HOME}" "${ACME_CERT_HOME}" \
        --install-cert \
        "${ecc_args[@]}" \
        -d "${FQDN}" \
        --key-file "${cert_dir}/privkey.pem" \
        --fullchain-file "${cert_dir}/fullchain.pem" \
        --reloadcmd "systemctl reload nginx"

    restorecon -RF "${cert_dir}" 2>/dev/null || true
    nginx -t
    systemctl reload nginx
}

install_prod_timer() {
    cat > /etc/systemd/system/acme-nodered-renew.service <<EOF
[Unit]
Description=Renovar certificado ACME do Node-RED
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
UMask=0077
ExecStart=${ACME_HOME}/acme.sh --cron --home ${ACME_HOME} --config-home ${ACME_CONFIG_ROOT}/prod --cert-home ${ACME_CERT_ROOT}/prod
EOF

    cat > /etc/systemd/system/acme-nodered-renew.timer <<'EOF'
[Unit]
Description=Verificação diária de renovação ACME do Node-RED

[Timer]
OnCalendar=daily
RandomizedDelaySec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    chmod 0644 /etc/systemd/system/acme-nodered-renew.service \
        /etc/systemd/system/acme-nodered-renew.timer
    systemctl daemon-reload
    systemctl enable --now acme-nodered-renew.timer
}
