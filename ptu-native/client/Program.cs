// ptu-client - entry-point NativeAOT do cliente do hook PreToolUse (auto-allow) do Claude Code.
// PASSO D (§5(b) dispara-e-sai). Solucao especifica do Claude Code; nao se aplica a Codex/Cursor/OpenCode.
//
// Modo real do hook (args VAZIO): le o JSON do hook no stdin (cap <= 64 KB + deadline), computa a
// identidade (paridade B3), e DISPARA-E-SAI contra o named pipe do daemon:
//   - canal disponivel (WaitNamedPipe)        -> connect, frame, resposta ESTRITA ("allow"/"defer"), emite §3.1;
//   - canal AUSENTE (ERROR_FILE_NOT_FOUND)    -> TryAcquire NAO-bloqueante do mutex de guarda:
//        adquiriu -> sobe o daemon DETACHED, segura guardWindowMs, escreve defer, libera; nao adquiriu -> defer;
//   - existe-porem-ocupado / outra falha      -> defer (canal existe; nao sobe outro daemon).
// INVARIANTE: isolado, NUNCA emite "allow"; allow so vem de um FRAME VALIDO do daemon com payload "allow".
// Qualquer erro/timeout/identidade invalida/handshake divergente -> "defer", exit 0. NUNCA "deny".
//
// Modos diagnostico (read-only; NAO leem stdin, NAO conectam, NAO decidem, JAMAIS emitem allow), usados
// pelos self-tests de paridade (Passos D/E): --emit-pin e --emit-identity [startDir].
using System;
using System.IO;
using Ptu;
using Ptu.Client;

if (args.Length >= 1)
{
    switch (args[0])
    {
        case "--emit-pin":
            Console.Out.Write(BuildPin.Value);
            return 0;
        case "--emit-identity":
        {
            // startDir OPCIONAL (so diagnostico/self-test): aponta um deploy sem relocar o EXE. O hook
            // real usa SEMPRE o diretorio do EXE. Roots vem da env/default (GetRoots).
            string startDir = args.Length >= 2 ? args[1] : Path.GetDirectoryName(Environment.ProcessPath);
            PtuIdentity diag = ClientIdentity.Compute(startDir, null);
            Console.Out.Write(diag == null ? "IDENTITY-INVALID" : diag.IdentityHash);
            return 0;
        }
        case "--observe":
            // Modo MEDICAO (Fase 3): exercita o fio real (sobe/consulta o daemon) e mede a latencia, mas
            // SEMPRE devolve defer ao Claude Code (passivo). NAO e' diagnostico: le stdin e conecta.
            return HookClient.Run(true);
        default:
            // Argumento desconhecido: fail-closed (o hook real nunca passa args).
            HookClient.WriteHookOutput("defer", HookClient.ReasonLocal);
            return 0;
    }
}

return HookClient.Run();
