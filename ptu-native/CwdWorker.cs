// CwdWorker.cs - worker com timeout DURO + CAP de in-flight para a canonicalizacao do cwd do
// daemon PreToolUse (auto-allow) do Claude Code (Passo C / G2(a), spec linhas 103-123).
// Compilado SO na DLL (ptu-lib), AO LADO de PtuCanon.cs, NUNCA no cliente NativeAOT. NAO entra no
// buildContractPin (o gerador hasheia so PtuCanon.cs + gerador + targets + 3 props) -> pin-neutro.
// O scriptblock do PowerShell nao roda em Thread crua (sem Runspace); por isso o worker e' C#.

using System;
using System.Threading;

namespace Ptu
{
    public static class CwdWorker
    {
        private static int _inFlight = 0;

        // Sentinelas de falha: o daemon compara o retorno por IGUALDADE EXATA a estas 3 constantes
        // (qualquer match -> defer, fail-closed) e nao por heuristica de formato. Nao podem colidir
        // com um caminho canonico real, que SEMPRE comeca por letra de drive ou '\\' (nunca por uma
        // destas palavras). So um resultado != sentinela E nao-nulo e' caminho canonico (allow-candidato).
        public const string CapExceeded = "cap-exceeded";
        public const string TimedOut    = "timed-out";
        public const string Failed      = "failed";

        // Nucleo: roda 'body' numa thread com timeout DURO e CAP de in-flight. O loop do daemon e'
        // single-threaded e chama isto UMA vez por requisicao (bloqueia <= timeoutMs). O cap protege
        // contra ACUMULO de threads presas em I/O nao-cancelavel (UNC ruim): cada timeout deixa a
        // thread viva (ela devolve o slot ao decrementar no finally quando/se a I/O destravar), e o
        // proximo request geraria OUTRA thread -> sem cap acumulariam sem limite. Ao atingir o cap,
        // novas chamadas retornam CapExceeded SEM spawnar. Contrato do self-test: LIMITE POR CAP
        // (InFlight() <= cap sob N timeouts), NAO ANTES==DEPOIS (inatingivel com I/O nao-cancelavel).
        private static string RunCapped(Func<string> body, int timeoutMs, int cap)
        {
            if (body == null) { return Failed; }
            if (timeoutMs < 0 || cap < 1) { return Failed; }

            int cur = Interlocked.Increment(ref _inFlight);
            if (cur > cap)
            {
                Interlocked.Decrement(ref _inFlight);
                return CapExceeded;
            }

            string result = null;
            var worker = new Thread(() =>
            {
                try { result = body(); }
                catch { result = null; }
                finally { Interlocked.Decrement(ref _inFlight); }
            });
            worker.IsBackground = true;
            worker.Start();

            if (!worker.Join(timeoutMs))
            {
                // I/O nao terminou no deadline: a thread segue viva (nao-cancelavel) e devolvera o
                // slot ao decrementar no finally. O loop do daemon NAO pendura -> volta agora.
                return TimedOut;
            }
            // Join true estabelece happens-before: ler 'result' aqui e' seguro.
            return result == null ? Failed : result;
        }

        // Producao: canonicaliza 'path' (resolve symlink/junction -> caminho DOS minusculo) com
        // timeout/cap. Resultado != sentinela E nao-nulo -> caminho canonico; qualquer falha -> sentinela.
        public static string Canonicalize(string path, int timeoutMs, int cap)
        {
            if (string.IsNullOrEmpty(path)) { return Failed; }
            return RunCapped(() => Ptu.Canon.CanonicalizePath(path), timeoutMs, cap);
        }

        // SO PARA O SELF-TEST do cap: exercita o MESMO RunCapped com um corpo que DORME 'sleepMs'
        // (simula I/O nao-cancelavel sem UNC real de ~21s). Canonicalize nunca chama isto -> sem
        // efeito no caminho de producao. Mantem a logica de cap UNICA e efetivamente testada.
        public static string CanonicalizeSlowForTest(int sleepMs, int timeoutMs, int cap)
        {
            return RunCapped(() => { Thread.Sleep(sleepMs); return null; }, timeoutMs, cap);
        }

        public static int InFlight() { return Volatile.Read(ref _inFlight); }
    }
}
