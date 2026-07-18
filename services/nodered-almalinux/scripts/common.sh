#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mOK:\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mAVISO:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
    [[ ${EUID} -eq 0 ]] || die "este alvo tem de ser executado como root."
}

load_env() {
    [[ -r "${ENV_FILE}" ]] || die "não é possível ler ${ENV_FILE}."
    local mode
    mode="$(stat -c '%a' "${ENV_FILE}" 2>/dev/null || true)"
    if [[ -n "${mode}" && $((8#${mode} & 077)) -ne 0 ]]; then
        warn "${ENV_FILE} é legível por grupo/outros; execute chmod 600 '${ENV_FILE}'."
    fi

    local env_source line env_status
    env_source="$(mktemp)"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" =~ ^([[:space:]]*(NODERED_ADMIN_PASSWORD_HASH|NODERED_HTTP_NODE_PASSWORD_HASH)=)(\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53})([[:space:]]*)$ ]]; then
            printf "%s'%s'%s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" >> "${env_source}"
        else
            printf '%s\n' "${line}" >> "${env_source}"
        fi
    done < "${ENV_FILE}"

    set -a
    set +e
    # shellcheck disable=SC1090
    source "${env_source}"
    env_status=$?
    set -e
    set +a
    rm -f -- "${env_source}"
    (( env_status == 0 )) || return "${env_status}"

    : "${FQDN:=}"
    : "${NODE_MAJOR:=24}"
    : "${NODERED_VERSION:=latest}"
    : "${NODERED_USER:=nodered}"
    : "${NODERED_GROUP:=nodered}"
    : "${NODERED_HOME:=/var/lib/nodered}"
    : "${NODERED_BIND:=127.0.0.1}"
    : "${NODERED_PORT:=1880}"
    : "${NODERED_SESSION_SECONDS:=86400}"
    : "${NODERED_ADMIN_USER:=admin}"
    : "${NODERED_ADMIN_PASSWORD:=}"
    : "${NODERED_ADMIN_PASSWORD_HASH:=}"
    : "${NODE_RED_CREDENTIAL_SECRET:=}"
    : "${NODERED_HTTP_NODE_AUTH:=false}"
    : "${NODERED_HTTP_NODE_USER:=api}"
    : "${NODERED_HTTP_NODE_PASSWORD:=}"
    : "${NODERED_HTTP_NODE_PASSWORD_HASH:=}"
    : "${SELF_SIGNED_DAYS:=825}"
    : "${CERTBOT_EMAIL:=}"
    : "${CERTBOT_DNS_PROVIDER:=cloudflare}"
    : "${CERTBOT_DNS_PROPAGATION_SECONDS:=120}"
    : "${CERTBOT_KEY_TYPE:=ecdsa}"
    : "${CERTBOT_ELLIPTIC_CURVE:=secp256r1}"
    : "${CERTBOT_RSA_KEY_SIZE:=3072}"
    CERTBOT_CONFIG_DIR=/etc/letsencrypt
    CERTBOT_WORK_DIR=/var/lib/letsencrypt
    CERTBOT_LOGS_DIR=/var/log/letsencrypt
    CERTBOT_STAGING_CONFIG_DIR=/etc/letsencrypt-staging
    CERTBOT_STAGING_WORK_DIR=/var/lib/letsencrypt-staging
    CERTBOT_STAGING_LOGS_DIR=/var/log/letsencrypt-staging
    : "${CERTBOT_DNS_CREDENTIALS_FILE:=${CERTBOT_CONFIG_DIR}/dns-${CERTBOT_DNS_PROVIDER}-${FQDN}.ini}"
    : "${CERTBOT_DEPLOY_HOOK:=/usr/local/libexec/nodered-certbot-deploy-${FQDN}}"
    : "${CLOUDFLARE_API_TOKEN:=}"
    export -n CLOUDFLARE_API_TOKEN
    : "${UPGRADE_PALETTE_NODES:=false}"
    : "${BACKUP_ROOT:=/var/backups/nodered}"
    : "${BACKUP_RETENTION_DAYS:=30}"
    : "${ALLOW_RHEL_COMPAT:=false}"

    export FQDN NODE_MAJOR NODERED_VERSION NODERED_USER NODERED_GROUP
    export NODERED_HOME NODERED_BIND NODERED_PORT NODERED_SESSION_SECONDS
    export NODERED_ADMIN_USER NODERED_ADMIN_PASSWORD NODERED_ADMIN_PASSWORD_HASH
    export NODE_RED_CREDENTIAL_SECRET NODERED_HTTP_NODE_AUTH
    export NODERED_HTTP_NODE_USER NODERED_HTTP_NODE_PASSWORD
    export NODERED_HTTP_NODE_PASSWORD_HASH SELF_SIGNED_DAYS
    export CERTBOT_EMAIL CERTBOT_DNS_PROVIDER CERTBOT_DNS_PROPAGATION_SECONDS
    export CERTBOT_KEY_TYPE CERTBOT_ELLIPTIC_CURVE CERTBOT_RSA_KEY_SIZE
    export CERTBOT_CONFIG_DIR CERTBOT_WORK_DIR CERTBOT_LOGS_DIR
    export CERTBOT_STAGING_CONFIG_DIR CERTBOT_STAGING_WORK_DIR
    export CERTBOT_STAGING_LOGS_DIR CERTBOT_DNS_CREDENTIALS_FILE
    export CERTBOT_DEPLOY_HOOK
    export UPGRADE_PALETTE_NODES BACKUP_ROOT BACKUP_RETENTION_DAYS
    export ALLOW_RHEL_COMPAT

    validate_env
}

validate_env() {
    [[ "${FQDN}" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]] \
        || die "FQDN inválido: '${FQDN}'."
    [[ "${NODE_MAJOR}" =~ ^[0-9]{2}$ ]] || die "NODE_MAJOR tem de ser numérico, por exemplo 24."
    [[ "${NODERED_VERSION}" =~ ^(latest|[0-9]+([.][0-9x*]+){0,2}(-[0-9A-Za-z.-]+)?)$ ]] \
        || die "NODERED_VERSION deve ser latest, 5, 5.x ou uma versão semver."
    [[ "${NODERED_USER}" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "NODERED_USER inválido."
    [[ "${NODERED_GROUP}" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "NODERED_GROUP inválido."
    [[ "${NODERED_ADMIN_USER}" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "NODERED_ADMIN_USER inválido."
    [[ "${NODERED_PORT}" =~ ^[0-9]+$ ]] && (( NODERED_PORT >= 1 && NODERED_PORT <= 65535 )) \
        || die "NODERED_PORT inválido."
    [[ "${NODERED_SESSION_SECONDS}" =~ ^[0-9]+$ ]] || die "NODERED_SESSION_SECONDS inválido."
    [[ "${SELF_SIGNED_DAYS}" =~ ^[0-9]+$ ]] || die "SELF_SIGNED_DAYS inválido."
    [[ "${CERTBOT_DNS_PROVIDER}" =~ ^[a-z0-9][a-z0-9-]*$ ]] \
        || die "CERTBOT_DNS_PROVIDER inválido."
    [[ "${CERTBOT_DNS_PROPAGATION_SECONDS}" =~ ^[0-9]+$ ]] \
        || die "CERTBOT_DNS_PROPAGATION_SECONDS inválido."
    [[ "${CERTBOT_KEY_TYPE}" =~ ^(ecdsa|rsa)$ ]] \
        || die "CERTBOT_KEY_TYPE deve ser ecdsa ou rsa."
    [[ "${CERTBOT_ELLIPTIC_CURVE}" =~ ^(secp256r1|secp384r1)$ ]] \
        || die "CERTBOT_ELLIPTIC_CURVE inválido."
    [[ "${CERTBOT_RSA_KEY_SIZE}" =~ ^(2048|3072|4096)$ ]] \
        || die "CERTBOT_RSA_KEY_SIZE inválido."
    [[ "${BACKUP_RETENTION_DAYS}" =~ ^[0-9]+$ ]] || die "BACKUP_RETENTION_DAYS inválido."
    [[ "${NODERED_BIND}" == "127.0.0.1" ]] \
        || die "por segurança, NODERED_BIND deve ser 127.0.0.1."
    [[ "${NODERED_HTTP_NODE_USER}" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "NODERED_HTTP_NODE_USER inválido."
    [[ "${NODERED_HOME}" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "NODERED_HOME tem de ser absoluto e sem espaços."
    local certbot_path
    for certbot_path in \
        "${CERTBOT_CONFIG_DIR}" "${CERTBOT_WORK_DIR}" "${CERTBOT_LOGS_DIR}" \
        "${CERTBOT_STAGING_CONFIG_DIR}" "${CERTBOT_STAGING_WORK_DIR}" \
        "${CERTBOT_STAGING_LOGS_DIR}" "${CERTBOT_DNS_CREDENTIALS_FILE}" \
        "${CERTBOT_DEPLOY_HOOK}"
    do
        [[ "${certbot_path}" =~ ^/[A-Za-z0-9._/-]+$ ]] \
            || die "os caminhos Certbot têm de ser absolutos e sem espaços."
    done
    [[ "${NODERED_HTTP_NODE_AUTH}" =~ ^(true|false)$ ]] || die "NODERED_HTTP_NODE_AUTH deve ser true ou false."
    [[ "${ALLOW_RHEL_COMPAT}" =~ ^(true|false)$ ]] || die "ALLOW_RHEL_COMPAT deve ser true ou false."
}

check_os() {
    [[ -r /etc/os-release ]] || die "não foi encontrado /etc/os-release."
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" == "almalinux" ]]; then
        return
    fi
    if [[ "${ALLOW_RHEL_COMPAT}" == "true" && "${ID_LIKE:-}" == *"rhel"* ]]; then
        warn "sistema ${ID:-desconhecido} aceite por ALLOW_RHEL_COMPAT=true."
        return
    fi
    die "este projecto destina-se a AlmaLinux. Detectado ID='${ID:-desconhecido}'."
}

backup_file() {
    local file="$1"
    if [[ -e "${file}" ]]; then
        cp -a -- "${file}" "${file}.bak.$(date +%Y%m%d%H%M%S)"
    fi
}

install_atomic() {
    local source="$1" destination="$2" mode="$3" owner="${4:-root}" group="${5:-root}"
    local dir tmp
    dir="$(dirname -- "${destination}")"
    if [[ ! -d "${dir}" ]]; then
        install -d -o "${owner}" -g "${group}" -m 0755 "${dir}"
    fi
    tmp="$(mktemp "${dir}/.$(basename "${destination}").XXXXXX")"
    cp -- "${source}" "${tmp}"
    chown "${owner}:${group}" "${tmp}"
    chmod "${mode}" "${tmp}"
    mv -f -- "${tmp}" "${destination}"
}

system_env_value() {
    local key="$1" file="/etc/node-red/environment"
    [[ -r "${file}" ]] || return 1
    sed -n "s/^${key}=//p" "${file}" | tail -n 1
}

generate_bcrypt() {
    local plaintext="$1"
    [[ -n "${plaintext}" ]] || die "não é possível gerar bcrypt de uma palavra-passe vazia."
    local npm_root
    npm_root="$(npm root -g)"
    NODE_PATH="${npm_root}" node -e '
const fs = require("fs");
const bcrypt = require("bcryptjs");
const input = fs.readFileSync(3, "utf8");
process.stdout.write(bcrypt.hashSync(input, 10));
' 3< <(printf '%s' "${plaintext}")
}

resolve_auth_material() {
    local existing_admin existing_http existing_secret

    existing_admin="$(system_env_value NODERED_ADMIN_PASSWORD_HASH || true)"
    existing_http="$(system_env_value NODERED_HTTP_NODE_PASSWORD_HASH || true)"
    existing_secret="$(system_env_value NODE_RED_CREDENTIAL_SECRET || true)"

    if [[ -n "${NODERED_ADMIN_PASSWORD_HASH}" ]]; then
        ADMIN_HASH="${NODERED_ADMIN_PASSWORD_HASH}"
    elif [[ -n "${NODERED_ADMIN_PASSWORD}" && "${NODERED_ADMIN_PASSWORD}" != "ALTERAR-ANTES-DE-INSTALAR" ]]; then
        ADMIN_HASH="$(generate_bcrypt "${NODERED_ADMIN_PASSWORD}")"
    elif [[ -n "${existing_admin}" ]]; then
        ADMIN_HASH="${existing_admin}"
    else
        die "defina NODERED_ADMIN_PASSWORD ou NODERED_ADMIN_PASSWORD_HASH no .env."
    fi
    [[ "${ADMIN_HASH}" =~ ^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$ ]] \
        || die "o hash do administrador não é um bcrypt válido de 60 caracteres."

    if [[ -n "${NODE_RED_CREDENTIAL_SECRET}" ]]; then
        CREDENTIAL_SECRET="${NODE_RED_CREDENTIAL_SECRET}"
    elif [[ -n "${existing_secret}" ]]; then
        CREDENTIAL_SECRET="${existing_secret}"
    else
        CREDENTIAL_SECRET="$(openssl rand -hex 32)"
        warn "NODE_RED_CREDENTIAL_SECRET não estava definido; foi gerado um segredo novo."
    fi
    [[ "${CREDENTIAL_SECRET}" =~ ^[A-Za-z0-9._~!@%+=:-]{16,}$ ]] \
        || die "NODE_RED_CREDENTIAL_SECRET deve ter pelo menos 16 caracteres seguros."

    HTTP_HASH=""
    if [[ "${NODERED_HTTP_NODE_AUTH}" == "true" ]]; then
        if [[ -n "${NODERED_HTTP_NODE_PASSWORD_HASH}" ]]; then
            HTTP_HASH="${NODERED_HTTP_NODE_PASSWORD_HASH}"
        elif [[ -n "${NODERED_HTTP_NODE_PASSWORD}" ]]; then
            HTTP_HASH="$(generate_bcrypt "${NODERED_HTTP_NODE_PASSWORD}")"
        elif [[ -n "${existing_http}" ]]; then
            HTTP_HASH="${existing_http}"
        else
            die "NODERED_HTTP_NODE_AUTH=true requer password ou hash HTTP."
        fi
        [[ "${HTTP_HASH}" =~ ^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$ ]] \
            || die "o hash HTTP não é um bcrypt válido de 60 caracteres."
    fi

    export ADMIN_HASH CREDENTIAL_SECRET HTTP_HASH
}

ensure_service_account() {
    if ! getent group "${NODERED_GROUP}" >/dev/null; then
        groupadd --system "${NODERED_GROUP}"
    fi

    if id "${NODERED_USER}" >/dev/null 2>&1; then
        local current_home current_shell
        current_home="$(getent passwd "${NODERED_USER}" | cut -d: -f6)"
        current_shell="$(getent passwd "${NODERED_USER}" | cut -d: -f7)"
        [[ "${current_home}" == "${NODERED_HOME}" ]] \
            || die "o utilizador existente ${NODERED_USER} tem home ${current_home}, esperado ${NODERED_HOME}."
        [[ "${current_shell}" == "/sbin/nologin" || "${current_shell}" == "/usr/sbin/nologin" ]] \
            || die "o utilizador existente ${NODERED_USER} não é uma conta nologin."
    else
        useradd --system \
            --gid "${NODERED_GROUP}" \
            --home-dir "${NODERED_HOME}" \
            --create-home \
            --shell /sbin/nologin \
            --comment "Node-RED service account" \
            "${NODERED_USER}"
    fi

    install -d -o "${NODERED_USER}" -g "${NODERED_GROUP}" -m 0750 "${NODERED_HOME}"
    install -d -o root -g "${NODERED_GROUP}" -m 0750 /etc/node-red
}

ensure_nodesource_repo() {
    local repo_rpm
    repo_rpm="https://rpm.nodesource.com/pub_${NODE_MAJOR}.x/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm"
    log "A configurar repositório NodeSource para Node.js ${NODE_MAJOR}.x"
    if rpm -q nodesource-release-nodistro >/dev/null 2>&1; then
        dnf remove -y nodesource-release-nodistro
    fi
    dnf install -y "${repo_rpm}"
}

nginx_cert_dir() {
    printf '/etc/nginx/tls/%s' "${FQDN}"
}

cert_kind() {
    local cert="$(nginx_cert_dir)/fullchain.pem"
    [[ -r "${cert}" ]] || { printf 'ausente'; return; }

    local subject issuer
    subject="$(openssl x509 -in "${cert}" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject=//')"
    issuer="$(openssl x509 -in "${cert}" -noout -issuer -nameopt RFC2253 2>/dev/null | sed 's/^issuer=//')"

    if [[ "${issuer}" == *"Fake LE"* || "${issuer}" == *"STAGING"* ]]; then
        printf 'letsencrypt-staging'
    elif [[ "${issuer}" == *"Let's Encrypt"* || "${issuer}" == *"ISRG"* ]]; then
        printf 'letsencrypt-prod'
    elif [[ -n "${subject}" && "${subject}" == "${issuer}" ]]; then
        printf 'auto-assinado'
    else
        printf 'outro'
    fi
}
