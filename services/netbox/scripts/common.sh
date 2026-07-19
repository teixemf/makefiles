#!/usr/bin/env bash
set -Eeuo pipefail

service_dir() { cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd; }

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

first_output_line() {
  local output="$1"
  printf '%s' "${output%%$'\n'*}"
}

display_heading() {
  printf '\n\033[1;36m%s\033[0m\n' "$*"
}

display_row() {
  local icon="$1" label="$2" value="$3" colour="${4:-0;37}"
  printf '  %s  %-24s \033[%sm%s\033[0m\n' \
    "$icon" "$label" "$colour" "$value"
}

print_service_status() {
  local label="$1" unit="$2" state icon colour
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  case "$state" in
    active)
      icon='✅'
      colour='1;32'
      ;;
    activating|reloading|deactivating)
      icon='⏳'
      colour='1;33'
      ;;
    inactive)
      icon='⏸️'
      colour='0;33'
      ;;
    failed)
      icon='❌'
      colour='1;31'
      ;;
    *)
      icon='❔'
      colour='0;37'
      state="${state:-unknown}"
      ;;
  esac
  display_row "$icon" "$label" "$state" "$colour"
}

require_env() {
  local env_file=${ENV_FILE:-}
  [[ -n "$env_file" && -r "$env_file" ]] || die "ENV_FILE is missing or unreadable. Run make init."
  # shellcheck disable=SC1090
  source "$env_file"
  : "${NETBOX_DIR:?NETBOX_DIR must be set}"
  : "${NETBOX_APP:?NETBOX_APP must be set}"
  : "${NETBOX_REQUIREMENTS:?NETBOX_REQUIREMENTS must be set}"
  : "${NETBOX_SECRETS_FILE:?NETBOX_SECRETS_FILE must be set}"
  : "${NETBOX_PYTHON:?NETBOX_PYTHON must be set}"
  : "${NETBOX_PIP:?NETBOX_PIP must be set}"
  : "${NETBOX_SYSTEM_PYTHON:?NETBOX_SYSTEM_PYTHON must be set}"
  : "${NETBOX_USER:?NETBOX_USER must be set}"
  : "${NETBOX_SERVICE:?NETBOX_SERVICE must be set}"
  : "${NETBOX_RQ_SERVICE:?NETBOX_RQ_SERVICE must be set}"
}

require_installation() {
  [[ -d "$NETBOX_DIR" ]] || die "Missing NETBOX_DIR: $NETBOX_DIR"
  [[ -d "$NETBOX_APP" ]] || die "Missing NETBOX_APP: $NETBOX_APP"
  [[ -r "$NETBOX_SECRETS_FILE" ]] || die "Missing NETBOX_SECRETS_FILE: $NETBOX_SECRETS_FILE"
  [[ -x "$NETBOX_SYSTEM_PYTHON" ]] || die "Missing NETBOX_SYSTEM_PYTHON: $NETBOX_SYSTEM_PYTHON"
}

require_runtime() {
  require_installation
  [[ -x "$NETBOX_PYTHON" ]] || die "Missing NETBOX_PYTHON: $NETBOX_PYTHON"
  [[ -x "$NETBOX_PIP" ]] || die "Missing NETBOX_PIP: $NETBOX_PIP"
}

load_secrets() {
  eval "$("$(service_dir)/scripts/export_netbox_env.py" "$NETBOX_SECRETS_FILE")"
}

confirm() {
  local prompt=$1 answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Aborted."
}

stable_tags() { git -C "$NETBOX_DIR" tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$'; }

restart_services() { systemctl restart "$NETBOX_SERVICE" "$NETBOX_RQ_SERVICE"; }
