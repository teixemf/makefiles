#!/usr/bin/env bash
set -Eeuo pipefail

certbot_plugin_package() {
    printf 'python3-certbot-dns-%s' "${CERTBOT_DNS_PROVIDER}"
}

ensure_certbot_packages() {
    log "Installing Certbot and the ${CERTBOT_DNS_PROVIDER} DNS plugin"
    dnf install -y epel-release
    dnf install -y certbot "$(certbot_plugin_package)"
}

validate_credentials_permissions() {
    local credentials_file="$1" mode
    [[ -r "${credentials_file}" ]] \
        || die "cannot read ${credentials_file}."
    mode="$(stat -c '%a' "${credentials_file}")"
    (( (8#${mode} & 077) == 0 )) \
        || die "${credentials_file} deve ter modo 0600."
}

prepare_dns_credentials() {
    local credentials_dir credentials_tmp
    credentials_dir="$(dirname -- "${CERTBOT_DNS_CREDENTIALS_FILE}")"

    if [[ "${CERTBOT_DNS_PROVIDER}" == "cloudflare" ]]; then
        if [[ -n "${CLOUDFLARE_API_TOKEN}" ]]; then
            [[ "${CLOUDFLARE_API_TOKEN}" =~ ^[^[:space:]]+$ ]] \
                || die "CLOUDFLARE_API_TOKEN cannot contain spaces or newlines."
            install -d -o root -g root -m 0700 "${credentials_dir}"
            credentials_tmp="$(mktemp "${credentials_dir}/.dns-cloudflare.XXXXXX")"
            printf 'dns_cloudflare_api_token = %s\n' "${CLOUDFLARE_API_TOKEN}" \
                > "${credentials_tmp}"
            chown root:root "${credentials_tmp}"
            chmod 0600 "${credentials_tmp}"
            mv -f -- "${credentials_tmp}" "${CERTBOT_DNS_CREDENTIALS_FILE}"
        elif [[ ! -r "${CERTBOT_DNS_CREDENTIALS_FILE}" ]]; then
            die "defina CLOUDFLARE_API_TOKEN no .env ou crie ${CERTBOT_DNS_CREDENTIALS_FILE}."
        fi
    elif [[ ! -r "${CERTBOT_DNS_CREDENTIALS_FILE}" ]]; then
        die "crie ${CERTBOT_DNS_CREDENTIALS_FILE} no formato exigido pelo plugin dns-${CERTBOT_DNS_PROVIDER}."
    fi

    validate_credentials_permissions "${CERTBOT_DNS_CREDENTIALS_FILE}"
    unset CLOUDFLARE_API_TOKEN
}

certbot_key_args() {
    if [[ "${CERTBOT_KEY_TYPE}" == "ecdsa" ]]; then
        printf '%s\n' --key-type ecdsa --elliptic-curve "${CERTBOT_ELLIPTIC_CURVE}"
    else
        printf '%s\n' --key-type rsa --rsa-key-size "${CERTBOT_RSA_KEY_SIZE}"
    fi
}

install_deploy_hook() {
    local cert_dir hook_dir hook_tmp
    cert_dir="$(nginx_cert_dir)"
    hook_dir="$(dirname -- "${CERTBOT_DEPLOY_HOOK}")"
    install -d -o root -g root -m 0755 "${hook_dir}"
    hook_tmp="$(mktemp)"
    cat > "${hook_tmp}" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
lineage="\${RENEWED_LINEAGE:?RENEWED_LINEAGE was not set by Certbot}"
[[ -r "\${lineage}/privkey.pem" && -r "\${lineage}/fullchain.pem" ]]
install -d -o root -g root -m 0700 "${cert_dir}"
key_tmp="\$(mktemp "${cert_dir}/.privkey.XXXXXX")"
chain_tmp="\$(mktemp "${cert_dir}/.fullchain.XXXXXX")"
trap 'rm -f -- "\${key_tmp}" "\${chain_tmp}"' EXIT
install -o root -g root -m 0600 "\${lineage}/privkey.pem" "\${key_tmp}"
install -o root -g root -m 0644 "\${lineage}/fullchain.pem" "\${chain_tmp}"
mv -f -- "\${key_tmp}" "${cert_dir}/privkey.pem"
mv -f -- "\${chain_tmp}" "${cert_dir}/fullchain.pem"
trap - EXIT
restorecon -RF "${cert_dir}" 2>/dev/null || true
nginx -t
systemctl reload nginx
EOF
    install_atomic "${hook_tmp}" "${CERTBOT_DEPLOY_HOOK}" 0750 root root
    rm -f -- "${hook_tmp}"
}

deploy_cert_lineage() {
    local lineage="$1" cert_dir
    [[ -r "${lineage}/privkey.pem" && -r "${lineage}/fullchain.pem" ]] \
        || die "Certbot did not create a usable lineage at ${lineage}."
    cert_dir="$(nginx_cert_dir)"
    install -d -o root -g root -m 0700 "${cert_dir}"
    install_atomic "${lineage}/privkey.pem" "${cert_dir}/privkey.pem" 0600 root root
    install_atomic "${lineage}/fullchain.pem" "${cert_dir}/fullchain.pem" 0644 root root
    restorecon -RF "${cert_dir}" 2>/dev/null || true
    nginx -t
    systemctl reload nginx
}

issue_dns_cert() {
    local environment="$1" config_dir work_dir logs_dir
    local plugin_flag credentials_flag propagation_flag
    local -a certbot_args key_args

    [[ -n "${CERTBOT_EMAIL}" && "${CERTBOT_EMAIL}" != "admin@example.com" ]] \
        || die "defina CERTBOT_EMAIL no .env."
    if ! rpm -q certbot "$(certbot_plugin_package)" >/dev/null 2>&1; then
        ensure_certbot_packages
    fi
    prepare_dns_credentials

    plugin_flag="--dns-${CERTBOT_DNS_PROVIDER}"
    credentials_flag="--dns-${CERTBOT_DNS_PROVIDER}-credentials"
    propagation_flag="--dns-${CERTBOT_DNS_PROVIDER}-propagation-seconds"

    if [[ "${environment}" == "staging" ]]; then
        config_dir="${CERTBOT_STAGING_CONFIG_DIR}"
        work_dir="${CERTBOT_STAGING_WORK_DIR}"
        logs_dir="${CERTBOT_STAGING_LOGS_DIR}"
    else
        config_dir="${CERTBOT_CONFIG_DIR}"
        work_dir="${CERTBOT_WORK_DIR}"
        logs_dir="${CERTBOT_LOGS_DIR}"
        install_deploy_hook
    fi

    install -d -o root -g root -m 0700 "${config_dir}" "${work_dir}" "${logs_dir}"
    mapfile -t key_args < <(certbot_key_args)
    certbot_args=(
        certonly --non-interactive --agree-tos --email "${CERTBOT_EMAIL}"
        --config-dir "${config_dir}"
        --work-dir "${work_dir}"
        --logs-dir "${logs_dir}"
        "${plugin_flag}"
        "${credentials_flag}" "${CERTBOT_DNS_CREDENTIALS_FILE}"
        "${propagation_flag}" "${CERTBOT_DNS_PROPAGATION_SECONDS}"
        --cert-name "${FQDN}"
        -d "${FQDN}"
        "${key_args[@]}"
    )

    if [[ "${environment}" == "staging" ]]; then
        log "Testing Certbot DNS-01 staging issuance (${CERTBOT_DNS_PROVIDER})"
        certbot "${certbot_args[@]}" --staging --force-renewal
    else
        log "Issuing a production Certbot DNS-01 certificate (${CERTBOT_DNS_PROVIDER})"
        certbot "${certbot_args[@]}" \
            --keep-until-expiring \
            --deploy-hook "${CERTBOT_DEPLOY_HOOK}"
        deploy_cert_lineage "${CERTBOT_CONFIG_DIR}/live/${FQDN}"
    fi
}

enable_certbot_timer() {
    if systemctl list-unit-files acme-nodered-renew.timer >/dev/null 2>&1; then
        systemctl disable --now acme-nodered-renew.timer >/dev/null 2>&1 || true
    fi
    systemctl enable --now certbot-renew.timer
}
