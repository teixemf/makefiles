#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TEST_DIR}"' EXIT

env_file="${TEST_DIR}/custom.env"
bcrypt_line="TEST_BCRYPT='\$2b\$12\$abcdefghijklmnopqrstuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu'"
cat > "${env_file}" <<'EOF'
NETBOX_USER=custom-netbox
NETBOX_SECRETS_FILE="/private/secrets path.env"
TEST_EMPTY=
TEST_QUOTED="quoted value; keep me"
TEST_BCRYPT='$2b$12$abcdefghijklmnopqrstuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu'
TEST_PASSWORD=private-password-value
TEST_TOKEN=private-token-value
OBSOLETE_LOCAL=keep-this-value
EOF
chmod 600 "${env_file}"
original_file="${TEST_DIR}/original.env"
cp -- "${env_file}" "${original_file}"
original_line_count="$(wc -l < "${original_file}")"

output=""
if ! output="$(make --no-print-directory -C "${SERVICE_DIR}" sync-env ENV_FILE="${env_file}" 2>&1)"; then
  printf '%s\n' "${output}" >&2
  exit 1
fi
[[ "${output}" == *'NETBOX_DIR'* ]]
[[ "${output}" == *'OBSOLETE_LOCAL'* ]]
for secret in private-password-value private-token-value keep-this-value; do
  [[ "${output}" != *"${secret}"* ]]
done
grep -Fqx 'NETBOX_USER=custom-netbox' "${env_file}"
grep -Fqx 'NETBOX_SECRETS_FILE="/private/secrets path.env"' "${env_file}"
grep -Fqx "${bcrypt_line}" "${env_file}"
grep -Fqx 'TEST_PASSWORD=private-password-value' "${env_file}"
grep -Fqx 'TEST_TOKEN=private-token-value' "${env_file}"
grep -Fqx 'OBSOLETE_LOCAL=keep-this-value' "${env_file}"
[[ "$(grep -Fxc '# Paths for an existing NetBox installation. Values are interpreted as Bash.' "${env_file}")" == 1 ]]
[[ "$(grep -Fxc "# NetBox's dedicated system account and systemd units." "${env_file}")" == 1 ]]
head -n "${original_line_count}" "${env_file}" > "${TEST_DIR}/preserved-prefix.env"
cmp -s "${original_file}" "${TEST_DIR}/preserved-prefix.env"
[[ "$(stat -c '%a' "${env_file}")" == 600 ]]
[[ "$(find "${TEST_DIR}" -maxdepth 1 -name 'custom.env.bak.*' -type f | wc -l)" == 1 ]]
[[ "$(stat -c '%a' "${TEST_DIR}"/custom.env.bak.*)" == 600 ]]

before_hash="$(sha256sum "${env_file}")"
second_output="$(make --no-print-directory -C "${SERVICE_DIR}" sync-env ENV_FILE="${env_file}" 2>&1)"
after_hash="$(sha256sum "${env_file}")"
[[ "${before_hash}" == "${after_hash}" ]]
[[ "$(find "${TEST_DIR}" -maxdepth 1 -name 'custom.env.bak.*' -type f | wc -l)" == 1 ]]
[[ "${second_output}" != *'private-token-value'* ]]

duplicate_file="${TEST_DIR}/duplicate.env"
printf 'DUPLICATE=one\nDUPLICATE=two\n' > "${duplicate_file}"
chmod 600 "${duplicate_file}"
if duplicate_output="$(make --no-print-directory -C "${SERVICE_DIR}" sync-env ENV_FILE="${duplicate_file}" 2>&1)"; then
  printf 'duplicate active assignment was accepted.\n' >&2
  exit 1
fi
[[ "${duplicate_output}" == *'DUPLICATE'* ]]
[[ "${duplicate_output}" != *'one'* && "${duplicate_output}" != *'two'* ]]

printf 'OK: sync-env regression tests passed.\n'
