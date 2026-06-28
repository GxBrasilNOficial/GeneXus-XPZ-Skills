# daemon-tcp-persistpy.ps1 - PROTOTIPO DESCARTAVEL (passo 0b: fallback TCP+token).
# Mesma decisao do daemon-pipe-persistpy.ps1 (python persistente + Support.ps1), trocando o
# transporte por TCP loopback com token de sessao. Identidade/ACL/atomicidade do token sao
# SIMPLIFICADAS aqui (so medir transporte); a v1 segue secao 7. Single-thread sincrono.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $DiscoveryFile,
    [Parameter(Mandatory)] [string] $ReadyFile,
    [string] $RepoRoot = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills',
    [Parameter(Mandatory)] [string] $PersistPy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $RepoRoot 'scripts\ClaudeCodePreToolUseSafeAllowSupport.ps1')

$roots = Get-PtuRoots
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
$pythonExe = if ($pythonCmd) { $pythonCmd.Source } else { $null }
if (-not $pythonExe) { throw 'python nao encontrado' }

$pyPsi = [System.Diagnostics.ProcessStartInfo]::new()
$pyPsi.FileName = $pythonExe
[void]$pyPsi.ArgumentList.Add('-u'); [void]$pyPsi.ArgumentList.Add($PersistPy)
$pyPsi.UseShellExecute = $false
$pyPsi.RedirectStandardInput = $true; $pyPsi.RedirectStandardOutput = $true; $pyPsi.RedirectStandardError = $true
$pyPsi.CreateNoWindow = $true
$pyProc = [System.Diagnostics.Process]::Start($pyPsi)
[void]$pyProc.StandardOutput.ReadLine()  # consome {"status":"ready"}

function Invoke-PersistPy { param($Proc, [string] $Command)
    $Proc.StandardInput.WriteLine($Command); $Proc.StandardInput.Flush()
    return $Proc.StandardOutput.ReadLine()
}
function Get-DecisionPersist {
    param([string] $ToolName, [string] $Command, [string] $Cwd, [string[]] $Roots, $PyProc)
    try {
        if (-not (Test-PtuCwdInScope -Cwd $Cwd -Roots $Roots)) { return 'defer' }
        if ($ToolName -cne 'Bash') { return 'defer' }
        if ([string]::IsNullOrWhiteSpace($Command)) { return 'defer' }
        if ((Get-PtuBashFastPath -Command $Command) -eq 'defer') { return 'defer' }
        $json = Invoke-PersistPy -Proc $PyProc -Command $Command
        if ([string]::IsNullOrWhiteSpace($json)) { return 'defer' }
        $parsed = $json | ConvertFrom-Json
        if (-not $parsed -or $parsed.status -ne 'ok') { return 'defer' }
        $segs = @($parsed.segments)
        if ($segs.Count -lt 1) { return 'defer' }
        foreach ($seg in $segs) { if (-not (Test-PtuBashSegmentAllowed @($seg))) { return 'defer' } }
        return 'allow'
    }
    catch { return 'defer' }
}

function Read-Exact { param($Stream, [byte[]] $Buf, [int] $Count)
    $off = 0
    while ($off -lt $Count) { $k = $Stream.Read($Buf, $off, $Count - $off); if ($k -le 0) { throw 'eof' }; $off += $k }
}
function Read-Int32BE { param($Stream)
    $b = New-Object byte[] 4; Read-Exact -Stream $Stream -Buf $b -Count 4
    return ([int]$b[0] -shl 24) -bor ([int]$b[1] -shl 16) -bor ([int]$b[2] -shl 8) -bor [int]$b[3]
}
function Write-FramePayload { param($Stream, [byte] $Magic, [byte[]] $Bytes)
    $Stream.WriteByte($Magic)
    $lenBuf = New-Object byte[] 4; $len = $Bytes.Length
    $lenBuf[0] = [byte](($len -shr 24) -band 0xFF); $lenBuf[1] = [byte](($len -shr 16) -band 0xFF)
    $lenBuf[2] = [byte](($len -shr 8) -band 0xFF); $lenBuf[3] = [byte]($len -band 0xFF)
    $Stream.Write($lenBuf, 0, 4); $Stream.Write($Bytes, 0, $len); $Stream.Flush()
}
function Get-Prop { param($Obj, [string] $Name)
    if ($Obj -and ($Obj.PSObject.Properties.Name -contains $Name)) { return $Obj.$Name }
    return $null
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$token = [guid]::NewGuid().ToString('N')

# Discovery: escrita atomica simplificada (tmp -> move). ACL so-usuario fica para a v1 (secao 7).
$discTmp = "$DiscoveryFile.tmp"
Set-Content -LiteralPath $discTmp -Value ([ordered]@{ port = $port; token = $token } | ConvertTo-Json -Compress) -Encoding ascii
Move-Item -LiteralPath $discTmp -Destination $DiscoveryFile -Force

Set-Content -LiteralPath $ReadyFile -Value 'ready' -Encoding ascii

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $stream.ReadTimeout = 1000
        $decision = 'defer'
        try {
            $magic = $stream.ReadByte()
            if ($magic -ge 0) {
                $tokLen = Read-Int32BE -Stream $stream
                if ($tokLen -ge 0 -and $tokLen -le 256) {
                    $tokBuf = New-Object byte[] $tokLen; Read-Exact -Stream $stream -Buf $tokBuf -Count $tokLen
                    $gotToken = [System.Text.Encoding]::UTF8.GetString($tokBuf)
                    $bodyLen = Read-Int32BE -Stream $stream
                    if ($bodyLen -ge 0 -and $bodyLen -le 65536) {
                        $bodyBuf = New-Object byte[] $bodyLen; Read-Exact -Stream $stream -Buf $bodyBuf -Count $bodyLen
                        if ($gotToken -ceq $token) {
                            $hook = [System.Text.Encoding]::UTF8.GetString($bodyBuf) | ConvertFrom-Json
                            $toolName = [string](Get-Prop $hook 'tool_name')
                            $cwd = [string](Get-Prop $hook 'cwd')
                            $toolInput = Get-Prop $hook 'tool_input'
                            $command = [string](Get-Prop $toolInput 'command')
                            $decision = Get-DecisionPersist -ToolName $toolName -Command $command -Cwd $cwd -Roots $roots -PyProc $pyProc
                        }
                    }
                }
            }
        }
        catch { $decision = 'defer' }
        try { Write-FramePayload -Stream $stream -Magic 0x01 -Bytes ([System.Text.Encoding]::UTF8.GetBytes($decision)) } catch { }
    }
    finally { $client.Dispose() }
}
