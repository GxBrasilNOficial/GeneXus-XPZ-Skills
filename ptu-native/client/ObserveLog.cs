// ObserveLog.cs - log de MEDICAO (modo observe / Fase 3) do cliente NativeAOT do hook PreToolUse
// (auto-allow) do Claude Code. PASSO G. Diferente do ClientLog (que so registra FALHA DE SUBIDA e e'
// rate-limited): aqui grava UMA linha POR INVOCACAO para caracterizar a latencia sob concorrencia -- o
// dado que destrava o enforce (§9-0e, condicao (c)). Contrato (§7 log minimo):
//   - SEM o command e SEM o hash do command (privacidade);
//   - ACL so-usuario (mesma postura do ClientLog/daemon);
//   - SEM rate-limit (queremos TODAS as observacoes);
//   - append concorrente com retry curto (varios clientes podem escrever ao mesmo tempo -- justamente
//     o cenario medido); fail-open: logar JAMAIS impede nem atrasa o defer.
// Linha TSV: ts \t requestId \t wouldDecision \t outcome \t latencyMs \t path
using System;
using System.Globalization;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading;

namespace Ptu.Client
{
    internal static class ObserveLog
    {
        private const int AppendRetries = 5;

        // wouldDecision: o que o modo enforce TERIA emitido (allow/defer). outcome: decided | busy | cold |
        // deadline | error | stdin | parse | identity. path: hot | cold | -.
        internal static void Write(string logPath, string requestId, string wouldDecision,
                                   string outcome, double latencyMs, string path)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(logPath)) { return; }
                string rid = string.IsNullOrEmpty(requestId) ? "-" : requestId;

                string dir = Path.GetDirectoryName(logPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) { Directory.CreateDirectory(dir); }

                if (!File.Exists(logPath)) { CreateUserOnly(logPath); }

                string line = DateTime.UtcNow.ToString("o") + "\t" + rid + "\t"
                            + wouldDecision + "\t" + outcome + "\t"
                            + latencyMs.ToString("F3", CultureInfo.InvariantCulture) + "\t" + path + "\n";
                byte[] bytes = new UTF8Encoding(false).GetBytes(line);

                // Append concorrente: FileShare.ReadWrite + retry curto cobre a colisao entre clientes
                // simultaneos (sharing violation). Fail-open apos esgotar as tentativas.
                for (int attempt = 0; attempt < AppendRetries; attempt++)
                {
                    try
                    {
                        using (var fs = new FileStream(logPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite))
                        {
                            fs.Write(bytes, 0, bytes.Length);
                        }
                        return;
                    }
                    catch (IOException)
                    {
                        Thread.Sleep(2 * (attempt + 1));   // backoff curto entre tentativas
                    }
                }
            }
            catch { /* fail-open: o log nunca pode impedir nem atrasar o defer */ }
        }

        // Cria o arquivo com DACL so-usuario (heranca removida; FullControl so p/ o SID corrente),
        // espelhando ClientLog.CreateUserOnly / Initialize-PtuLog do daemon. CreateNew e' ATOMICO: se outro
        // cliente concorrente ja criou, lanca IOException e nos so seguimos para o append (o criador cuidou
        // da ACL) -- evita o File.Create truncar o conteudo de quem criou primeiro.
        private static void CreateUserOnly(string path)
        {
            try
            {
                using (var fs = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.ReadWrite)) { }
            }
            catch (IOException) { return; }   // ja existe (corrida de criacao): nao recria nem re-aplica ACL

            string sidStr = NativeMethods.GetCurrentUserSid();
            if (string.IsNullOrWhiteSpace(sidStr)) { return; }   // sem SID: arquivo fica com ACL herdada (fail-open)
            var sid = new SecurityIdentifier(sidStr);
            var sec = new FileSecurity();
            sec.SetAccessRuleProtection(true, false);            // remove heranca
            sec.AddAccessRule(new FileSystemAccessRule(
                sid, FileSystemRights.FullControl, AccessControlType.Allow));
            new FileInfo(path).SetAccessControl(sec);
        }
    }
}
