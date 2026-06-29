// PtuCanon.cs - canonicalizacao de caminho do hook PreToolUse (auto-allow) do Claude Code.
// FONTE UNICA: este .cs e' compilado DUAS vezes, SEM #if -- (i) no cliente NativeAOT (EXE) e
// (ii) como DLL gerenciada non-AOT carregada por Add-Type -Path no daemon. O spike do Passo B
// (claude-code-pretooluse-implementacao-v1-plan.md, linhas 93-100) prova que CanonicalizePath
// e' byte-a-byte identico entre as duas compilacoes em todo o corpus.
//
// CanonicalizePath: abre handle do filesystem com FILE_FLAG_BACKUP_SEMANTICS (vale p/ diretorio),
// GetFinalPathNameByHandleW VOLUME_NAME_DOS + fallback explicito GUID->letra, remove os prefixos
// \\?\ e \\?\UNC\, e aplica ToLowerInvariant() EXPLICITO. AOT-safe: so DllImport, sem reflexao
// nem AppDomain. SINCRONO: o timeout/cap do open-handle (UNC inacessivel) e' do CHAMADOR (worker
// no daemon / deadline no cliente), nao deste metodo. Qualquer falha -> null (chamador -> defer).

using System;
using System.Runtime.InteropServices;

namespace Ptu
{
    public static class Canon
    {
        private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
        private const uint OPEN_EXISTING = 3;
        private const uint FILE_SHARE_READ = 0x1;
        private const uint FILE_SHARE_WRITE = 0x2;
        private const uint FILE_SHARE_DELETE = 0x4;
        private const uint FILE_NAME_NORMALIZED = 0x0;
        private const uint VOLUME_NAME_DOS = 0x0;
        private const uint VOLUME_NAME_GUID = 0x1;

        private static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "CreateFileW")]
        private static extern IntPtr CreateFileW(
            string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes,
            uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "GetFinalPathNameByHandleW")]
        private static extern uint GetFinalPathNameByHandleW(
            IntPtr hFile, [Out] char[] lpszFilePath, uint cchFilePath, uint dwFlags);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "GetVolumePathNamesForVolumeNameW")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetVolumePathNamesForVolumeNameW(
            string lpszVolumeName, [Out] char[] lpszVolumePathNames, uint cchBufferLength, out uint lpcchReturnLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr hObject);

        // Caminho canonico em minusculas (InvariantCulture) ou null em qualquer falha.
        public static string CanonicalizePath(string path)
        {
            if (string.IsNullOrEmpty(path)) { return null; }

            IntPtr h = CreateFileW(
                path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, IntPtr.Zero);
            if (h == INVALID_HANDLE_VALUE) { return null; }

            try
            {
                string dos = QueryFinalPath(h, VOLUME_NAME_DOS);
                if (dos == null)
                {
                    // Volume sem letra DOS montada: pega o nome GUID e resolve para a letra.
                    string guid = QueryFinalPath(h, VOLUME_NAME_GUID);
                    if (guid == null) { return null; }
                    dos = ResolveGuidVolumeToDos(guid);
                    if (dos == null) { return null; }
                }
                return Normalize(dos);
            }
            finally
            {
                CloseHandle(h);
            }
        }

        private static string QueryFinalPath(IntPtr h, uint volumeFlag)
        {
            uint flags = FILE_NAME_NORMALIZED | volumeFlag;
            char[] buf = new char[512];
            uint rc = GetFinalPathNameByHandleW(h, buf, (uint)buf.Length, flags);
            if (rc == 0) { return null; }
            if (rc >= (uint)buf.Length)
            {
                // rc = tamanho necessario INCLUINDO o terminador NUL quando o buffer e' pequeno.
                buf = new char[checked((int)rc) + 1];
                rc = GetFinalPathNameByHandleW(h, buf, (uint)buf.Length, flags);
                if (rc == 0 || rc >= (uint)buf.Length) { return null; }
            }
            return new string(buf, 0, (int)rc);
        }

        // \\?\Volume{GUID}\resto  ->  X:\resto  via mount point montado para o volume.
        private static string ResolveGuidVolumeToDos(string guidPath)
        {
            const string p = @"\\?\";
            if (guidPath == null || !guidPath.StartsWith(p, StringComparison.Ordinal)) { return null; }

            int slash = guidPath.IndexOf('\\', p.Length);
            string volName;
            string rest;
            if (slash < 0)
            {
                volName = guidPath + "\\";
                rest = "";
            }
            else
            {
                volName = guidPath.Substring(0, slash) + "\\";   // \\?\Volume{GUID}\
                rest = guidPath.Substring(slash + 1);
            }

            char[] buf = new char[512];
            uint needed;
            if (!GetVolumePathNamesForVolumeNameW(volName, buf, (uint)buf.Length, out needed))
            {
                if (needed == 0) { return null; }
                buf = new char[checked((int)needed)];
                if (!GetVolumePathNamesForVolumeNameW(volName, buf, (uint)buf.Length, out needed)) { return null; }
            }

            int nul = Array.IndexOf(buf, '\0');
            if (nul <= 0) { return null; }
            string mount = new string(buf, 0, nul);   // ex.: "C:\" ou "C:\mnt\folder\"
            if (rest.Length == 0) { return mount; }
            return mount + rest;                       // mount ja termina em '\'
        }

        private static string Normalize(string pth)
        {
            if (pth == null) { return null; }
            if (pth.StartsWith(@"\\?\UNC\", StringComparison.Ordinal))
            {
                pth = @"\\" + pth.Substring(8);
            }
            else if (pth.StartsWith(@"\\?\", StringComparison.Ordinal))
            {
                pth = pth.Substring(4);
            }
            return pth.ToLowerInvariant();
        }
    }
}
