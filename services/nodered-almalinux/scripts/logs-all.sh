#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
require_root
load_env

cleanup() {
    kill "${journal_pid:-}" "${nginx_pid:-}" 2>/dev/null || true
    wait "${journal_pid:-}" "${nginx_pid:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo 'Following Node-RED and Nginx access/error logs. Press Ctrl-C to exit.' >&2
journalctl -u nodered -f -n 0 &
journal_pid=$!
tail --retry -n 0 -F /var/log/nginx/access.log /var/log/nginx/error.log &
nginx_pid=$!

wait
