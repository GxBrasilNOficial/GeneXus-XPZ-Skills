// HookClient.cs - orquestracao do cliente NativeAOT do hook PreToolUse (auto-allow) do Claude Code.
// PASSO D. Hot-path (canal disponivel) XOR cold-path (canal ausente -> guard+spawn). Toda falha -> defer.
// AOT-safe: JSON por JsonDocument (leitura) e Utf8JsonWriter (request) -- NUNCA o serializer reflexivo
// (cortado pelo trimming AOT). Saida §3.1 montada manualmente, byte-a-byte com Get-PtuHookOutput.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Ptu;

namespace Ptu.Client
{
    internal static class HookClient
    {
        // --- Orcamento (fonte unica; SEPARADOS: uma invocacao e quente XOR fria). Medicao = Passo F. ---
        private const int ResponseDeadlineMs = 80;   // QUENTE: connect+frame+resposta
        private const int GuardWindowMs      = 50;   // FRIO: clamp(50, ~coldReadyMs_p95, 200)
        private const int StdinDeadlineMs    = 1000;  // rede de seguranca: stdin do hook ja vem pronto
        private const int MaxFrameBytes      = 65536; // 64 KB

        // --- Protocolo do wire (§7), identico ao daemon: [magic 1B][protoVer 2B BE][len 4B BE][payload]. ---
        private const byte MagicData       = 0x01;   // o cliente nao envia 0x02 (shutdown): so dados
        private const int  ProtocolVersion = 1;

        // Paridade com $script:PtuSafeAllowVersion (Support.ps1). Barreira de versao no handshake.
        private const string Version = "1.0.0";

        // Reasons (o §8 normaliza SO o valor de permissionDecisionReason; conteudo nao afeta a paridade).
        internal const string ReasonDaemon  = "ptu-daemon v" + Version;
        internal const string ReasonLocal   = "ptu-client v" + Version + " fail-closed";
        internal const string ReasonObserve = "ptu-observe v" + Version + " passive";

        private const string DaemonScriptName = "ClaudeCodePreToolUseSafeAllowDaemon.ps1";
        private const string DllName          = "PtuCanon.dll";

        private sealed class HookFields { internal string ToolName; internal string Command; internal string Cwd; }

        // Resultado do Dispatch: decisao + telemetria do modo observe (Fase 3). No enforce so .Decision e' usado.
        private sealed class DispatchResult
        {
            internal string Decision;    // allow | defer
            internal double LatencyMs;   // ida-e-volta e2e client-side (inclui a espera na fila do daemon)
            internal string Outcome;     // decided | busy | cold | deadline | error | stdin | parse | identity
            internal string Path;        // hot | cold | -
        }

        internal static int Run() { return Run(false); }

        // observe=true (Fase 3): mede o fio real e SEMPRE devolve defer (passivo). observe=false: enforce,
        // comportamento byte-identico ao anterior (a saida depende SO de r.Decision).
        internal static int Run(bool observe)
        {
            // requestId cunhado pelo cliente (o hook nao traz um); usado no payload e nos logs.
            string requestId = Guid.NewGuid().ToString("N");
            try
            {
                string hookJson = ReadStdinCapped();
                if (hookJson == null) { return Finish(observe, requestId, null, Pre("stdin")); }

                HookFields f = ParseHook(hookJson);
                if (f == null) { return Finish(observe, requestId, null, Pre("parse")); }

                string exeDir = Path.GetDirectoryName(Environment.ProcessPath);
                PtuIdentity id = ClientIdentity.Compute(exeDir, null);
                if (id == null)
                {
                    ClientLog.Write(IdentityInvalidLogPath(), requestId, "identity-invalid");
                    return Finish(observe, requestId, null, Pre("identity"));
                }

                DispatchResult r = Dispatch(f, id, exeDir, requestId);
                return Finish(observe, requestId, id, r);
            }
            catch
            {
                return Finish(observe, requestId, null, Pre("error"));
            }
        }

        // Falha pre-Dispatch: defer, sem latencia/path reais (mantem a contagem do observe completa).
        private static DispatchResult Pre(string outcome)
        {
            return new DispatchResult { Decision = "defer", LatencyMs = 0, Outcome = outcome, Path = "-" };
        }

