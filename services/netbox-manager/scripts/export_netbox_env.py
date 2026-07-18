#!/usr/bin/env python3
from __future__ import annotations
import re, shlex, sys
from pathlib import Path
KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: export_netbox_env.py /path/to/secrets.env", file=sys.stderr); return 2
    try: lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
    except OSError as exc: print(f"Failed to read secrets file: {exc}", file=sys.stderr); return 1
    for lineno, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"): continue
        if line.startswith("export "): line = line[7:].lstrip()
        if "=" not in line: print(f"Malformed env line {lineno}", file=sys.stderr); return 1
        key, value = (part.strip() for part in line.split("=", 1))
        if not KEY_RE.match(key): print(f"Invalid env key on line {lineno}", file=sys.stderr); return 1
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}: value = value[1:-1]
        print(f"export {key}={shlex.quote(value)}")
    return 0
if __name__ == "__main__": raise SystemExit(main())
