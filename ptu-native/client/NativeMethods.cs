// NativeMethods.cs - P/Invokes do cliente NativeAOT do hook PreToolUse (auto-allow) do Claude Code.
// PASSO D. AOT-safe: so DllImport, sem reflexao. Dois grupos:
//   (1) SID do usuario corrente via token do processo (advapi32) -- paridade byte-a-byte com
//       [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value do lado PowerShell
//       (Get-PtuCurrentUserSid em ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1), sem arrastar
//       o assembly System.Security.Principal.Windows para o binario.
//   (2) WaitNamedPipeW: distingue "canal ausente" (ERROR_FILE_NOT_FOUND, retorna na hora) de
//       "existe-porem-ocupado" (timeout) -- usado pelo dispara-e-sai (§5(b)) para respeitar o
//       orcamento quente-XOR-frio sem gastar o deadline num connect cego.
using System;
using System.Runtime.InteropServices;

namespace Ptu.Client
{
    internal static class NativeMethods
    {
        internal const uint TOKEN_QUERY = 0x0008;
        internal const int  TokenUser   = 1;   // TOKEN_INFORMATION_CLASS.TokenUser

        internal const int ERROR_FILE_NOT_FOUND = 2;
        internal const int ERROR_SEM_TIMEOUT    = 121;

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern IntPtr GetCurrentProcess();

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetTokenInformation(
            IntPtr TokenHandle, int TokenInformationClass, IntPtr TokenInformation,
            int TokenInformationLength, out int ReturnLength);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool ConvertSidToStringSidW(IntPtr Sid, out IntPtr StringSid);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern IntPtr LocalFree(IntPtr hMem);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool WaitNamedPipeW(string lpNamedPipeName, uint nTimeOut);

        // SID string ("S-1-5-21-...") do usuario corrente, ou null em qualquer falha (fail-closed).
        // TOKEN_USER comeca por SID_AND_ATTRIBUTES, cujo 1o campo e' o ponteiro do SID; em qualquer
        // arquitetura, o 1o IntPtr do buffer aponta o SID -> Marshal.ReadIntPtr(buffer).
        internal static string GetCurrentUserSid()
        {
            IntPtr token  = IntPtr.Zero;
            IntPtr buffer = IntPtr.Zero;
            IntPtr strSid = IntPtr.Zero;
            try
            {
                if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, out token)) { return null; }
                int len;
                GetTokenInformation(token, TokenUser, IntPtr.Zero, 0, out len);   // 1a chamada: tamanho
                if (len <= 0) { return null; }
                buffer = Marshal.AllocHGlobal(len);
                if (!GetTokenInformation(token, TokenUser, buffer, len, out len)) { return null; }
                IntPtr sidPtr = Marshal.ReadIntPtr(buffer);   // TOKEN_USER.User.Sid
                if (sidPtr == IntPtr.Zero) { return null; }
                if (!ConvertSidToStringSidW(sidPtr, out strSid)) { return null; }
                return Marshal.PtrToStringUni(strSid);
            }
            catch { return null; }
            finally
            {
                if (strSid != IntPtr.Zero) { LocalFree(strSid); }
                if (buffer != IntPtr.Zero) { Marshal.FreeHGlobal(buffer); }
                if (token  != IntPtr.Zero) { CloseHandle(token); }
            }
        }
    }
}
