#!/usr/bin/env python3
# Get-ClaudeCodeBashSafeSegments.py - parte do hook PreToolUse do CLAUDE CODE (auto-allow).
# (O lexing em si e agnostico de agente, mas integra a solucao especifica do Claude Code.)
# Ver claude-code-pretooluse-auto-allow-design.md (secao 4).
#
# Tokeniza um comando Bash com shlex (parser de verdade, nao regex) e devolve os
# SEGMENTOS de um pipeline simples e seguro, OU 'defer'. Conservador por desenho:
# qualquer duvida -> defer (fail-closed). O classificador de verbo/flag fica no
# PowerShell (ClaudeCodePreToolUseSafeAllowSupport.ps1); este helper so faz o lexing seguro.
#
# Contrato: le o comando cru do stdin; emite 1 linha JSON no stdout:
#   {"status":"ok","segments":[["git","log"],["head"]]}
#   {"status":"defer","reason":"<motivo>"}
import sys
import json
import shlex
import unicodedata
import hashlib

# Separadores de segmento de pipeline aceitos (estrutura permitida).
SEPARATORS = {"|", "||", "&&", ";"}
# Caracteres de pontuacao que o shlex (punctuation_chars=True) agrupa em tokens
# proprios. Um token feito so destes que NAO seja separador (redirecao >, subshell
# (), background &, here-doc <<, merge 2>&1 ...) -> defer.
PUNCT = set("();<>|&")
# Expansao / substituicao / brace dentro de um token -> defer (nao sabemos provar
# seguro): $VAR, $(...), `...`, ${...}, {a,b}.
DANGER_IN_TOKEN = set("$`{}")


# Marcador de versao: SHA256 do PROPRIO source deste modulo, computado em runtime na
# importacao. O daemon (Passo C) usa isto para PROVAR que o python persistente importou a
# versao NOVA do .py apos um respawn (e nao um modulo/.pyc velho ainda em memoria).
def _module_source_sha256():
    try:
        with open(__file__, "rb") as _f:
            return hashlib.sha256(_f.read()).hexdigest()
    except OSError:
        return None


CLASSIFY_SOURCE_SHA256 = _module_source_sha256()


def emit(obj):
    sys.stdout.write(json.dumps(obj))


# classify: logica pura e IMPORTAVEL (Passo A da v1). Recebe o comando cru e RETORNA o
# dict de resultado (mesma semantica de antes, so que retornando em vez de emitir). O
# ShlexLoop.py persistente IMPORTA esta funcao -> fonte unica da tokenizacao (sem duplicar).
def classify(cmd):
    if not cmd or not cmd.strip():
        return {"status": "defer", "reason": "empty"}
    # Multi-linha: newline pode separar comandos; nao tratamos -> defer.
    if "\n" in cmd.strip():
        return {"status": "defer", "reason": "multiline"}
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        # Aspas desbalanceadas / lexing invalido -> defer.
        return {"status": "defer", "reason": "lex-error"}

    segments = []
    current = []
    for tok in tokens:
        if tok in SEPARATORS:
            segments.append(current)
            current = []
            continue
        if tok and all(c in PUNCT for c in tok):
            # Pontuacao que nao e separador: redirecao, subshell, background, etc.
            return {"status": "defer", "reason": "punct"}
        if any(c in DANGER_IN_TOKEN for c in tok):
            return {"status": "defer", "reason": "danger-char"}
        # Unicode de CONTROLE/FORMATO (categorias Cc/Cf: zero-width U+200B/U+FEFF, bidi
        # U+202E, etc.) em qualquer token -> defer (fail-closed; nao tentamos provar seguro).
        if any(unicodedata.category(c) in ("Cc", "Cf") for c in tok):
            return {"status": "defer", "reason": "unicode-control"}
        current.append(tok)
    segments.append(current)

    segments = [s for s in segments if s]
    if not segments:
        return {"status": "defer", "reason": "no-segments"}
    return {"status": "ok", "segments": segments}


def main():
    emit(classify(sys.stdin.read()))


if __name__ == "__main__":
    main()
