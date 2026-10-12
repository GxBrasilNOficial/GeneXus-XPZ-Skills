#requires -Version 7.4

<#
.SYNOPSIS
    Monitor incremental de execução headless de MSBuild/GeneXus.

.DESCRIPTION
    Acompanha o processo informado durante uma execução MSBuild/GeneXus:
    le o log incrementalmente,
    destaca fases relevantes do GeneXus, detecta silencio prolongado e
    encerra automaticamente quando o processo termina.

    Não depende do chat para polling — roda como processo independente no
    terminal do Windows. Recomenda-se iniciar com -NoExit para que a janela
    permita ao usuário ler o output após a execução e fecha-la manualmente.

    Fases destacadas: Open, Specify, Generate, Compile, BuildAll, Reorgan/Reorg,
    Validating subtype group, Close.

    Durante periodos sem nova linha no log, exibe um contador de silencio
    in-place (sobrescrevendo a última linha da tela com \r) — sem gerar nova
    linha a cada poll. Apenas fases, alertas e mensagens de estado geram linhas
    novas. O arquivo -MonitorLog não recebe o contador de silencio.

    Quando usado por um wrapper MSBuild compativel, passar o mesmo caminho como
    -MonitorLog aqui e -MonitorLogPath no wrapper permite que o JSON de resultado
    inclua timing.phases com duracao de cada fase interna. Esse contrato vale para
    Invoke-GeneXusKbBuildAll.ps1, Invoke-GeneXusKbSpecifyGenerate.ps1,
    Test-GeneXusXpzImportPreview.ps1, Invoke-GeneXusXpzExport.ps1 e
    Invoke-GeneXusXpzImport.ps1.

.PARAMETER ProcessId
    PID do processo cuja vida delimita o monitoramento. Quando iniciado por um
    wrapper compativel, e o PID do próprio wrapper que conduz a execução MSBuild.
    Alias: -Pid.

.PARAMETER LogPath
    Caminho do arquivo de log a ler incrementalmente (ex: msbuild.stdout.log).
    O script aguarda ate 30 segundos pelo arquivo, caso ainda não exista.

.PARAMETER MonitorLog
    Caminho opcional para gravar o log próprio do monitor.
    A pasta pai e criada automaticamente se não existir.

.PARAMETER IntervalSeconds
    Intervalo de polling em segundos. Padrão: 5. Intervalo valido: 1-60.

.PARAMETER SilenceThresholdSeconds
    Segundos sem nova linha no log antes de emitir alerta de silencio.
    Padrão: 120. Intervalo valido: 30-3600.

.EXAMPLE
    .\Watch-GeneXusMsBuildLog.ps1 -Pid 12345 -LogPath "C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-exemplo\msbuild.stdout.log"

.EXAMPLE
    # Iniciado pelo agente com -NoExit para janela ficar aberta após a execução:
    Start-Process pwsh -ArgumentList @(
        '-NoExit', '-NoProfile', '-File', '.\Watch-GeneXusMsBuildLog.ps1',
        '-Pid', '12345',
        '-LogPath',    'C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-exemplo\msbuild.stdout.log',
        '-MonitorLog', 'C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\xpz-build-exemplo\monitor.log',
        '-IntervalSeconds', '5',
        '-SilenceThresholdSeconds', '180'
    )

.NOTES
    Não usar C:\Temp\ como destino de LogPath ou MonitorLog quando o script e
    iniciado como processo filho desanexado (Start-Process) — processos filhos
    não tem acesso de escrita a C:\Temp\ neste ambiente. Usar pasta sob o
    repositório da skill (ex.: GeneXus-XPZ-Skills\Temp\).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Pid')]
    [int]$ProcessId,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$MonitorLog,

    [ValidateRange(1, 60)]
    [int]$IntervalSeconds = 5,

    [ValidateRange(30, 3600)]
    [int]$SilenceThresholdSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Padrões de fase GeneXus ───────────────────────────────────────────────────
# Ordem importa: mais específicos primeiro para evitar sobreposicao.