        // Emite a saida §3.1. No enforce: a decisao do daemon (allow/defer). No observe: grava a linha de
        // medicao e FORCA defer (passivo: mede tudo, decide nada). id==null no observe -> sem log, so defer.
        private static int Finish(bool observe, string requestId, PtuIdentity id, DispatchResult r)
        {
            if (observe)
            {
                if (id != null) { ObserveLog.Write(id.ObserveLogPath, requestId, r.Decision, r.Outcome, r.LatencyMs, r.Path); }
                WriteHookOutput("defer", ReasonObserve);
                return 0;
            }
            WriteHookOutput(r.Decision, r.Decision == "allow" ? ReasonDaemon : ReasonLocal);
            return 0;
        }

        // ------------------------------------------------------------------------------------------------
        // Dispatch: quente XOR frio. allow SO do hot-path com frame valido "allow".
        // ------------------------------------------------------------------------------------------------
        private static DispatchResult Dispatch(HookFields f, PtuIdentity id, string exeDir, string requestId)
        {
            string pipePath = @"\\.\pipe\" + id.PipeName;
            var sw = Stopwatch.StartNew();
            bool available = NativeMethods.WaitNamedPipeW(pipePath, (uint)ResponseDeadlineMs);
            if (available)
            {
                return HotPath(f, id, requestId, sw);
            }
            int err = Marshal.GetLastWin32Error();
            if (err == NativeMethods.ERROR_FILE_NOT_FOUND)
            {
                string d = ColdPath(id, exeDir, requestId);   // canal ausente -> guard/spawn
                return new DispatchResult { Decision = d, LatencyMs = Ms(sw), Outcome = "cold", Path = "cold" };
            }
            // existe-porem-ocupado (WaitNamedPipe esgotou o prazo sem instancia livre) -> nao sobe outro
            // daemon. Principal sinal de CONCORRENCIA: a fila do daemon single-threaded (maxInstances=1).
            return new DispatchResult { Decision = "defer", LatencyMs = Ms(sw), Outcome = "busy", Path = "hot" };
        }

        private static DispatchResult HotPath(HookFields f, PtuIdentity id, string requestId, Stopwatch sw)
        {
            try
            {
                using var client = new NamedPipeClientStream(".", id.PipeName, PipeDirection.InOut);
                int connTimeout = Remaining(sw);
                if (connTimeout <= 0) { return new DispatchResult { Decision = "defer", LatencyMs = Ms(sw), Outcome = "deadline", Path = "hot" }; }
                client.Connect(connTimeout);   // lanca em timeout/sem-instancia -> catch -> defer

                byte[] payload = BuildRequestPayload(f, requestId);
                if (payload.Length > MaxFrameBytes) { return new DispatchResult { Decision = "defer", LatencyMs = Ms(sw), Outcome = "error", Path = "hot" }; }
                WriteFrame(client, MagicData, payload);

                string resp = ReadResponseStrict(client, sw);
                // O daemon so emite "allow"/"defer"; resp null = timeout/eof (estourou o prazo de 80 ms).
                if (resp == "allow") { return new DispatchResult { Decision = "allow", LatencyMs = Ms(sw), Outcome = "decided", Path = "hot" }; }
                if (resp == "defer") { return new DispatchResult { Decision = "defer", LatencyMs = Ms(sw), Outcome = "decided", Path = "hot" }; }
                return new DispatchResult { Decision = "defer", LatencyMs = Ms(sw), Outcome = "deadline", Path = "hot" };
            }
            catch { return new DispatchResult { Decision = "defer", LatencyMs = Ms(sw), Outcome = "error", Path = "hot" }; }
        }

        private static string ColdPath(PtuIdentity id, string exeDir, string requestId)
        {
            string daemonScript = Path.Combine(exeDir, DaemonScriptName);
            string dllPath      = Path.Combine(exeDir, DllName);
            if (!File.Exists(dllPath))      { ClientLog.Write(id.ClientLogPath, requestId, "dll-missing");   return "defer"; }
            if (!File.Exists(daemonScript)) { ClientLog.Write(id.ClientLogPath, requestId, "spawn-failed");  return "defer"; }

            Mutex guard = null;
            bool acquired = false;
            try
            {
                guard = CreateUserOnlyMutex(id.GuardMutexName, id.Sid);
                try { acquired = guard.WaitOne(0); }
                catch (AbandonedMutexException) { acquired = true; }
                if (!acquired) { return "defer"; }   // outro cliente ja esta subindo o daemon

                try { SpawnDaemonDetached(daemonScript); }
                catch { ClientLog.Write(id.ClientLogPath, requestId, "spawn-failed"); return "defer"; }

                Thread.Sleep(GuardWindowMs);   // segura a janela fria; NUNCA espera ready
                ClientLog.Write(id.ClientLogPath, requestId, "daemon-not-ready");   // rate-limited
                return "defer";
            }
            catch { return "defer"; }
            finally
            {
                if (guard != null)
                {
                    if (acquired) { try { guard.ReleaseMutex(); } catch { } }
                    guard.Dispose();
                }
            }
        }

