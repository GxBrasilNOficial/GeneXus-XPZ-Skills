#!/usr/bin/env python3
"""Probe tomllib para o adaptador Codex da skill xpz-mcp-integrations-setup.

Le um arquivo TOML e devolve JSON de maquina no stdout:
  {"ok": true, "hasJev": bool, "canonicalJson": "..."}
  {"ok": false, "error": "..."}

Nao grava nada. Usa apenas a biblioteca padrao (Python 3.11+).
"""

import json
import sys
import tomllib


def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"ok": False, "error": "usage: McpTomlProbe.py <path>"}))
        return 0
    path = sys.argv[1]
    try:
        with open(path, "rb") as handle:
            data = tomllib.load(handle)
    except Exception as exc:  # noqa: BLE001 - borda de entrada externa
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=True))
        return 0

    canonical = json.dumps(
        data,
        sort_keys=True,
        ensure_ascii=True,
        default=str,
        separators=(",", ":"),
    )
    has_jev = isinstance(data.get("mcp_servers"), dict) and "jev" in data["mcp_servers"]
    print(json.dumps({"ok": True, "hasJev": has_jev, "canonicalJson": canonical}, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
