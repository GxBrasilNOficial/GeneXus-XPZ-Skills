#requires -Version 7.4
<#
.SYNOPSIS
    Resolve o caminho direto do .cs gerado por objeto GeneXus a partir do metadata da pasta paralela.

.DESCRIPTION
    Le kb-source-metadata.md, resolve o environment operacional e usa o mapeamento
    kb_environment_web_dirs para montar <webDir>\<objectName-lowercase>.cs sem varredura
    recursiva da KB nativa.

    Se o metadata não tiver mapeamento de output/web por environment, bloqueia e orienta
    reconciliar a pasta paralela via xpz-kb-parallel-setup.

.PARAMETER KbPath
    Caminho da KB nativa GeneXus. Usado para contexto e validação leve; o webDir vem do metadata.

.PARAMETER ObjectName
    Nome do objeto GeneXus.

.PARAMETER ObjectType
    Tipo do objeto GeneXus. Campo informativo reservado para diagnostico.

.PARAMETER EnvironmentName
    Environment GeneXus a resolver. Se omitido, usa deployment_environment_name; em KB
    single-environment, usa o único nome em kb_environment_names.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela da KB para resolver kb-source-metadata.md.

.PARAMETER KbMetadataPath
    Caminho explicito para kb-source-metadata.md.

.PARAMETER AsJson
    Emite saida JSON estruturada.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$ObjectName,

    [string]$ObjectType,

    [string]$EnvironmentName,

    [string]$ParallelKbRoot,

    [string]$KbMetadataPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')
# Fase 2 (paridade Java/Tomcat): registro-fonte-unica dos hosting kinds (guarda de familia do Eixo B).
. (Join-Path $PSScriptRoot 'GeneXusKbHostingKindSupport.ps1')

function New-BlockedResult {
    param(
        [string]$Reason,
        [string]$MetadataPath
    )

    return [ordered]@{
        status             = 'BLOCK'
        reason             = $Reason
        kbPath             = $KbPath
        metadataPath       = $MetadataPath
        objectName         = $ObjectName
        objectType         = $ObjectType
        environmentName    = $EnvironmentName
        nextStep           = 'Executar xpz-kb-parallel-setup para reconciliar kb-source-metadata.md com kb_environment_output_dirs e kb_environment_web_dirs.'
    }
}

# Fase 2: construtor dedicado do ramo INVALIDO da guarda de familia. Espelha a shape COMPLETA do BLOCK
# (paridade com New-BlockedResult e com o skip abaixo), sobrescrevendo reason, nextStep (proprio de
# hosting_kind — NAO o texto de web_dirs) e environmentName = $ResolvedEnvironment (nao o param cru).
function New-InvalidHostingKindResult {
    param(
        [string]$Reason,
        [string]$MetadataPath,
        [string]$ResolvedEnvironment
    )

    return [ordered]@{
        status             = 'BLOCK'
        reason             = $Reason
        kbPath             = $KbPath
        metadataPath       = $MetadataPath
        objectName         = $ObjectName
        objectType         = $ObjectType
        environmentName    = $ResolvedEnvironment
        nextStep           = 'Corrigir deployment_hosting_kind em kb-source-metadata.md para um valor reconhecido, ou regravar via Set-XpzKbSourceMetadataDeployment.ps1.'
    }
}

# Fase 2: construtor do ramo SKIP (hosting kind reconhecido-sem-motor). exit 0 (skip != erro != resolucao);
# shape completa, com environmentName resolvido, deploymentHostingKind/family, e SEM csPath (o artefato Java
# nao e .cs; o motor Eixo B/C e Pos-v1). status em MAIUSCULAS/underscore — NAO casa o regex de skip da §8.
function New-SkippedJavaResult {
    param(
        [string]$Reason,
        [string]$MetadataPath,
        [string]$ResolvedEnvironment,
        [string]$DeploymentHostingKind,
        [string]$Family
    )

    return [ordered]@{
        status                = 'CS_PATH_SKIPPED_HOSTING_UNSUPPORTED'
        reason                = $Reason
        kbPath                = $KbPath
        metadataPath          = $MetadataPath
        objectName            = $ObjectName
        objectType            = $ObjectType
        environmentName       = $ResolvedEnvironment
        deploymentHostingKind = $DeploymentHostingKind
        family                = $Family
        readOnly              = $true
        nextStep              = 'Gerador Java/Tomcat reconhecido sem motor de diagnostico de fonte gerado (Eixo B e Pos-v1). Nenhuma acao: o artefato gerado nao e .cs.'
    }
}

$resolvedKbPath = [System.IO.Path]::GetFullPath($KbPath)
$metadataPathResolved = Resolve-GeneXusKbSourceMetadataPath -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot

if ([string]::IsNullOrWhiteSpace($metadataPathResolved)) {
    $blocked = New-BlockedResult -Reason 'KbMetadataPath/ParallelKbRoot ausente; metadata da pasta paralela e obrigatorio para resolver .cs gerado.' -MetadataPath $null
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$metadataPathResolved = [System.IO.Path]::GetFullPath($metadataPathResolved)
$fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $metadataPathResolved
if (-not $fields.MetadataFound) {
    $blocked = New-BlockedResult -Reason "kb-source-metadata.md nao encontrado: $metadataPathResolved" -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$requestedEnvironment = if ([string]::IsNullOrWhiteSpace($EnvironmentName)) { $null } else { $EnvironmentName.Trim() }
$resolvedEnvironment = $null
$environmentSource = $null

if ($requestedEnvironment) {
    $resolvedEnvironment = $requestedEnvironment
    $environmentSource = 'parameter'
} elseif (-not [string]::IsNullOrWhiteSpace($fields.deployment_environment_name)) {
    $resolvedEnvironment = $fields.deployment_environment_name
    $environmentSource = 'deployment_environment_name'
} elseif ($fields.kb_environment_names.Count -eq 1) {
    $resolvedEnvironment = $fields.kb_environment_names[0]
    $environmentSource = 'single_environment_metadata'
} else {
    $blocked = New-BlockedResult -Reason 'EnvironmentName ausente e metadata nao define deployment_environment_name nem KB single-environment.' -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in $fields.kb_environment_names) {
    [void]$known.Add($name)
}

if ($known.Count -gt 0 -and -not $known.Contains($resolvedEnvironment)) {
    $blocked = New-BlockedResult -Reason ("Environment '{0}' nao consta em kb_environment_names ({1})." -f $resolvedEnvironment, ($fields.kb_environment_names -join ', ')) -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

# Fase 2 — guarda de familia (Eixo B). Inserida APOS a resolucao do environment (que da o
# $resolvedEnvironment aos resultados) e ANTES do bloco kb_environment_web_dirs abaixo: o skip Java NAO
# depende de web_dirs (nao roda motor; o design admite topologia Java externa .war/webapp sem web_dirs
# no molde .NET). Guard de vazio T1: so consulta o registro quando deployment_hosting_kind esta PRESENTE;
# vazio/ausente segue o fluxo .cs de hoje (KB .NET/legada sem bloco de deploy NAO regride). Fase 3 (split
# per-eixo): este e o Eixo B (fonte gerado .cs/.java) — discrimina pelo campo DO SEU EIXO
# ($rec.runsSourceEngine), nao pelo alias legado runsFreshnessEngine (que segue o Eixo A e, para Java
# pos-Fase 3, seria 'true' e montaria o .cs indevidamente). Le so family/runsSourceEngine/sourceUnsupportedReason
# — nunca o campo de forma-alvo da Fase 3 (clausula no-bridge).
$hostingKindRaw = $fields.deployment_hosting_kind
if (-not [string]::IsNullOrWhiteSpace($hostingKindRaw)) {
    $hostingRec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $hostingKindRaw
    if ($null -eq $hostingRec) {
        # ramo 1 — presente-e-fora-do-registro: rejeicao canonica (nextStep proprio de hosting_kind).
        $blocked = New-InvalidHostingKindResult `
            -Reason (Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind $hostingKindRaw) `
            -MetadataPath $metadataPathResolved `
            -ResolvedEnvironment $resolvedEnvironment
        if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
        exit 1
    }
    if (-not $hostingRec.runsSourceEngine) {
        # ramo 2 — recognized-no-engine / blocked-out-of-scope no Eixo B: skip exit 0, sem depender de
        # web_dirs; nao monta .cs. Razao DERIVADA do campo do Eixo B (sourceUnsupportedReason).
        $skipped = New-SkippedJavaResult `
            -Reason $hostingRec.sourceUnsupportedReason `
            -MetadataPath $metadataPathResolved `
            -ResolvedEnvironment $resolvedEnvironment `
            -DeploymentHostingKind $hostingRec.hostingKind `
            -Family $hostingRec.family
        if ($AsJson) { $skipped | ConvertTo-Json -Depth 6 } else { Write-Output "CS_PATH_SKIPPED_HOSTING_UNSUPPORTED"; Write-Output $skipped.reason }
        exit 0
    }
    # ramo 3 — runsSourceEngine (dotnet): segue o fluxo .cs de hoje (abaixo).
}

if ($fields.kb_environment_web_dirs.Count -eq 0) {
    $blocked = New-BlockedResult -Reason 'kb_environment_web_dirs ausente em kb-source-metadata.md; nao inferir por scan de pastas da KB nativa.' -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

if (-not $fields.kb_environment_web_dirs.Contains($resolvedEnvironment)) {
    $blocked = New-BlockedResult -Reason ("kb_environment_web_dirs nao contem mapeamento para environment '{0}'." -f $resolvedEnvironment) -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$webDir = $fields.kb_environment_web_dirs[$resolvedEnvironment]
if ([string]::IsNullOrWhiteSpace($webDir)) {
    $blocked = New-BlockedResult -Reason ("kb_environment_web_dirs contem caminho vazio para environment '{0}'." -f $resolvedEnvironment) -MetadataPath $metadataPathResolved
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 6 } else { Write-Output "BLOCK: $($blocked.reason)"; Write-Output $blocked.nextStep }
    exit 1
}

$generatedFileName = $ObjectName.Trim().ToLowerInvariant() + '.cs'
$csPath = Join-Path $webDir $generatedFileName
$exists = Test-Path -LiteralPath $csPath -PathType Leaf

$result = [ordered]@{
    status             = 'CS_PATH_RESOLVED'
    kbPath             = $resolvedKbPath
    metadataPath       = $metadataPathResolved
    objectName         = $ObjectName
    objectType         = $ObjectType
    environmentName    = $resolvedEnvironment
    environmentSource  = $environmentSource
    webDirectory       = $webDir
    generatedFileName  = $generatedFileName
    csPath             = $csPath
    exists             = $exists
    readOnly           = $true
    resolutionSource   = 'kb-source-metadata.kb_environment_web_dirs'
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output 'CS_PATH_RESOLVED'
    Write-Output ("environment : {0} ({1})" -f $resolvedEnvironment, $environmentSource)
    Write-Output ("webDirectory: {0}" -f $webDir)
    Write-Output ("csPath      : {0}" -f $csPath)
    Write-Output ("exists      : {0}" -f $exists)
}