        // ------------------------------------------------------------------------------------------------
        // Spawn detached: ShellExecute hidden. Critico: NAO herdar os std-handles do cliente (se o daemon
        // herdasse o stdout, o pipe lido pelo Claude Code ficaria aberto apos a saida do cliente e o hook
        // PENDURARIA). ShellExecute lanca independente (sem heranca de handles) e herda o environment
        // (mesmos roots -> mesmo pipe). NAO passa -Roots: o daemon resolve pela mesma fonte (env/default).
        // ------------------------------------------------------------------------------------------------
        private static void SpawnDaemonDetached(string daemonScript)
        {
            var psi = new ProcessStartInfo
            {
                FileName        = "pwsh",
                Arguments       = "-NoProfile -File \"" + daemonScript + "\"",
                UseShellExecute = true,
                WindowStyle     = ProcessWindowStyle.Hidden,
                CreateNoWindow  = true
            };
            Process.Start(psi);   // nao espera; nao retem o handle
        }

        private static Mutex CreateUserOnlyMutex(string name, string sidStr)
        {
            var sid = new SecurityIdentifier(sidStr);
            var sec = new MutexSecurity();
            sec.AddAccessRule(new MutexAccessRule(sid, MutexRights.FullControl, AccessControlType.Allow));
            bool createdNew;
            return MutexAcl.Create(false, name, out createdNew, sec);
        }

        // ------------------------------------------------------------------------------------------------
        // IO do wire
        // ------------------------------------------------------------------------------------------------
        private static int Remaining(Stopwatch sw)
        {
            int r = ResponseDeadlineMs - (int)sw.ElapsedMilliseconds;
            return r;
        }

        private static double Ms(Stopwatch sw) { return sw.Elapsed.TotalMilliseconds; }

        private static void WriteFrame(Stream s, byte magic, byte[] payload)
        {
            int len = payload.Length;
            byte[] hdr = new byte[7];
            hdr[0] = magic;
            hdr[1] = (byte)((ProtocolVersion >> 8) & 0xFF);
            hdr[2] = (byte)(ProtocolVersion & 0xFF);
            hdr[3] = (byte)((len >> 24) & 0xFF);
            hdr[4] = (byte)((len >> 16) & 0xFF);
            hdr[5] = (byte)((len >> 8) & 0xFF);
            hdr[6] = (byte)(len & 0xFF);
            s.Write(hdr, 0, 7);
            s.Write(payload, 0, len);
            s.Flush();
        }

        // Le UM frame de resposta. Retorna a string do payload (ordinal, sem normalizar) ou null em
        // magic!=dados / protoVer!=1 / len invalido / timeout / EOF. O chamador compara == "allow".
        private static string ReadResponseStrict(Stream s, Stopwatch sw)
        {
            byte[] hdr = ReadExact(s, 7, sw);
            if (hdr == null) { return null; }
            byte magic = hdr[0];
            int proto = (hdr[1] << 8) | hdr[2];
            long len = ((long)hdr[3] << 24) | ((long)hdr[4] << 16) | ((long)hdr[5] << 8) | hdr[6];
            if (magic != MagicData) { return null; }
            if (proto != ProtocolVersion) { return null; }
            if (len < 0 || len > MaxFrameBytes) { return null; }
            byte[] payload = ReadExact(s, (int)len, sw);
            if (payload == null) { return null; }
            return new UTF8Encoding(false).GetString(payload);
        }

        private static byte[] ReadExact(Stream s, int count, Stopwatch sw)
        {
            if (count == 0) { return Array.Empty<byte>(); }
            byte[] buf = new byte[count];
            int off = 0;
            while (off < count)
            {
                int remaining = Remaining(sw);
                if (remaining <= 0) { return null; }
                var t = s.ReadAsync(buf, off, count - off);
                if (!t.Wait(remaining)) { return null; }
                int k = t.Result;
                if (k <= 0) { return null; }
                off += k;
            }
            return buf;
        }

