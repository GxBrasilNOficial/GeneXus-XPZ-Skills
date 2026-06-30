// ptu-client - entry-point NativeAOT do cliente do hook PreToolUse (auto-allow) do Claude Code.
// PASSO D (em construcao). Modo real do hook (args VAZIO): le o JSON do hook no stdin, computa a
// identidade, dispara-e-sai contra o named pipe do daemon e devolve o hookSpecificOutput allow/defer.
// Modos diagnostico (read-only; NAO leem stdin, NAO conectam, NAO decidem, JAMAIS emitem allow), usados
// pelos self-tests de paridade (Passos D/E): --emit-pin e --emit-identity.
//
// ESTADO D1: identidade C# (ClientIdentity/NativeMethods) ligada nos modos diagnostico. O hook real
// (hot/cold-path, saida §3.1, log de falha de subida) e' o D3 -- aqui ainda devolve um defer placeholder.
using System;
using System.IO;
using Ptu;
using Ptu.Client;

if (args.Length >= 1)
{
    switch (args[0])
    {
        case "--emit-pin":
            // buildContractPin embutido (BuildPin.g.cs, gerado no build) -- handshake/diagnostico.
            Console.Out.Write(BuildPin.Value);
            return 0;
        case "--emit-identity":
        {
            // startDir OPCIONAL (so diagnostico/self-test): permite apontar um deploy sem relocar o EXE.
            // O hook real (D3) usa SEMPRE o diretorio do EXE. Roots vem da env/default (GetRoots).
            string startDir = args.Length >= 2 ? args[1] : Path.GetDirectoryName(Environment.ProcessPath);
            PtuIdentity id = ClientIdentity.Compute(startDir, null);
            Console.Out.Write(id == null ? "IDENTITY-INVALID" : id.IdentityHash);
            return 0;
        }
    }
}

// Hook real (args vazio): D3. Placeholder fail-closed ate la.
Console.Out.Write("{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"defer\",\"permissionDecisionReason\":\"ptu-client interim D1\"}}");
return 0;
