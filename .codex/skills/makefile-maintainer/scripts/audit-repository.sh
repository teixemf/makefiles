#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="${1:-$(pwd)}"
services_root="${repo_root}/services"
required_files=(Makefile .env.example .gitignore README.md scripts/common.sh)
required_targets=(help init lint install configure validate status restart logs versions)
required_scripts=(install configure validate)
errors=0

report_error() {
    printf 'ERROR: %s\n' "$*" >&2
    errors=$((errors + 1))
}

[[ -d "${services_root}" ]] || {
    printf 'ERROR: services directory does not exist: %s\n' "${services_root}" >&2
    exit 1
}

found_service=false
for service_dir in "${services_root}"/*; do
    [[ -d "${service_dir}" ]] || continue
    found_service=true
    service_name="$(basename "${service_dir}")"
    makefile="${service_dir}/Makefile"

    for relative_path in "${required_files[@]}"; do
        [[ -e "${service_dir}/${relative_path}" ]] \
            || report_error "${service_name}: missing ${relative_path}"
    done

    [[ -f "${makefile}" ]] || continue

    grep -Eq '^\.DEFAULT_GOAL[[:space:]]*:=[[:space:]]*help[[:space:]]*$' "${makefile}" \
        || report_error "${service_name}: .DEFAULT_GOAL must be help"
    grep -Eq '^ENV_FILE[[:space:]]*\?=[[:space:]]*\.env[[:space:]]*$' "${makefile}" \
        || report_error "${service_name}: must define ENV_FILE ?= .env"

    help_output="$(make --no-print-directory -C "${service_dir}" help 2>&1)" \
        || report_error "${service_name}: make help failed"
    make_db="$(make --no-print-directory -C "${service_dir}" -qp 2>/dev/null || true)"
    phony_targets="$(sed -n 's/^\.PHONY:[[:space:]]*//p' <<<"${make_db}")"

    for target in "${required_targets[@]}"; do
        grep -Eq "^${target}[[:space:]]*:" "${makefile}" \
            || report_error "${service_name}: missing target ${target}"
        grep -Eq "(^|[[:space:]])${target}($|[[:space:]])" <<<"${phony_targets}" \
            || report_error "${service_name}: ${target} is not declared in .PHONY"
        grep -Fq "make ${target}" <<<"${help_output}" \
            || report_error "${service_name}: help does not document ${target}"
    done

    for script_name in "${required_scripts[@]}"; do
        script_path="${service_dir}/scripts/${script_name}.sh"
        [[ -f "${script_path}" ]] \
            || report_error "${service_name}: missing scripts/${script_name}.sh"
    done

    if [[ -d "${service_dir}/scripts" ]]; then
        while IFS= read -r -d '' script_path; do
            bash -n "${script_path}" \
                || report_error "${service_name}: invalid syntax in ${script_path}"
            [[ -x "${script_path}" ]] \
                || report_error "${service_name}: script is not executable: ${script_path}"
        done < <(find "${service_dir}/scripts" -type f -name '*.sh' -print0)
    fi
done

[[ "${found_service}" == true ]] || report_error 'no services found'

if ((errors > 0)); then
    printf 'Audit failed with %d error(s).\n' "${errors}" >&2
    exit 1
fi

printf 'Makefile consistency validated.\n'
