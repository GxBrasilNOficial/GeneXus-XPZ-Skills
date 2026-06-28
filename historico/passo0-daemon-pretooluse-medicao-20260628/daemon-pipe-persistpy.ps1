# daemon-pipe-persistpy.ps1 - PROTOTIPO DESCARTAVEL (passo 0b / gargalo B: opcao 4.1(b)).
# Igual ao daemon-pipe.ps1, mas segura UM python persistente (shlex-persistent.py) vivo e, no
# caminho allow, troca o spawn-por-requisicao por um round-trip ao python ja no ar. O veredito
# (fast-path + Test-Ptu*SegmentAllowed) reusa as funcoes do Support.ps1 (fonte unica do verdito).
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $PipeName,
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

# Sobe o python persistente UMA vez.
$pyPsi = [System.Diagnostics.ProcessStartInfo]::new()
$pyPsi.FileName = $pythonExe
[void]$pyPsi.ArgumentList.Add('-u')
[void]$pyPsi.ArgumentList.Add($PersistPy)
$pyPsi.UseShellExecute = $false
$pyPsi.RedirectStandardInput = $true
$pyPsi.RedirectStandardOutput = $true
$pyPsi.RedirectStandardError = $true
$pyPsi.CreateNoWindow = $true
$pyProc = [System.Diagnostics.Process]::Start($pyPsi)
[void]$pyProc.StandardOutput.ReadLine()  # consome o {"status":"ready"}

function Invoke-PersistPy { param($Proc, [string] $Command)
    $Proc.StandardInput.WriteLine($Command)
    $Proc.StandardInput.Flush()
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
function Read-FramePayload { param($Stream)
    $magic = $Stream.ReadByte(); if ($magic -lt 0) { return $null }
    $lenBuf = New-Object byte[] 4; Read-Exact -Stream $Stream -Buf $lenBuf -Count 4
    $n = ([int]$lenBuf[0] -shl 24) -bor ([int]$lenBuf[1] -shl 16) -bor ([int]$lenBuf[2] -shl 8) -bor [int]$lenBuf[3]
    if ($n -lt 0 -or $n -gt 65536) { throw 'bad len' }
    $buf = New-Object byte[] $n; Read-Exact -Stream $Stream -Buf $buf -Count $n
    return , $buf
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

Set-Content -LiteralPath $ReadyFile -Value 'ready' -Encoding ascii

while ($true) {
    $server = New-Object System.IO.Pipes.NamedPipeServerStream(
        $PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::None)
    try {
        $server.WaitForConnection()
        $decision = 'defer'
        try {
            $reqBytes = Read-FramePayload -Stream $server
            if ($null -ne $reqBytes) {
                $hook = [System.Text.Encoding]::UTF8.GetString($reqBytes) | ConvertFrom-Json
                $toolName = [string](Get-Prop $hook 'tool_name')
                $cwd = [string](Get-Prop $hook 'cwd')
                $toolInput = Get-Prop $hook 'tool_input'
                $command = [string](Get-Prop $toolInput 'command')
                $decision = Get-DecisionPersist -ToolName $toolName -Command $command -Cwd $cwd -Roots $roots -PyProc $pyProc
            }
        }
        catch { $decision = 'defer' }
        try { Write-FramePayload -Stream $server -Magic 0x01 -Bytes ([System.Text.Encoding]::UTF8.GetBytes($decision)) } catch { }
    }
    finally { $server.Dispose() }
}
