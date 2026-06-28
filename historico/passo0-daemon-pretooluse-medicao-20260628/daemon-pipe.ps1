# daemon-pipe.ps1 - PROTOTIPO DESCARTAVEL (passo 0b: daemon persistente, named pipe).
# Dot-source do Support.ps1 UMA vez, abre o pipe so apos pronto (ready), e entra em loop
# sincrono single-thread: aceita conexao, le frame, Get-PtuDecision, devolve o enum.
# NAO eh a v1: identidade simplificada (nome fixo), sem mutex/staleness/ACL. So mede latencia.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $PipeName,
    [Parameter(Mandatory)] [string] $ReadyFile,
    [string] $RepoRoot = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $RepoRoot 'scripts\ClaudeCodePreToolUseSafeAllowSupport.ps1')

$roots = Get-PtuRoots
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
$pythonExe = if ($pythonCmd) { $pythonCmd.Source } else { $null }
$helperPath = Join-Path $RepoRoot 'scripts\Get-ClaudeCodeBashSafeSegments.py'

function Read-Exact { param($Stream, [byte[]] $Buf, [int] $Count)
    $off = 0
    while ($off -lt $Count) {
        $k = $Stream.Read($Buf, $off, $Count - $off)
        if ($k -le 0) { throw 'eof' }
        $off += $k
    }
}
function Read-FramePayload { param($Stream)
    $magic = $Stream.ReadByte()
    if ($magic -lt 0) { return $null }
    $lenBuf = New-Object byte[] 4
    Read-Exact -Stream $Stream -Buf $lenBuf -Count 4
    $n = ([int]$lenBuf[0] -shl 24) -bor ([int]$lenBuf[1] -shl 16) -bor ([int]$lenBuf[2] -shl 8) -bor [int]$lenBuf[3]
    if ($n -lt 0 -or $n -gt 65536) { throw 'bad len' }
    $buf = New-Object byte[] $n
    Read-Exact -Stream $Stream -Buf $buf -Count $n
    return , $buf
}
function Write-FramePayload { param($Stream, [byte] $Magic, [byte[]] $Bytes)
    $Stream.WriteByte($Magic)
    $lenBuf = New-Object byte[] 4
    $len = $Bytes.Length
    $lenBuf[0] = [byte](($len -shr 24) -band 0xFF)
    $lenBuf[1] = [byte](($len -shr 16) -band 0xFF)
    $lenBuf[2] = [byte](($len -shr 8) -band 0xFF)
    $lenBuf[3] = [byte]($len -band 0xFF)
    $Stream.Write($lenBuf, 0, 4)
    $Stream.Write($Bytes, 0, $len)
    $Stream.Flush()
}
function Get-Prop { param($Obj, [string] $Name)
    if ($Obj -and ($Obj.PSObject.Properties.Name -contains $Name)) { return $Obj.$Name }
    return $null
}

# Pronto: so agora sinaliza (o "canal so existe apos ready" do design e simplificado aqui
# para a medicao - o pipe e criado por conexao, mas o ready marca dot-source OK).
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
                $json = [System.Text.Encoding]::UTF8.GetString($reqBytes)
                $hook = $json | ConvertFrom-Json
                $toolName = [string](Get-Prop $hook 'tool_name')
                $cwd = [string](Get-Prop $hook 'cwd')
                $toolInput = Get-Prop $hook 'tool_input'
                $command = [string](Get-Prop $toolInput 'command')
                $decision = Get-PtuDecision -ToolName $toolName -Command $command -Cwd $cwd -Roots $roots -PythonExe $pythonExe -HelperPath $helperPath
            }
        }
        catch { $decision = 'defer' }
        try { Write-FramePayload -Stream $server -Magic 0x01 -Bytes ([System.Text.Encoding]::UTF8.GetBytes($decision)) } catch { }
    }
    finally { $server.Dispose() }
}
