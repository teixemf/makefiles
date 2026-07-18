#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_runtime
printf 'NetBox Git revision: '; git -C "$NETBOX_DIR" describe --tags --always
printf 'Python: '; "$NETBOX_PYTHON" --version
printf 'Installed plugins:\n'
[[ -r "$NETBOX_REQUIREMENTS" ]] || die "Missing requirements file: $NETBOX_REQUIREMENTS"
while IFS= read -r requirement; do
  package=$(sed -E 's/[<>=!~].*$//' <<<"$requirement" | xargs)
  [[ -z "$package" || "$package" == \#* ]] && continue
  version=$("$NETBOX_PIP" show "$package" 2>/dev/null | awk -F': ' '/^Version:/ {print $2}')
  printf '  %s: %s\n' "$package" "${version:-not installed}"
done <"$NETBOX_REQUIREMENTS"
