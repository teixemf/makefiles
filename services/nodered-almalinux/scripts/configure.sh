#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
ensure_service_account

command -v node >/dev/null || die "Node.js não está instalado."
command -v npm >/dev/null || die "npm não está instalado."
npm list -g node-red --depth=0 >/dev/null 2>&1 || die "Node-RED não está instalado."
npm list -g bcryptjs --depth=0 >/dev/null 2>&1 || npm install -g bcryptjs@latest

resolve_auth_material

log "A escrever ambiente protegido do Node-RED"
env_tmp="$(mktemp)"
cat > "${env_tmp}" <<EOF
NODERED_BIND=${NODERED_BIND}
NODERED_PORT=${NODERED_PORT}
NODERED_ADMIN_USER=${NODERED_ADMIN_USER}
NODERED_ADMIN_PASSWORD_HASH=${ADMIN_HASH}
NODERED_SESSION_SECONDS=${NODERED_SESSION_SECONDS}
NODE_RED_CREDENTIAL_SECRET=${CREDENTIAL_SECRET}
NODERED_HTTP_NODE_AUTH=${NODERED_HTTP_NODE_AUTH}
NODERED_HTTP_NODE_USER=${NODERED_HTTP_NODE_USER}
NODERED_HTTP_NODE_PASSWORD_HASH=${HTTP_HASH}
EOF
install_atomic "${env_tmp}" /etc/node-red/environment 0640 root "${NODERED_GROUP}"
rm -f "${env_tmp}"

log "A gerar settings.js"
settings_tmp="$(mktemp)"
cat > "${settings_tmp}" <<'EOF'
"use strict";

const required = (name) => {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
};

const settings = {
    uiHost: process.env.NODERED_BIND || "127.0.0.1",
    uiPort: Number(process.env.NODERED_PORT || "1880"),
    flowFile: "flows.json",
    credentialSecret: required("NODE_RED_CREDENTIAL_SECRET"),

    adminAuth: {
        type: "credentials",
        sessionExpiryTime: Number(process.env.NODERED_SESSION_SECONDS || "86400"),
        users: [{
            username: required("NODERED_ADMIN_USER"),
            password: required("NODERED_ADMIN_PASSWORD_HASH"),
            permissions: "*"
        }]
    },

    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: true
        }
    },

    functionExternalModules: false,
    exportGlobalContextKeys: false,
    functionGlobalContext: {}
};

if ((process.env.NODERED_HTTP_NODE_AUTH || "false") === "true") {
    settings.httpNodeAuth = {
        user: required("NODERED_HTTP_NODE_USER"),
        pass: required("NODERED_HTTP_NODE_PASSWORD_HASH")
    };
}

module.exports = settings;
EOF
install_atomic "${settings_tmp}" "${NODERED_HOME}/settings.js" 0640 "${NODERED_USER}" "${NODERED_GROUP}"
rm -f "${settings_tmp}"

if [[ ! -f "${NODERED_HOME}/package.json" ]]; then
    log "A inicializar package.json do userDir"
    runuser -u "${NODERED_USER}" -- \
        env HOME="${NODERED_HOME}" \
        bash -c 'cd -- "$1" && exec npm --prefix "$1" init -y' \
        _ "${NODERED_HOME}" >/dev/null
fi
chown -R "${NODERED_USER}:${NODERED_GROUP}" "${NODERED_HOME}"

node_bin="$(command -v node)"
npm_global_root="$(npm root -g)"
node_red_entrypoint="${npm_global_root}/node-red/red.js"
[[ -x "${node_bin}" ]] || die "the Node.js executable is not executable: ${node_bin}"
[[ -r "${node_red_entrypoint}" ]] \
    || die "the Node-RED entrypoint is missing: ${node_red_entrypoint}"
runuser -u "${NODERED_USER}" -- test -r "${node_red_entrypoint}" \
    || die "the Node-RED entrypoint is not readable by ${NODERED_USER}: ${node_red_entrypoint}"
log "A gerar unidade systemd"
service_tmp="$(mktemp)"
cat > "${service_tmp}" <<EOF
[Unit]
Description=Node-RED
Documentation=https://nodered.org/docs/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=${NODERED_USER}
Group=${NODERED_GROUP}
WorkingDirectory=${NODERED_HOME}
Environment=HOME=${NODERED_HOME}
EnvironmentFile=/etc/node-red/environment
ExecStart=${node_bin} ${node_red_entrypoint} --userDir ${NODERED_HOME} --settings ${NODERED_HOME}/settings.js
KillSignal=SIGINT
Restart=on-failure
RestartSec=10
TimeoutStopSec=30
UMask=0027
LimitNOFILE=65536

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=${NODERED_HOME}
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
EOF
install_atomic "${service_tmp}" /etc/systemd/system/nodered.service 0644 root root
rm -f "${service_tmp}"

cert_dir="$(nginx_cert_dir)"
install -d -o root -g root -m 0700 "${cert_dir}"

log "A gerar configuração Nginx"
nginx_tmp="$(mktemp)"
cat > "${nginx_tmp}" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${FQDN};
    return 301 https://${FQDN}\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${FQDN};

    ssl_certificate     ${cert_dir}/fullchain.pem;
    ssl_certificate_key ${cert_dir}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:NodeREDTLS:10m;
    ssl_session_timeout 1d;

    client_max_body_size 20m;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    location / {
        proxy_pass http://${NODERED_BIND}:${NODERED_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
    }
}
EOF
install_atomic "${nginx_tmp}" /etc/nginx/conf.d/nodered.conf 0644 root root
rm -f "${nginx_tmp}"

systemctl daemon-reload
restorecon -RF /etc/node-red "${NODERED_HOME}" /etc/nginx 2>/dev/null || true

selinux_mode="$(getenforce 2>/dev/null || true)"
case "${selinux_mode}" in
    Disabled)
        log "SELinux está desactivado; a configuração do booleano foi ignorada."
        ;;
    Enforcing|Permissive)
        if ! setsebool -P httpd_can_network_connect 1; then
            warn "não foi possível persistir httpd_can_network_connect; a instalação continua."
        fi
        ;;
    *)
        warn "não foi possível determinar o estado do SELinux; a configuração do booleano foi ignorada."
        ;;
esac

ok "configuração actualizada."
