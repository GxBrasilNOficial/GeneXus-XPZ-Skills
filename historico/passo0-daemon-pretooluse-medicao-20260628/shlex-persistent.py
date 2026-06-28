#!/usr/bin/env python3
# shlex-persistent.py - PROTOTIPO DESCARTAVEL (passo 0b / gargalo B: shlex persistente).
# Mesma logica de Get-ClaudeCodeBashSafeSegments.py, mas em LOOP: le 1 comando por linha do
# stdin e emite 1 linha JSON por resposta. Valido porque multilinha sempre vira defer no fast-path.
# NAO eh codigo final: a v1 (b) deve COMPARTILHAR a logica com o one-shot (fonte unica, secao 2.3),
# nao duplica-la. Aqui a copia e fiel so para medir a opcao (b) (python pago UMA vez).
import sys
import json
import shlex

SEPARATORS = {"|", "||", "&&", ";"}
PUNCT = set("();<>|&")
DANGER_IN_TOKEN = set("$`{}")


def classify(cmd):
    if not cmd or not cmd.strip():
        return {"status": "defer", "reason": "empty"}
    if "\n" in cmd.strip():
        return {"status": "defer", "reason": "multiline"}
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        return {"status": "defer", "reason": "lex-error"}

    segments = []
    current = []
    for tok in tokens:
        if tok in SEPARATORS:
            segments.append(current)
            current = []
            continue
        if tok and all(c in PUNCT for c in tok):
            return {"status": "defer", "reason": "punct"}
        if any(c in DANGER_IN_TOKEN for c in tok):
            return {"status": "defer", "reason": "danger-char"}
        current.append(tok)
    segments.append(current)

    segments = [s for s in segments if s]
    if not segments:
        return {"status": "defer", "reason": "no-segments"}
    return {"status": "ok", "segments": segments}


def main():
    # Sinaliza pronto na 1a linha (opcional; o daemon le e descarta).
    sys.stdout.write(json.dumps({"status": "ready"}))
    sys.stdout.write("\n")
    sys.stdout.flush()
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        cmd = line.rstrip("\n").rstrip("\r")
        sys.stdout.write(json.dumps(classify(cmd)))
        sys.stdout.write("\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
