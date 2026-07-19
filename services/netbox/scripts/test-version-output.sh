#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "$0")/common.sh"

runtime_output=$'NetBox 4.4.0\nPython 3.12.9\nLinux 6.12 x86_64'
runtime_version="$(first_output_line "$runtime_output")"

[[ "$runtime_version" == 'NetBox 4.4.0' ]] \
  || die "the NetBox version was not isolated from multiline output."
[[ "$runtime_version" != *$'\n'* ]] \
  || die "the NetBox version still contains unlabeled lines."

printf 'OK: version output regression test passed.\n'
