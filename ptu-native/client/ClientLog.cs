// ClientLog.cs - log de FALHA DE SUBIDA do cliente NativeAOT (auto-allow) do Claude Code. PASSO D.
// Complementar ao log do daemon (§7): o daemon pode NUNCA nascer, entao o cliente grava por conta
// propria um marcador minimo quando algo impede o caminho feliz. Contrato (§5(b)/Passo D):
//   - SEM o command (privacidade; nem o hash, que e' reversivel por dicionario p/ comando estereotipado);
//   - ACL so-usuario (mesma postura do log do daemon);
//   - rate-limited (o cliente e' dispara-e-sai: o estado do rate-limit vive no mtime do arquivo);
//   - codigos: spawn-failed, daemon-not-ready, identity-invalid, dll-missing.
// SUCESSO normal NAO loga. Tudo em try/catch: logar JAMAIS lanca nem atrasa o defer (fail-open do log).
using System;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;

namespace Ptu.Client
{
    internal static class ClientLog
    {
        // Janela de rate-limit: dispara-e-sai re-invocado em rajada nao deve encher o log. A 1a escrita
        // (arquivo ausente) SEMPRE ocorre -> o §8 forca daemon-nao-pronto e exige a presenca do marcador.
        private const int RateLimitMs = 1000;

        internal static void Write(string logPath, string requestId, string code)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(logPath)) { return; }
                string rid = string.IsNullOrEmpty(requestId) ? "-" : requestId;

                string dir = Path.GetDirectoryName(logPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) { Directory.CreateDirectory(dir); }

                bool exists = File.Exists(logPath);
                if (exists)
                {
                    // Rate-limit por mtime: escrita recente -> pula (mantem o caminho de defer barato).
                    DateTime last = File.GetLastWriteTimeUtc(logPath);
                    if ((DateTime.UtcNow - last).TotalMilliseconds < RateLimitMs) { return; }
                }
                else
                {
                    CreateUserOnly(logPath);
                }

                string line = DateTime.UtcNow.ToString("o") + "\t" + rid + "\t" + code + "\n";
                File.AppendAllText(logPath, line, new UTF8Encoding(false));
            }
            catch { /* fail-open: o log nunca pode impedir o defer */ }
        }

        // Cria o arquivo de log com DACL so-usuario (heranca removida; FullControl so p/ o SID corrente),
        // espelhando Initialize-PtuLog do daemon. SID via P/Invoke (NativeMethods), sem WindowsIdentity.
        private static void CreateUserOnly(string path)
        {
            using (FileStream fs = File.Create(path)) { }
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