$script:phasePatterns = @(
    [pscustomobject]@{ Regex = 'Validating subtype group'; Color = 'Cyan' }
    [pscustomobject]@{ Regex = 'Open.*Knowledge|Knowledge.*Open'; Color = 'Cyan' }
    [pscustomobject]@{ Regex = 'Close.*Knowledge|Knowledge.*Close'; Color = 'Cyan' }
    [pscustomobject]@{ Regex = 'Reorgani[sz]|Reorg'; Color = 'Red' }
    [pscustomobject]@{ Regex = 'Specify'; Color = 'Yellow' }
    [pscustomobject]@{ Regex = 'Generat'; Color = 'Yellow' }
    [pscustomobject]@{ Regex = 'Compil'; Color = 'Yellow' }
    [pscustomobject]@{ Regex = 'BuildAll|Build All'; Color = 'Yellow' }
)

# ── Estado do monitor ─────────────────────────────────────────────────────────

$script:monitorStream    = $null
$script:statusLineActive = $false   # true enquanto a linha de silencio está na tela sem \n

# ── Helpers ───────────────────────────────────────────────────────────────────

function Confirm-StatusLine {
    # Se ha uma linha de status ao vivo (sem \n), fecha-a antes de imprimir conteúdo real.
    if ($script:statusLineActive) {
        Write-Host ''
        $script:statusLineActive = $false
    }
}

function Write-Status {
    # Imprime/atualiza a linha de silencio in-place no console. Não vai para o arquivo.
    param([string]$Message, [string]$Color = 'DarkGray')
    $line    = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    $padded  = $line.PadRight([Math]::Max(0, [Console]::WindowWidth - 1))
    Write-Host "`r$padded" -NoNewline -ForegroundColor $Color
    $script:statusLineActive = $true
}

function Write-Mon {
    param([string]$Message, [string]$Color = 'Gray')
    Confirm-StatusLine
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    if ($null -ne $script:monitorStream) {
        $script:monitorStream.WriteLine($line)
        $script:monitorStream.Flush()
    }
}

function Get-PhaseColor {
    param([string]$Line)
    foreach ($p in $script:phasePatterns) {
        if ($Line -imatch $p.Regex) { return $p.Color }
    }
    return $null
}

function Read-NewLines {
    param([ref]$Offset)
    $collected = [System.Collections.Generic.List[string]]::new()
    try {
        $fs = [System.IO.FileStream]::new(
            $LogPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        [void]$fs.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin)
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        $l = $reader.ReadLine()
        while ($null -ne $l) {
            $collected.Add($l)
            $l = $reader.ReadLine()
        }
        $Offset.Value = $fs.Position
        $reader.Dispose()
        $fs.Dispose()
    } catch {
        Write-Mon "AVISO: Falha ao ler log: $($_.Exception.Message)" 'DarkYellow'
    }
    # PowerShell enumera a lista; o chamador usa @() para coletar como array.
    $collected
}

function Emit-Lines {
    param([string[]]$Lines)
    foreach ($l in $Lines) {
        $color = Get-PhaseColor $l
        if ($null -ne $color) {
            Write-Mon $l $color
        } else {
            Write-Mon $l 'Gray'
        }
    }
}

# ── Inicializar log do monitor ────────────────────────────────────────────────

if (-not [string]::IsNullOrWhiteSpace($MonitorLog)) {
    $monDir = Split-Path -Parent $MonitorLog
    if (-not [string]::IsNullOrWhiteSpace($monDir) -and
        -not (Test-Path -LiteralPath $monDir -PathType Container)) {
        New-Item -Path $monDir -ItemType Directory -Force | Out-Null
    }
    $script:monitorStream = [System.IO.StreamWriter]::new(
        $MonitorLog, $true, [System.Text.Encoding]::UTF8
    )
}

# ── Header de inicio ──────────────────────────────────────────────────────────

# Paliativo anti-acidente do fluxo de janela visivel: sinaliza que fechar esta janela
# derruba o build em andamento. NAO impede o fechamento — o Windows encerra os processos
# anexados a console ~5s apos o CTRL_CLOSE. Para robustez real contra fechamento de janela
# ou do app, usar o modo desacoplado (Start-GeneXusKbBuildDetached.ps1).
try {
    if ($null -ne $Host -and $null -ne $Host.UI -and $null -ne $Host.UI.RawUI) {
        $Host.UI.RawUI.WindowTitle = 'BUILD GeneXus EM ANDAMENTO — NÃO FECHAR esta janela'
    }
} catch {
    # Host sem RawUI (execucao redirecionada): titulo nao se aplica, segue sem ele.
}

