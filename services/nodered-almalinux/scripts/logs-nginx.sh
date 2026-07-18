#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env
echo 'A seguir logs de acesso/erro do Nginx. Ctrl-C para sair.' >&2
exec tail --retry -n 0 -F /var/log/nginx/access.log /var/log/nginx/error.log
