#!/usr/bin/env python3
from __future__ import annotations
import json, re, sys
from pathlib import Path
def norm(value: str) -> str: return re.sub(r"[-_.]+", "-", value).lower()
def packages(path: Path) -> dict[str, str]: return {norm(p["name"]): p["version"] for p in json.loads(path.read_text())}
def main() -> int:
    if len(sys.argv) != 4: print("Usage: check_plugin_updates.py requirements installed outdated", file=sys.stderr); return 1
    req, installed, outdated = map(Path, sys.argv[1:]); current, latest = packages(installed), packages(outdated)
    for raw in req.read_text().splitlines():
        name = re.split(r"[<>=!~]", raw.strip(), maxsplit=1)[0].strip()
        if not name or name.startswith("#"): continue
        now, newer = current.get(norm(name)), latest.get(norm(name))
        print(f"  {name:<35} {('not installed' if now is None else now if not newer else now + ' -> ' + newer)}")
    return 0
if __name__ == "__main__": raise SystemExit(main())
