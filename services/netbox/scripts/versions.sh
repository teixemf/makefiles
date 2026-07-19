#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_runtime
git_revision="$(git -C "$NETBOX_DIR" describe --tags --always)"
python_version="$("$NETBOX_PYTHON" --version 2>&1)"

display_heading "🧩 NetBox versions"
display_row "📦" "NetBox Git revision" "$git_revision" '1;32'
display_row "🐍" "Python" "$python_version" '0;36'
display_heading "🔌 Installed plugins"
[[ -r "$NETBOX_REQUIREMENTS" ]] || die "Missing requirements file: $NETBOX_REQUIREMENTS"
while IFS= read -r requirement; do
  package=$(sed -E 's/[<>=!~].*$//' <<<"$requirement" | xargs)
  [[ -z "$package" || "$package" == \#* ]] && continue
  version=$("$NETBOX_PIP" show "$package" 2>/dev/null | awk -F': ' '/^Version:/ {print $2}')
  display_row "•" "$package" "${version:-not installed}" '0;37'
done <"$NETBOX_REQUIREMENTS"
