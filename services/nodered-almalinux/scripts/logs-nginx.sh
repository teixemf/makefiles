#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env
echo 'Following Nginx access/error logs. Press Ctrl-C to exit.' >&2
exec tail --retry -n 0 -F /var/log/nginx/access.log /var/log/nginx/error.log
