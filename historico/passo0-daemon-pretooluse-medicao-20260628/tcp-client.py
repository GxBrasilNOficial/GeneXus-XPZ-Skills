#!/usr/bin/env python3
# tcp-client.py - PROTOTIPO DESCARTAVEL (passo 0b: cliente do fallback TCP+Python).
# Le o JSON do hook no stdin, descobre porta+token, conecta no loopback (deadline ~80ms),
# envia [magic|tokenLen|token|bodyLen|body], le o enum e monta o hookSpecificOutput. Fail-closed.
# So tokeniza/transporta: NUNCA decide allow (o veredito fica no daemon). NAO eh codigo final.
import sys
import socket
import struct
import json

DISCOVERY = r'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad\tcp-discovery.json'
DEADLINE = 0.08  # 80ms deadline monotonico (connect+io)


def emit(decision, reason):
    sys.stdout.write('{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"'
                     + decision + '","permissionDecisionReason":"' + reason + '"}}')


def defer():
    emit('defer', 'ptu-tcp fail-closed')


def recvn(sock, n):
    buf = b''
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError()
        buf += chunk
    return buf


def main():
    try:
        data = sys.stdin.buffer.read()
    except Exception:
        defer()
        return
    try:
        with open(DISCOVERY, 'r') as f:
            disc = json.load(f)
        port = int(disc['port'])
        token = disc['token'].encode('utf-8')
        sock = socket.create_connection(('127.0.0.1', port), timeout=DEADLINE)
        sock.settimeout(DEADLINE)
        frame = bytes([1]) + struct.pack('>I', len(token)) + token + struct.pack('>I', len(data)) + data
        sock.sendall(frame)
        recvn(sock, 1)  # magic
        n = struct.unpack('>I', recvn(sock, 4))[0]
        if n < 0 or n > 65536:
            defer()
            return
        resp = recvn(sock, n).decode('utf-8')
        sock.close()
        if resp in ('allow', 'defer'):
            emit(resp, 'ptu-tcp')
        else:
            defer()
    except Exception:
        defer()


if __name__ == '__main__':
    main()
