#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env
[[ ${PLUGIN:-} =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || die "Set PLUGIN to a package name, e.g. make add-plugin PLUGIN=package-name"
install -d -m 0750 "$(dirname -- "$NETBOX_REQUIREMENTS")"
touch "$NETBOX_REQUIREMENTS"
grep -qxF "$PLUGIN" "$NETBOX_REQUIREMENTS" || printf '%s\n' "$PLUGIN" >>"$NETBOX_REQUIREMENTS"
printf 'Updated %s\n' "$NETBOX_REQUIREMENTS"
