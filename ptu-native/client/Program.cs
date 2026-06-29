// ptu-client - entry-point NativeAOT do cliente do hook PreToolUse (auto-allow) do Claude Code.
// PASSO B (spike): modo CLI que canonicaliza cada caminho recebido por argumento e imprime UMA
// linha por caminho (ou "<null>" em falha). Serve ao gate de viabilidade do Passo B, que exige
// invocar canonicalizePath pelo EXE-AOT sobre o corpus. O protocolo named-pipe dispara-e-sai
// (le o JSON do hook no stdin, handshake, request/resposta) e' o Passo D -- NAO esta aqui.
using System;
using Ptu;

// Saida deterministica em UTF-8 (sem BOM) para o spike do Passo B: a comparacao byte-a-byte do
// EXE-AOT vs DLL sobre o corpus nao-ASCII (I turco U+0130, ss U+00DF) NAO pode passar pela code page
// do console (CP850/ANSI), que nao representa esses caracteres e corromperia a saida. NAO afeta o
// buildContractPin (que hasheia PtuCanon.cs + gerador + targets + 3 props, nao este Program.cs).
System.Console.OutputEncoding = new System.Text.UTF8Encoding(false);

if (args.Length == 0)
{
    // Modo handshake/diagnostico: emite o buildContractPin embutido (de BuildPin.g.cs, gerado em build).
    Console.Out.Write(BuildPin.Value);
    return 0;
}

foreach (var a in args)
{
    string c = Canon.CanonicalizePath(a);
    Console.Out.WriteLine(c ?? "<null>");
}
return 0;
