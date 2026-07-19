#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-.env}"
[[ "${ENV_FILE}" == /* ]] || ENV_FILE="${SERVICE_DIR}/${ENV_FILE}"
EXAMPLE_FILE="${SERVICE_DIR}/.env.example"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -f "${ENV_FILE}" && -r "${ENV_FILE}" && ! -L "${ENV_FILE}" ]] \
  || die "${ENV_FILE} is missing or unreadable. Run 'make init'."
[[ -r "${EXAMPLE_FILE}" ]] || die "Missing service example: ${EXAMPLE_FILE}"
[[ "$(stat -c '%a' "${ENV_FILE}")" == 600 ]] \
  || die "${ENV_FILE} must have mode 0600."

list_keys() {
  awk '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/^export[[:space:]]+/, "", line)
      if (line !~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) next
      sub(/[[:space:]]*=.*/, "", line)
      if (!seen[line]++) print line
    }
  ' "$1"
}

duplicate_keys() {
  awk '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/^export[[:space:]]+/, "", line)
      if (line !~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) next
      sub(/[[:space:]]*=.*/, "", line)
      if (++seen[line] == 2) print line
    }
  ' "$1"
}

for file in "${ENV_FILE}" "${EXAMPLE_FILE}"; do
  duplicate="$(duplicate_keys "${file}")"
  [[ -z "${duplicate}" ]] \
    || die "duplicate active assignment(s) in ${file}: ${duplicate//$'\n'/, }"
done

declare -A existing_keys=() example_keys=()
while IFS= read -r key; do
  [[ -n "${key}" ]] && existing_keys["${key}"]=1
done < <(list_keys "${ENV_FILE}")
while IFS= read -r key; do
  [[ -n "${key}" ]] && example_keys["${key}"]=1
done < <(list_keys "${EXAMPLE_FILE}")

env_dir="$(dirname -- "${ENV_FILE}")"
missing_file="$(mktemp "${env_dir}/.sync-env.XXXXXX")"
tmp_file=""
cleanup() {
  [[ -z "${tmp_file}" || ! -e "${tmp_file}" ]] || rm -f -- "${tmp_file}"
  [[ -e "${missing_file}" ]] && rm -f -- "${missing_file}"
}
trap cleanup EXIT

declare -a added_keys=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  key=""
  if [[ "${line}" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*= ]]; then
    key="${BASH_REMATCH[2]}"
  fi
  [[ -n "${key}" ]] || continue
  if [[ -z "${existing_keys[${key}]+present}" ]]; then
    printf '%s\n' "${line}" >> "${missing_file}"
    added_keys+=("${key}")
  fi
done < "${EXAMPLE_FILE}"

if ((${#added_keys[@]} > 0)); then
  tmp_file="$(mktemp "${env_dir}/.sync-env.XXXXXX")"
  cp -- "${ENV_FILE}" "${tmp_file}"
  if [[ -s "${ENV_FILE}" && "$(tail -c 1 "${ENV_FILE}")" != $'\n' ]]; then
    printf '\n' >> "${tmp_file}"
  fi
  cat "${missing_file}" >> "${tmp_file}"
  chmod 600 "${tmp_file}"

  backup_file="$(mktemp "${ENV_FILE}.bak.XXXXXX")"
  cp -- "${ENV_FILE}" "${backup_file}"
  chmod 600 "${backup_file}"
  mv -f -- "${tmp_file}" "${ENV_FILE}"
  tmp_file=""

  printf 'Added keys:\n'
  printf '  %s\n' "${added_keys[@]}"
  printf 'Backup created.\n'
else
  printf 'No missing keys; environment file was not changed.\n'
fi

declare -a obsolete_keys=()
for key in "${!existing_keys[@]}"; do
  [[ -n "${example_keys[${key}]+present}" ]] || obsolete_keys+=("${key}")
done
if ((${#obsolete_keys[@]} > 0)); then
  printf 'Potentially obsolete local keys:\n'
  printf '  %s\n' "${obsolete_keys[@]}" | sort
fi
