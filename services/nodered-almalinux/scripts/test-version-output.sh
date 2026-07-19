#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

node_red_output=$'Node-RED v5.0.1\nNode.js v22.23.1\nLinux 7.0.14-5-pve x64 LE'
node_red_version="$(first_output_line "${node_red_output}")"

[[ "${node_red_version}" == 'Node-RED v5.0.1' ]] \
    || die "a versão Node-RED não foi isolada da saída multilinha."
[[ "${node_red_version}" != *$'\n'* ]] \
    || die "a versão Node-RED ainda contém linhas sem label."

ok "teste da saída de versão do Node-RED passou."
