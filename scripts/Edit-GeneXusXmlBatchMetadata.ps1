#requires -Version 7.4
<#
.SYNOPSIS
    Edicao em lote de metadados de XML GeneXus dirigida por manifesto, com
    verificacao contra a realidade do XML antes de tocar em disco.

.DESCRIPTION
    Implementa o desenho congelado v10 (edit-genexus-xml-batch-metadata-design.md).
    Separa a DECLARACAO (manifesto JSON) da EXECUCAO: o motor confere cada
    precondicao declarada contra o arquivo real, planeja tudo em memoria e so
    entao grava, com journal, backup e rollback.

    Sem -Apply, a rodada termina no plano e NAO deixa artefato persistente
    (o lock e transitorio).

    O nucleo vive em GeneXusXmlBatchMetadataSupport.ps1; este wrapper e a
    superficie de linha de comando e o contrato de saida.

.PARAMETER InputPath
    Manifesto JSON (Kind = xpz-batch-metadata-manifest). Aliases -Path e
    -ManifestPath. Ressalva semantica: aqui a entrada primaria e um manifesto
    JSON, nao um XML; -Path e alias de consistencia de familia.

.PARAMETER FrontFolder
    Frente canonica sob ObjetosGeradosParaImportacaoNaKbNoGenexus.

.PARAMETER AcervoPath
    Acervo de XMLs da KB. Default: <RepoRoot>/ObjetosDaKbEmXml.

.PARAMETER WorkDir
    Diretorio de artefatos da rodada (journal, .bak, baseline sintetico, lock).
    ESTAVEL POR FRENTE, nao por execucao - o lock precisa de local compartilhado
    para que dois processos se enxerguem.
    Default: <RepoRoot>/Temp/xpz-batch-metadata/<NomeDaFrente>.

.PARAMETER Apply
    Aplica o plano. Sem ele, so planeja.

.PARAMETER ReportPath
    Caminho absoluto .json para gravar o relatorio. O JSON de maquina sai no
    stdout por padrao, SEMPRE - inclusive quando a gravacao aqui falhar.

    Relacao com a promessa de "nenhum artefato persistente" sem -Apply: a
    promessa cobre os artefatos que o MOTOR cria por conta propria - journal,
    .bak, baseline sintetico, temporarios de escrita e o -WorkDir que ele
    tenha criado. O relatorio nao e artefato do motor: e saida que o chamador
    pediu explicitamente, num caminho que ele mesmo deu, do mesmo modo que o
    JSON do stdout. Rodada sem -Apply com -ReportPath grava o relatorio e
    NADA mais - isso e verificado por caso proprio na bateria de contrato.

    O caminho passa pela mesma familia de guardas dos demais (D2): absoluto,
    terminado em .json, fora da frente e do -WorkDir, fora de area protegida,
    sem ponto de reanalise no caminho, pasta pai existente e, quando ja
    existir, arquivo regular. Recusado o caminho, o motor bloqueia e o
    relatorio sai apenas no stdout.

.PARAMETER AcknowledgeReferences
    Registra aceitacao do limite de cobertura da varredura de referencias. NAO
    transforma medicao incompleta em autorizacao.

.PARAMETER RequireHeadWitness
    Torna bloqueio a indisponibilidade da testemunha de HEAD.

.PARAMETER AllowDegradedAccents
    Habilita a excecao por operacao (allowDegradedAccents no manifesto). Nunca
    concede a excecao sozinho.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path', 'ManifestPath')]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [string]$AcervoPath,

    [string]$WorkDir,

    [switch]$Apply,

    [string]$ReportPath,

    [switch]$AcknowledgeReferences,

    [switch]$RequireHeadWitness,

    [switch]$AllowDegradedAccents
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusXmlBatchMetadataSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusXmlBatchMetadataSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

function Get-GeneXusBatchExitCode {
    param([Parameter(Mandatory = $true)][string]$Status)

    if ($Status -eq 'blocked') { return 20 }
    if ($Status -eq 'rollbackComplete') { return 25 }
    if ($Status -eq 'rollbackIncomplete') { return 30 }
    if ($Status -eq 'partiallyApplied') { return 35 }
    return 0
}

$report = $null
try {
    $report = Invoke-GeneXusXmlBatchMetadataCore `
        -InputPath $InputPath `
        -FrontFolder $FrontFolder `
        -AcervoPath $AcervoPath `
        -WorkDir $WorkDir `
        -Apply:$Apply.IsPresent `
        -ReportPath $ReportPath `
        -AcknowledgeReferences:$AcknowledgeReferences.IsPresent `
        -RequireHeadWitness:$RequireHeadWitness.IsPresent `
        -AllowDegradedAccents:$AllowDegradedAccents.IsPresent
} catch {
    $report = [ordered]@{
        Kind          = 'xpz-batch-metadata-report'
        SchemaVersion = 1
        runId         = $null
        status        = 'internalError'
        phase         = 'unknown'
        atUtc         = [DateTime]::UtcNow.ToString('o')
        blocks        = @([ordered]@{ code = 'INTERNAL_ERROR'; message = $_.Exception.Message; opId = $null; path = $null; detail = $null })
        warnings      = @()
        files         = @()
    }
    $json = ($report | ConvertTo-Json -Depth 20)
    Write-Output $json
    exit 90
}

$json = ($report | ConvertTo-Json -Depth 20)

# O motor valida o -ReportPath com a mesma familia de guardas dos demais
# caminhos e sinaliza a recusa em reportPathRefused. Gravar assim mesmo seria
# escrever justamente no caminho que o motor acabou de recusar.
$reportPathRefused = $true
if ($null -ne $report['reportPathRefused']) {
    $reportPathRefused = [bool]$report['reportPathRefused']
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath) -and -not $reportPathRefused) {
    try {
        $reportDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($ReportPath))
        if (-not (Test-Path -LiteralPath $reportDirectory -PathType Container)) {
            throw "pasta do -ReportPath nao existe: $reportDirectory"
        }
        [void](Write-XpzTextFileAtomic -Path ([System.IO.Path]::GetFullPath($ReportPath)) -Text $json -TempDir $reportDirectory -ReplaceExisting)
    } catch {
        # O stdout e a fonte que sempre existe; a falha de gravacao vira aviso
        # no proprio relatorio, nunca motivo para suprimir a saida.
        $report['warnings'] = @(@($report['warnings']) + @([ordered]@{
            kind    = 'reportPathWriteFailed'
            message = $_.Exception.Message
            opId    = $null
            path    = $ReportPath
            detail  = $null
        }))
        $json = ($report | ConvertTo-Json -Depth 20)
    }
}

Write-Output $json
exit (Get-GeneXusBatchExitCode -Status ([string]$report['status']))
