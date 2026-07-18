#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' 'NetBox installation is intentionally out of scope for this manager.' \
  'Point .env at an existing, supported NetBox deployment, then use make status.' >&2
exit 2
