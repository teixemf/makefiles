#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_installation
git -C "$NETBOX_DIR" fetch --tags
case ${1:?operation required} in
  check-netbox-updates)
    current=$(git -C "$NETBOX_DIR" describe --tags --abbrev=0 2>/dev/null || printf unknown)
    latest=$(stable_tags | head -n1)
    printf 'Current NetBox version: %s\nLatest stable NetBox tag: %s\n' "$current" "$latest"
    [[ "$current" == "$latest" ]] && printf 'Status: up to date\n' || printf 'Status: update available\n'
    ;;
  list-netbox-tags) printf 'Latest stable NetBox tags:\n'; stable_tags | head -n20 ;;
  *) die "Unknown update operation: $1" ;;
esac
