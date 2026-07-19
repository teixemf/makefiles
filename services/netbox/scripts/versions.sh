#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"
require_env; require_runtime
git_revision="$(git -C "$NETBOX_DIR" describe --tags --always)"
python_version_output="$("$NETBOX_PYTHON" --version 2>&1)"
python_version="$(first_output_line "$python_version_output")"
version_colour='0;36'

display_heading "🧩 NetBox versions"
display_row "📦" "NetBox Git revision" "$git_revision" "$version_colour"
display_row "🐍" "Python" "$python_version" "$version_colour"
display_heading "🔌 Installed plugins"
[[ -r "$NETBOX_REQUIREMENTS" ]] || die "Missing requirements file: $NETBOX_REQUIREMENTS"
while IFS= read -r requirement; do
  package=$(sed -E 's/[<>=!~].*$//' <<<"$requirement" | xargs)
  [[ -z "$package" || "$package" == \#* ]] && continue
  version=$("$NETBOX_PIP" show "$package" 2>/dev/null | awk -F': ' '/^Version:/ {print $2}')
  display_row "•" "$package" "${version:-not installed}" "$version_colour"
done <"$NETBOX_REQUIREMENTS"
