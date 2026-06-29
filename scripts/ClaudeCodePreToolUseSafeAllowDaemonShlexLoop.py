#!/usr/bin/env python3
# ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py - loop persistente do tokenizador (Passo A da v1
# do daemon do hook PreToolUse do CLAUDE CODE). Parte da solucao especifica do Claude Code.
#
# IMPORTA classify de Get-ClaudeCodeBashSafeSegments.py (FONTE UNICA da tokenizacao; NAO reimplementa
# a logica nem as constantes shlex). Protocolo length-prefixed (4 bytes big-endian + payload UTF-8)
# nos DOIS sentidos, para preservar identidade de comportamento com o one-shot: o comando cru chega
# INTEIRO (inclusive '\n'), entao o ramo multiline da classify dispara igual ao one-shot.
#
# Na subida emite UM frame de handshake {"status":"ready","sourceSha256":...} com o marcador de versao
# exportado por classify, para o daemon (Passo C) validar a staleness do .py apos um respawn.
#
# NAO eh o decisor: so tokeniza (classify). O veredito de verbo/flag fica no PowerShell
# (ClaudeCodePreToolUseSafeAllowSupport.ps1 :: Get-PtuSegmentsVerdict).
import sys
import os
import json
import struct
import importlib.util

_MAX_FRAME = 65536  # 64 KB (cap do protocolo, design secao 7)
_HELPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Get-ClaudeCodeBashSafeSegments.py")


def _load_classifier(path):
    # Carrega o helper por CAMINHO (o nome do arquivo tem hifens, invalido para import normal).
    spec = importlib.util.spec_from_file_location("ptu_safe_allow_segments", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read_frame(stream):
    header = stream.read(4)
    if not header or len(header) < 4:
        return None  # EOF / stream fechado -> shutdown
    (n,) = struct.unpack(">I", header)
    if n > _MAX_FRAME:
        return None
    payload = b""
    while len(payload) < n:
        chunk = stream.read(n - len(payload))
        if not chunk:
            return None
        payload += chunk
    return payload


def _write_frame(stream, payload_bytes):
    stream.write(struct.pack(">I", len(payload_bytes)))
    stream.write(payload_bytes)
    stream.flush()


def main():
    sin = sys.stdin.buffer
    sout = sys.stdout.buffer
    mod = _load_classifier(_HELPER)
    classify = mod.classify
    marker = getattr(mod, "CLASSIFY_SOURCE_SHA256", None)
    _write_frame(sout, json.dumps({"status": "ready", "sourceSha256": marker}).encode("utf-8"))
    while True:
        req = _read_frame(sin)
        if req is None:
            break
        try:
            cmd = req.decode("utf-8")
            result = classify(cmd)
        except Exception:
            # Qualquer erro de loop -> defer (fail-closed); o PowerShell tambem trata isso.
            result = {"status": "defer", "reason": "loop-error"}
        _write_frame(sout, json.dumps(result).encode("utf-8"))


if __name__ == "__main__":
    main()
