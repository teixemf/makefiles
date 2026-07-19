#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

loopback_sample='LISTEN 0 511 127.0.0.1:1880 0.0.0.0:*'
loopback_endpoints="$(printf '%s\n' "${loopback_sample}" | listener_local_endpoints)"
[[ "${loopback_endpoints}" == '127.0.0.1:1880' ]] \
    || die "o endereço local do exemplo loopback não foi extraído correctamente."
if listener_has_wildcard_endpoint 1880 <<<"${loopback_endpoints}"; then
    die "o peer wildcard do exemplo loopback foi confundido com o endereço local."
fi

for wildcard_endpoint in '0.0.0.0:1880' '[::]:1880' ':::1880' '*:1880'; do
    listener_has_wildcard_endpoint 1880 <<<"${wildcard_endpoint}" \
        || die "o listener wildcard não foi detectado: ${wildcard_endpoint}"
done

ok "testes dos endereços locais passaram."