        // ------------------------------------------------------------------------------------------------
        // JSON: leitura tolerante (JsonDocument) e request (Utf8JsonWriter) -- AOT-safe, sem reflexao.
        // ------------------------------------------------------------------------------------------------
        private static HookFields ParseHook(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Object) { return null; }
                if (!root.TryGetProperty("tool_name", out var tn) || tn.ValueKind != JsonValueKind.String) { return null; }
                if (!root.TryGetProperty("cwd", out var cw) || cw.ValueKind != JsonValueKind.String) { return null; }
                string command = "";
                if (root.TryGetProperty("tool_input", out var ti) && ti.ValueKind == JsonValueKind.Object
                    && ti.TryGetProperty("command", out var cmd) && cmd.ValueKind == JsonValueKind.String)
                {
                    command = cmd.GetString();
                }
                return new HookFields { ToolName = tn.GetString(), Command = command, Cwd = cw.GetString() };
            }
            catch { return null; }
        }

        private static byte[] BuildRequestPayload(HookFields f, string requestId)
        {
            using var ms = new MemoryStream();
            using (var w = new Utf8JsonWriter(ms))
            {
                w.WriteStartObject();
                w.WriteString("tool_name", f.ToolName);
                w.WriteStartObject("tool_input");
                w.WriteString("command", f.Command);
                w.WriteEndObject();
                w.WriteString("cwd", f.Cwd);
                w.WriteString("ptuSafeAllowVersion", Version);
                w.WriteString("buildContractPin", BuildPin.Value);
                w.WriteString("requestId", requestId);
                w.WriteEndObject();
            }
            return ms.ToArray();
        }

        // ------------------------------------------------------------------------------------------------
        // Saida §3.1: byte-a-byte com Get-PtuHookOutput (ConvertTo-Json -Compress). So permissionDecision
        // varia entre allow/defer; ordem hookEventName->permissionDecision->permissionDecisionReason, sem
        // espacos. NUNCA "deny". Bytes UTF-8 crus no stdout (sem code page).
        // ------------------------------------------------------------------------------------------------
        internal static void WriteHookOutput(string decision, string reason)
        {
            var sb = new StringBuilder(160);
            sb.Append("{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"");
            sb.Append(decision);
            sb.Append("\",\"permissionDecisionReason\":\"");
            sb.Append(EscapeJson(reason));
            sb.Append("\"}}");
            byte[] bytes = new UTF8Encoding(false).GetBytes(sb.ToString() + "\n");
            using var stdout = Console.OpenStandardOutput();
            stdout.Write(bytes, 0, bytes.Length);
            stdout.Flush();
        }

        private static string EscapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) { return s; }
            var sb = new StringBuilder(s.Length + 8);
            foreach (char c in s)
            {
                switch (c)
                {
                    case '\\': sb.Append("\\\\"); break;
                    case '"':  sb.Append("\\\""); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) { sb.Append("\\u").Append(((int)c).ToString("x4")); }
                        else { sb.Append(c); }
                        break;
                }
            }
            return sb.ToString();
        }

        private static string IdentityInvalidLogPath()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ClaudeCodePreToolUseSafeAllow", "ptu-client-identity-invalid.log");
        }

        // ------------------------------------------------------------------------------------------------
        // stdin do hook: cap <= 64 KB + deadline. >cap ou timeout -> null (defer). Le em thread de pool
        // (background) para que o deadline nunca pendure o processo: estourou -> retorna e o exit 0 segue.
        // ------------------------------------------------------------------------------------------------
        private static string ReadStdinCapped()
        {
            try
            {
                var t = Task.Run(() => ReadAllCapped(MaxFrameBytes));
                if (!t.Wait(StdinDeadlineMs)) { return null; }
                return t.Result;
            }
            catch { return null; }
        }

        private static string ReadAllCapped(int cap)
        {
            try
            {
                using var stdin = Console.OpenStandardInput();
                using var ms = new MemoryStream();
                byte[] buf = new byte[8192];
                int total = 0, r;
                while ((r = stdin.Read(buf, 0, buf.Length)) > 0)
                {
                    total += r;
                    if (total > cap) { return null; }   // over-cap -> defer
                    ms.Write(buf, 0, r);
                }
                return new UTF8Encoding(false).GetString(ms.ToArray());
            }
            catch { return null; }
        }
    }
}
