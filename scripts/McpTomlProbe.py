#!/usr/bin/env python3
"""Probe tomllib para o adaptador Codex da skill xpz-mcp-integrations-setup.

Le o TOML pela entrada padrao (UTF-8, sem argumentos) e devolve JSON de
maquina no stdout:
  {"ok": true, "hasJev": bool, "canonicalJson": "..."}
  {"ok": false, "error": "..."}

Nao grava nada e nao cria arquivo temporario: o conteudo nunca vai para disco.
Usa apenas a biblioteca padrao (Python 3.11+).
"""

import json
import sys
import tomllib


def main() -> int:
    if len(sys.argv) != 1:
        print(json.dumps({"ok": False, "error": "usage: McpTomlProbe.py (TOML via stdin, UTF-8)"}))
        return 0
    try:
        # tomllib.load(bytes) decodifica como UTF-8; mantemos a mesma semantica de erro.
        data = tomllib.loads(sys.stdin.buffer.read().decode("utf-8"))
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
