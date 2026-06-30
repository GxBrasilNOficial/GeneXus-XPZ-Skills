// ClientIdentity.cs - identidade do cliente NativeAOT do hook PreToolUse (auto-allow) do Claude Code.
// PASSO D. Paridade BYTE-A-BYTE com o lado PowerShell (Passo B3):
//   ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1 (Resolve-PtuRepoMarkerDir, ConvertTo-PtuRootsCanonical,
//   Get-PtuIdentityHashFromParts, Get-PtuIdentityNames, Get-PtuIdentity) +
//   ClaudeCodePreToolUseSafeAllowSupport.ps1 (Get-PtuRoots).
// O §8 (Passo E) prova hash byte-identico cliente[C#] <-> daemon[PS], inclusive env-ausente -> default.
//
// canonicalizePath vem de Ptu.Canon (PtuCanon.cs compilado NESTE EXE; byte-identico a DLL, provado no B4)
// -- o cliente NAO carrega DLL. Tudo FAIL-CLOSED: qualquer componente invalido -> identidade null -> defer.
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace Ptu.Client
{
    internal sealed class PtuIdentity
    {
        internal string Sid;
        internal string RepoCanonical;
        internal string RootsCanonical;
        internal string IdentityHash;
        internal string PipeName;
        internal string GuardMutexName;
        internal string LogDirectory;
        internal string ClientLogPath;
    }

    internal static class ClientIdentity
    {
        // Paridade com Get-PtuRoots: fallback default literal quando a env esta ausente/vazia.
        private const string DefaultRoot = @"C:\Dev\Knowledge\GeneXus-XPZ-Skills";
        // Paridade com $script:PtuMarkerName (marcador dedicado da raiz; arquivo, nao .md nem .git).
        private const string MarkerName = ".ptu-safe-allow-root";

        // Get-PtuRoots: env PTU_SAFE_ALLOW_ROOTS (sep ';', ignora vazios/whitespace); ausente/vazia ->
        // o UNICO root default literal. Nunca retorna lista vazia.
        internal static string[] GetRoots()
        {
            string env = Environment.GetEnvironmentVariable("PTU_SAFE_ALLOW_ROOTS");
            if (!string.IsNullOrWhiteSpace(env))
            {
                var parts = new List<string>();
                foreach (var p in env.Split(';'))
                {
                    if (!string.IsNullOrWhiteSpace(p)) { parts.Add(p); }
                }
                if (parts.Count >= 1) { return parts.ToArray(); }
            }
            return new[] { DefaultRoot };
        }

        // Resolve-PtuRepoMarkerDir: ascensao determinista coletando TODO ancestral (inclusive o start)
        // que contenha um FILE de nome EXATO MarkerName; valido SO com EXATAMENTE 1 (fail-closed em 0/>=2).
        internal static string ResolveRepoMarkerDir(string startDirectory)
        {
            if (string.IsNullOrWhiteSpace(startDirectory)) { return null; }
            var markerDirs = new List<string>();
            DirectoryInfo dir;
            try { dir = new DirectoryInfo(startDirectory); } catch { return null; }
            while (dir != null)
            {
                string candidate = Path.Combine(dir.FullName, MarkerName);
                if (File.Exists(candidate)) { markerDirs.Add(dir.FullName); }
                dir = dir.Parent;
            }
            if (markerDirs.Count == 1) { return markerDirs[0]; }
            return null;
        }

        // Get-PtuCanonicalRepoRoot: marcador -> canonicalizePath; null propaga.
        internal static string CanonicalRepoRoot(string startDirectory)
        {
            string markerDir = ResolveRepoMarkerDir(startDirectory);
            if (markerDir == null) { return null; }
            return Ptu.Canon.CanonicalizePath(markerDir);
        }

        // ConvertTo-PtuRootsCanonical: cada root por canonicalizePath; dedup OrdinalIgnoreCase preservando
        // 1a ocorrencia; ordena Ordinal; join ';'. Qualquer root vazio/nao-canonicalizavel -> null.
        internal static string RootsCanonical(string[] roots)
        {
            if (roots == null || roots.Length < 1) { return null; }
            var seen  = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var canon = new List<string>();
            foreach (var r in roots)
            {
                if (string.IsNullOrWhiteSpace(r)) { return null; }
                string c = Ptu.Canon.CanonicalizePath(r);
                if (c == null) { return null; }
                if (seen.Add(c)) { canon.Add(c); }
            }
            if (canon.Count < 1) { return null; }
            canon.Sort(StringComparer.Ordinal);
            return string.Join(";", canon);
        }

        // Get-PtuIdentityHashFromParts: SHA256( sid + "\0" + repo + "\0" + roots ) UTF-8 -> hex minusculo.
        internal static string IdentityHashFromParts(string sid, string repo, string roots)
        {
            string material = sid + "\0" + repo + "\0" + roots;
            byte[] bytes = new UTF8Encoding(false).GetBytes(material);
            byte[] hash  = SHA256.HashData(bytes);
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        // Get-PtuIdentity: orquestra; algum componente invalido -> null (fail-closed -> defer).
        // startDirectory = diretorio do EXE (co-localizado com daemon+DLL+marcador, layout Passo G).
        // rootsOverride: null -> GetRoots (fonte unica env/default).
        internal static PtuIdentity Compute(string startDirectory, string[] rootsOverride)
        {
            string sid = NativeMethods.GetCurrentUserSid();
            if (string.IsNullOrWhiteSpace(sid)) { return null; }
            string repo = CanonicalRepoRoot(startDirectory);
            if (repo == null) { return null; }
            string[] roots = rootsOverride ?? GetRoots();
            string rootsCanon = RootsCanonical(roots);
            if (rootsCanon == null) { return null; }
            string hash = IdentityHashFromParts(sid, repo, rootsCanon);
            if (!IsHash(hash)) { return null; }
            // Get-PtuIdentityNames: nomes de coordenacao derivados do MESMO hash.
            string logDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ClaudeCodePreToolUseSafeAllow");
            return new PtuIdentity
            {
                Sid            = sid,
                RepoCanonical  = repo,
                RootsCanonical = rootsCanon,
                IdentityHash   = hash,
                PipeName       = "ptu-safe-allow-" + hash,                  // NamedPipeClientStream usa o nome simples
                GuardMutexName = "Local\\ptu-safe-allow-guard-" + hash,
                LogDirectory   = logDir,
                ClientLogPath  = Path.Combine(logDir, "ptu-client-" + hash + ".log")
            };
        }

        // Paridade com o regex ^[0-9a-f]{64}$ de Get-PtuIdentityNames.
        private static bool IsHash(string h)
        {
            if (h == null || h.Length != 64) { return false; }
            foreach (char c in h)
            {
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) { return false; }
            }
            return true;
        }
    }
}
