#requires -Version 7.4
<#
.SYNOPSIS
    Roteiro de recuperacao manual a partir do journal de
    Edit-GeneXusXmlBatchMetadata.ps1.

.DESCRIPTION
    Le o journal de uma rodada e DIZ o que restaurar. Nao restaura nada: a
    recuperacao e ato humano, e este roteiro existe justamente porque morte de
    processo, queda de energia ou falha de I/O durante a restauracao deixam
    estado que o rollback automatico ja nao alcanca.

    O que ele reconhece:

      - passo 'started' sem 'committed' correspondente = a marca de
        interrupcao. O alvo desse passo pode estar em qualquer dos dois
        estados, e o .bak e a referencia;
      - renomes sao desfeitos em ORDEM INVERSA, antes de restaurar os .bak - a
        mesma ordem do rollback automatico. O roteiro ja emite a lista nessa
        ordem;
      - para cada restauracao, o hash gravado no journal permite conferir o
        resultado.

.PARAMETER JournalPath
    Caminho do arquivo <runId>.journal.json em -WorkDir.

.PARAMETER AsJson
    Saida estruturada em JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$JournalPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $JournalPath -PathType Leaf)) {
    throw "Journal nao encontrado: $JournalPath"
}

$journal = [System.IO.File]::ReadAllText($JournalPath) | ConvertFrom-Json
if ($journal.Kind -ne 'xpz-batch-metadata-journal') {
    throw "Arquivo nao e um journal de edicao em lote: Kind='$($journal.Kind)'."
}

$steps = @($journal.steps)
$committed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($step in $steps) {
    if ($step.state -eq 'committed') {
        [void]$committed.Add("$($step.opId)|$($step.action)")
    }
}

$interrupted = [System.Collections.Generic.List[object]]::new()
$renames = [System.Collections.Generic.List[object]]::new()
$restore = [System.Collections.Generic.List[object]]::new()

foreach ($step in $steps) {
    if ($step.state -ne 'started') { continue }
    $key = "$($step.opId)|$($step.action)"
    if (-not $committed.Contains($key)) {
        [void]$interrupted.Add([ordered]@{
            seq    = $step.seq
            opId   = $step.opId
            action = $step.action
            target = $step.pathAfter
        })
    }
}

foreach ($step in $steps) {
    if ($step.action -ne 'rename') { continue }
    if ($step.state -ne 'committed') { continue }
    [void]$renames.Add([ordered]@{
        seq  = $step.seq
        opId = $step.opId
        from = $step.pathAfter
        to   = $step.pathBefore
    })
}
$renamesReversed = @()
if ($renames.Count -gt 0) {
    $renamesReversed = @($renames.ToArray())
    [array]::Reverse($renamesReversed)
}

$seenTargets = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($step in $steps) {
    if ($step.action -ne 'write') { continue }
    if ([string]::IsNullOrWhiteSpace([string]$step.bakPath)) { continue }
    if (-not $seenTargets.Add([string]$step.pathBefore)) { continue }
    [void]$restore.Add([ordered]@{
        opId          = $step.opId
        target        = $step.pathBefore
        bakPath       = $step.bakPath
        bakPresent    = (Test-Path -LiteralPath ([string]$step.bakPath) -PathType Leaf)
        hashBefore    = $step.hashBefore
        hashAfter     = $step.hashAfter
        writeCommitted = $committed.Contains("$($step.opId)|write")
    })
}

$status = 'complete'
if ($interrupted.Count -gt 0) { $status = 'interrupted' }

$plan = [ordered]@{
    Kind          = 'xpz-batch-metadata-recovery-plan'
    SchemaVersion = 1
    runId         = $journal.runId
    journalPath   = [System.IO.Path]::GetFullPath($JournalPath)
    workDir       = $journal.workDir
    status        = $status
    stepCount     = $steps.Count
    interrupted   = @($interrupted)
    undoRenames   = @($renamesReversed)
    restore       = @($restore)
}

if ($AsJson) {
    $plan | ConvertTo-Json -Depth 10
    exit 0
}

Write-Output "ROTEIRO DE RECUPERACAO - runId $($journal.runId)"
Write-Output "  journal : $($plan.journalPath)"
Write-Output "  workDir : $($journal.workDir)"
Write-Output "  estado  : $status ($($steps.Count) passo(s) registrado(s))"
Write-Output ''

if ($interrupted.Count -gt 0) {
    Write-Output 'PASSOS INTERROMPIDOS (started sem committed):'
    foreach ($entry in $interrupted) {
        Write-Output ("  seq {0} [{1}] {2} -> {3}" -f $entry.seq, $entry.opId, $entry.action, $entry.target)
    }
    Write-Output ''
}

if ($renamesReversed.Count -gt 0) {
    Write-Output '1) DESFAZER RENOMES, NESTA ORDEM:'
    foreach ($entry in $renamesReversed) {
        Write-Output ("  mover  {0}" -f $entry.from)
        Write-Output ("     para {0}" -f $entry.to)
    }
    Write-Output ''
}

Write-Output '2) RESTAURAR OS .bak (depois dos renomes):'
foreach ($entry in $restore) {
    $presenca = 'ausente'
    if ($entry.bakPresent) { $presenca = 'presente' }
    Write-Output ("  copiar {0} ({1})" -f $entry.bakPath, $presenca)
    Write-Output ("     para {0}" -f $entry.target)
    if (-not [string]::IsNullOrWhiteSpace([string]$entry.hashBefore)) {
        Write-Output ("     conferir sha256 = {0}" -f $entry.hashBefore)
    }
}
Write-Output ''
Write-Output 'Nao apague os .bak antes de conferir o hash de cada restauracao.'
exit 0