Write-Mon '─── Watch-GeneXusMsBuildLog ─────────────────────────────────────' 'White'
Write-Mon 'AVISO: NÃO FECHAR esta janela enquanto o build estiver em andamento.'        'Red'
Write-Mon '       Fechar derruba o build (wrapper + MSBuild + GeneXus) sem erro no log.' 'Red'
Write-Mon '       Para build longo robusto a fechamento, prefira o modo desacoplado'    'Red'
Write-Mon '       (Start-GeneXusKbBuildDetached.ps1).'                                  'Red'
Write-Mon "  ProcessId            : $ProcessId"                               'White'
Write-Mon "  LogPath              : $LogPath"                                 'White'
Write-Mon "  IntervalSeconds      : $IntervalSeconds"                         'White'
Write-Mon "  SilenceThreshold     : ${SilenceThresholdSeconds}s"              'White'
if (-not [string]::IsNullOrWhiteSpace($MonitorLog)) {
    Write-Mon "  MonitorLog           : $MonitorLog" 'White'
}
Write-Mon '─────────────────────────────────────────────────────────────────' 'White'

# ── Verificar processo no inicio ──────────────────────────────────────────────

$checkProc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
if (-not $checkProc) {
    Write-Mon "AVISO: PID $ProcessId nao localizado no inicio. Processo pode ter encerrado antes do monitor." 'Yellow'
}

# ── Aguardar log aparecer (ate 30s) ──────────────────────────────────────────

$waitInterval = [Math]::Min($IntervalSeconds, 5)
$waited       = 0
while (-not (Test-Path -LiteralPath $LogPath -PathType Leaf) -and $waited -lt 30) {
    Write-Mon "Aguardando log: $LogPath" 'DarkGray'
    Start-Sleep -Seconds $waitInterval
    $waited += $waitInterval
}

if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
    Write-Mon "ERRO: Log nao encontrado apos ${waited}s. Encerrando." 'Red'
    if ($null -ne $script:monitorStream) { $script:monitorStream.Close() }
    exit 1
}

Write-Mon 'Log localizado. Monitoramento iniciado.' 'Green'

# ── Loop principal ────────────────────────────────────────────────────────────

$fileOffset     = [long]0
$lastActivity   = [DateTime]::Now
$silenceAlerted = $false

try {
    :monitorLoop while ($true) {
        $isAlive = $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)

        $lines = @(Read-NewLines -Offset ([ref]$fileOffset))

        if ($lines.Count -gt 0) {
            $lastActivity   = [DateTime]::Now
            $silenceAlerted = $false
            Emit-Lines $lines
        } else {
            $silenceSec = [int]([DateTime]::Now - $lastActivity).TotalSeconds
            if ($silenceSec -ge $SilenceThresholdSeconds -and -not $silenceAlerted) {
                $silenceAlerted = $true
                $procStatus = if ($isAlive) { "processo PID $ProcessId ativo" } else { "processo NAO localizado" }
                Write-Mon "SILENCIO ha ${SilenceThresholdSeconds}s — $procStatus" 'DarkYellow'
            } else {
                $procLabel = if ($isAlive) { 'ativo' } else { 'encerrado' }
                Write-Status "PID $ProcessId $procLabel | sem novas linhas | silencio: ${silenceSec}s"
            }
        }

        if (-not $isAlive) {
            # Drena o que restar no log antes de encerrar
            Start-Sleep -Seconds 2
            $tail = @(Read-NewLines -Offset ([ref]$fileOffset))
            if ($tail.Count -gt 0) {
                Write-Mon '── Drenagem final do log ──' 'DarkGray'
                Emit-Lines $tail
            }
            Write-Mon "Processo PID $ProcessId encerrado. Monitoramento concluido." 'Green'
            break monitorLoop
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    if ($null -ne $script:monitorStream) {
        $script:monitorStream.Close()
    }
}

exit 0
