// ptu-client - entry-point NativeAOT do cliente do hook PreToolUse (auto-allow) do Claude Code.
// PASSO B (spike): modo CLI que canonicaliza cada caminho recebido por argumento e imprime UMA
// linha por caminho (ou "<null>" em falha). Serve ao gate de viabilidade do Passo B, que exige
// invocar canonicalizePath pelo EXE-AOT sobre o corpus. O protocolo named-pipe dispara-e-sai
// (le o JSON do hook no stdin, handshake, request/resposta) e' o Passo D -- NAO esta aqui.
using System;
using Ptu;

if (args.Length == 0)
{
    return 0;
}

foreach (var a in args)
{
    string c = Canon.CanonicalizePath(a);
    Console.Out.WriteLine(c ?? "<null>");
}
return 0;
