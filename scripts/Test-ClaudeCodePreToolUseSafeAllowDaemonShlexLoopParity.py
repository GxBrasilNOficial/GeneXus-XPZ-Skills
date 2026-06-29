#!/usr/bin/env python3
# Test-ClaudeCodePreToolUseSafeAllowDaemonShlexLoopParity.py - GATE do Passo A da v1 do daemon.
# Prova que o canal LENGTH-PREFIXED do ShlexLoop persistente NAO corrompe a saida da classify vs a
# REFERENCIA in-process (a MESMA classify importada do helper). Tambem valida o handshake de versao
# (sourceSha256 reportado pelo loop == SHA256 do helper). Eh o gate de TRANSPORTE do Passo A
# (design secao 4.1/8: comparar segmentos, nao so o veredito).
#
# Sentinela de sucesso: "OK: Test-ClaudeCodePreToolUseSafeAllowDaemonShlexLoopParity.py". Exit 1 em falha.
import os
import sys
import json
import struct
import hashlib
import subprocess
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "Get-ClaudeCodeBashSafeSegments.py")
LOOP = os.path.join(HERE, "ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py")

# Corpus adversarial: happy-path + separadores + multiline + danger-char + punct + Unicode Cc/Cf + vazio.
CORPUS = [
    "git status",
    "git log | head -20",
    "cat a | xargs rm",
    "rm -rf x",
    "git log ; rm -rf x",
    "git status\ngit log",          # multiline -> defer
    "echo `whoami`",                # backtick -> danger-char
    "git log $(whoami)",            # subst -> danger-char
    "git show HEAD:path > out",     # redirecao -> punct
    "date +%Y",
    "ls",
    "git -C somerepo status",
    "git​log",                 # zero-width space -> unicode-control
    "git‮log",                 # bidi RLO -> unicode-control
    "",                             # vazio -> defer
    "FOO=bar git log",
]


def load_classify(path):
    spec = importlib.util.spec_from_file_location("ptu_ref_segments", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def read_exact(stream, n):
    buf = b""
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def read_frame(stream):
    hdr = read_exact(stream, 4)
    if hdr is None:
        return None
    (n,) = struct.unpack(">I", hdr)
    return read_exact(stream, n)


def write_frame(stream, payload):
    stream.write(struct.pack(">I", len(payload)))
    stream.write(payload)
    stream.flush()


def main():
    fails = []
    mod = load_classify(HELPER)
    classify = mod.classify
    with open(HELPER, "rb") as _f:
        expected_hash = hashlib.sha256(_f.read()).hexdigest()

    proc = subprocess.Popen([sys.executable, LOOP], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        ready = read_frame(proc.stdout)
        if ready is None:
            fails.append("frame de handshake ausente")
        else:
            rj = json.loads(ready.decode("utf-8"))
            if rj.get("status") != "ready":
                fails.append("handshake status != ready: %r" % (rj,))
            if rj.get("sourceSha256") != expected_hash:
                fails.append("sourceSha256 do loop != SHA256 do helper")

        for cmd in CORPUS:
            ref = json.dumps(classify(cmd))                      # referencia in-process (mesma classify)
            write_frame(proc.stdin, cmd.encode("utf-8"))
            resp = read_frame(proc.stdout)
            got = None if resp is None else resp.decode("utf-8")
            if got != ref:
                fails.append("cmd=%r ref=%r got=%r" % (cmd, ref, got))
    finally:
        try:
            proc.stdin.close()
        except Exception:
            pass
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()

    if fails:
        for f in fails:
            print("FAIL:", f)
        print("FAILED: %d caso(s)" % len(fails))
        sys.exit(1)
    print("OK: Test-ClaudeCodePreToolUseSafeAllowDaemonShlexLoopParity.py")


if __name__ == "__main__":
    main()
