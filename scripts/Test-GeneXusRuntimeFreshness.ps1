#requires -Version 7.4
<#
.SYNOPSIS
    Diagnostica se o runtime GeneXus .NET reflete a versão mais recente de um objeto importado.

.DESCRIPTION
    Verifica dois indicadores do motor .NET em modo somente leitura, sem abrir a IDE e sem invocar MSBuild:

    1. nav_objs.xml na raiz da KB: status de geração do objeto
       - genreq  = GeneXus marcou o objeto como pendente de geração no diagnóstico .NET (runtime defasado)
       - nogenreq = GeneXus considera o objeto já gerado (checar artefatos para confirmar)

    2. Artefatos gerados .NET (CSharpModel\web): timestamp dos arquivos gerados vs ImportedAt

    Em KB Java/Tomcat conhecida, passe -DeploymentHostingKind java-tomcat: o Eixo C ainda é
    recognized-no-engine/Pós-v1 e o script pula com skipped-hosting-unsupported, sem derivar
    CSharpModel\web. Nesse caso, ObjStatus não é critério isolado de freshness Java; a evidência
    operacional exige cruzar ObjNavig, XMLs de navegação/specification e artefatos .java/.class/.js
    em frente futura.

    O diagnostico e somente leitura: não grava, não abre KB, não invoca MSBuild.

.PARAMETER KbPath
    Caminho da KB GeneXus nativa (ex: C:\GxModels\MinhaKB).

.PARAMETER ObjectName
    Nome do objeto GeneXus a verificar.

.PARAMETER ImportedAt
    Timestamp do import usado como linha de corte (DateTime ou string ISO parseable).

.PARAMETER ObjectType
    Tipo GeneXus do objeto (ex: Procedure, WebPanel). Reservado para uso futuro.

.PARAMETER GeneratorOutputPath
    Pasta de output do gerador. Se omitido, deriva como <KbPath>\CSharpModel\web.
    Para diagnostico de .cs por environment, prefira resolver este caminho antes
    com Resolve-GeneXusGeneratedCsPath.ps1 a partir de kb-source-metadata.md.

.PARAMETER DeploymentHostingKind
    Guarda de família do Eixo C. Para KB de família não-.NET conhecida, especialmente
    java-tomcat, deve ser informado para acionar o skip explícito em vez do diagnóstico .NET.

.PARAMETER AsJson
    Emite saida como JSON estruturado em vez de texto humano.

.EXAMPLE
    .\Test-GeneXusRuntimeFreshness.ps1 `
        -KbPath "C:\GxModels\MinhaKB" `
        -ObjectName "MinhaProc" `
        -ImportedAt "2026-05-07T22:00:00-03:00" `
        -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$ObjectName,

    [Parameter(Mandatory = $true)]
    [string]$ImportedAt,

    [string]$ObjectType,

    [string]$GeneratorOutputPath,

    # Fase 2 (paridade Java/Tomcat): opcional no contrato para manter compatibilidade .NET legada.
    # Quando a familia do hosting kind e conhecida como nao-.NET, quem ja resolveu o metadata deve
    # passar o valor explicito (especialmente java-tomcat) para pular de forma clara em vez de derivar
    # CSharpModel\web e cair em runtime-unknown silencioso. Ausente/vazio => comportamento IDENTICO
    # ao de hoje (D3, zero regressao). Este script permanece metadata-free (nao resolve metadata por conta propria).
    [string]$DeploymentHostingKind,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Fase 2: registro-fonte-unica dos hosting kinds (guarda de familia do Eixo C). Dot-source novo — este
# script era self-contained.
. (Join-Path $PSScriptRoot 'GeneXusKbHostingKindSupport.ps1')

# ── Parse ImportedAt ───────────────────────────────────────────────────────────

$importedAtDt = $null
try {
    $importedAtDt = [DateTimeOffset]::Parse($ImportedAt)
} catch {
    throw "ImportedAt nao e timestamp valido: '$ImportedAt'"
}

# ── Inicializar resultado ──────────────────────────────────────────────────────

$result = [ordered]@{
    status     = 'runtime-unknown'
    objectName = $ObjectName
    importedAt = $importedAtDt.ToString('o')
    checks     = [ordered]@{
        navObjsXml         = [ordered]@{
            found              = $false
            objStatus          = $null
            requiresGeneration = $null
        }
        generatedArtifacts = [ordered]@{
            found                = $false
            artifacts            = @()
            allFresherThanImport = $null
        }
    }
    summary    = ''
}

# ── Fase 2 — guarda de familia (Eixo C) ─────────────────────────────────────────
# Opt-in por -DeploymentHostingKind (D3). Inserida APOS o init de $result e ANTES da secao nav_objs, para
# nao rodar o diagnostico .NET (nav_objs + derivacao CSharpModel\web) no caso de skip. Guard de vazio T1 +
# tríade por T2. Fase 3 (split per-eixo): este e o Eixo C (runtime-freshness) — discrimina pelo campo DO
# SEU EIXO ($rec.runsRuntimeEngine), nao pelo alias legado runsFreshnessEngine (que segue o Eixo A e, para
# Java pos-Fase 3, seria 'true' e rodaria o motor .rsp indevidamente). Script LINEAR (sem return): ramos 1/2
# emitem a saida e saem com exit explicito. Le so runsRuntimeEngine/runtimeSkipStatus/runtimeUnsupportedReason
# — nunca o campo de forma-alvo do registro (clausula no-bridge INVERTIDA: este guard nao-motor fica fora da allowlist de arquivos-motor).
if (-not [string]::IsNullOrWhiteSpace($DeploymentHostingKind)) {
    $hostingRec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $DeploymentHostingKind
    if ($null -eq $hostingRec) {
        # ramo 1 — presente-e-fora-do-registro: erro de parametro/metadata (exit NAO-ZERO), nao skip de familia.
        $invalidMsg = Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind $DeploymentHostingKind
        if ($AsJson) {
            [ordered]@{
                status     = 'runtime-hosting-kind-invalido'
                objectName = $ObjectName
                reason     = $invalidMsg
            } | ConvertTo-Json -Depth 6
        } else {
            Write-Host "BLOCK: $invalidMsg"
        }
        exit 1
    }
    if (-not $hostingRec.runsRuntimeEngine) {
        # ramo 2 — recognized-no-engine / blocked-out-of-scope no Eixo C: skip claro, sem derivar
        # CSharpModel\web nem .cs. status/summary DERIVADOS do registro (campos do Eixo C; nunca
        # redigitados). Os checks ficam nos defaults (found=false).
        $result.status  = $hostingRec.runtimeSkipStatus
        $result.summary = $hostingRec.runtimeUnsupportedReason
        if ($AsJson) {
            $result | ConvertTo-Json -Depth 6
        } else {
            Write-Host "Status    : $($result.status)"
            Write-Host "Objeto    : $($result.objectName)"
            Write-Host "Import em : $($result.importedAt)"
            Write-Host "Resumo    : $($result.summary)"
        }
        exit 0
    }
    # ramo 3 — runsRuntimeEngine (dotnet): segue o diagnostico .cs de hoje (abaixo).
}

# ── 1. nav_objs.xml ────────────────────────────────────────────────────────────
# Localizado na raiz da KB nativa; lista objetos com ObjStatus genreq/nogenreq.
# O arquivo não tem elemento raiz — encapsulado antes do parse.

$navObjsPath = Join-Path $KbPath 'nav_objs.xml'

if (Test-Path -LiteralPath $navObjsPath -PathType Leaf) {
    try {
        $rawContent = Get-Content -LiteralPath $navObjsPath -Raw -Encoding UTF8
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.PreserveWhitespace = $false
        $xmlDoc.LoadXml("<NavObjs>$rawContent</NavObjs>")

        $matchedNode = $null
        foreach ($node in $xmlDoc.SelectNodes('/NavObjs/Object')) {
            $nameNode = $node.SelectSingleNode('ObjName')
            if ($null -ne $nameNode -and $nameNode.InnerText -ieq $ObjectName) {
                $matchedNode = $node
                break
            }
        }

        if ($null -ne $matchedNode) {
            $statusNode = $matchedNode.SelectSingleNode('ObjStatus')
            $objStatus  = if ($null -ne $statusNode) { $statusNode.InnerText } else { $null }
            $requiresGen = ($objStatus -eq 'genreq')

            $result.checks.navObjsXml.found              = $true
            $result.checks.navObjsXml.objStatus          = $objStatus
            $result.checks.navObjsXml.requiresGeneration = $requiresGen
        }
    } catch {
        # Parse falhou — manter found=false; não abortar o diagnostico
    }
}

# ── 2. Artefatos gerados ───────────────────────────────────────────────────────
# Artefatos ficam em <KbPath>\CSharpModel\web\ com nome em minusculas.
# Extensoes observadas empiricamente: .cs .js .aspx .rsp

$outputPath = $GeneratorOutputPath
if ([string]::IsNullOrWhiteSpace($outputPath)) {
    $derived = Join-Path $KbPath 'CSharpModel\web'
    if (Test-Path -LiteralPath $derived -PathType Container) {
        $outputPath = $derived
    }
}

if (-not [string]::IsNullOrWhiteSpace($outputPath) -and
    (Test-Path -LiteralPath $outputPath -PathType Container)) {

    $namePrefix  = $ObjectName.ToLower()
    $extensions  = @('.cs', '.js', '.aspx', '.rsp')
    $foundArtifacts = [System.Collections.Generic.List[object]]::new()

    foreach ($ext in $extensions) {
        $candidate = Join-Path $outputPath ($namePrefix + $ext)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $fi        = Get-Item -LiteralPath $candidate
            $lastWrite = [DateTimeOffset]::new($fi.LastWriteTime)
            $fresh     = $lastWrite -gt $importedAtDt
            $foundArtifacts.Add([ordered]@{
                path              = $fi.FullName
                lastWrite         = $lastWrite.ToString('o')
                fresherThanImport = $fresh
            })
        }
    }

    if ($foundArtifacts.Count -gt 0) {
        $staleCount = ($foundArtifacts | Where-Object { -not $_.fresherThanImport }).Count
        $allFresh   = ($staleCount -eq 0)

        $result.checks.generatedArtifacts.found                = $true
        $result.checks.generatedArtifacts.artifacts            = $foundArtifacts.ToArray()
        $result.checks.generatedArtifacts.allFresherThanImport = $allFresh
    }
}

# ── 3. Classificar status ──────────────────────────────────────────────────────

$navFound    = $result.checks.navObjsXml.found
$requiresGen = $result.checks.navObjsXml.requiresGeneration
$artFound    = $result.checks.generatedArtifacts.found
$allFresh    = $result.checks.generatedArtifacts.allFresherThanImport

if ($navFound -and $requiresGen) {
    $result.status  = 'runtime-stale'
    $result.summary = "nav_objs.xml marca '$ObjectName' como genreq — geracao pendente apos o import"
} elseif ($navFound -and (-not $requiresGen) -and $artFound -and $allFresh) {
    $result.status  = 'runtime-fresh'
    $result.summary = "nav_objs.xml: nogenreq; artefatos gerados posteriores ao import — runtime atualizado"
} elseif ($navFound -and (-not $requiresGen) -and $artFound -and (-not $allFresh)) {
    $result.status  = 'runtime-stale'
    $result.summary = "nav_objs.xml: nogenreq, mas artefatos anteriores ao import — runtime ainda reflete versao anterior"
} elseif ($navFound -and (-not $requiresGen) -and (-not $artFound)) {
    $result.status  = 'runtime-unknown'
    $result.summary = "nav_objs.xml: nogenreq, mas artefatos nao localizados — diagnostico inconclusivo"
} elseif ((-not $navFound) -and $artFound -and $allFresh) {
    $result.status  = 'runtime-unknown'
    $result.summary = "Objeto ausente em nav_objs.xml; artefatos frescos encontrados — diagnostico inconclusivo"
} elseif (-not $navFound) {
    $result.status  = 'runtime-unknown'
    $result.summary = "Objeto '$ObjectName' nao encontrado em nav_objs.xml — diagnostico inconclusivo"
} else {
    $result.status  = 'runtime-unknown'
    $result.summary = "Indicadores insuficientes para determinar estado do runtime"
}

# ── 4. Saida ───────────────────────────────────────────────────────────────────

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Host "Status    : $($result.status)"
    Write-Host "Objeto    : $($result.objectName)"
    Write-Host "Import em : $($result.importedAt)"
    Write-Host ''
    Write-Host 'nav_objs.xml:'
    Write-Host "  Encontrado         : $($result.checks.navObjsXml.found)"
    Write-Host "  ObjStatus          : $($result.checks.navObjsXml.objStatus)"
    Write-Host "  Requer geracao     : $($result.checks.navObjsXml.requiresGeneration)"
    Write-Host ''
    Write-Host 'Artefatos gerados:'
    Write-Host "  Encontrados        : $($result.checks.generatedArtifacts.found)"
    Write-Host "  Todos frescos      : $($result.checks.generatedArtifacts.allFresherThanImport)"
    foreach ($a in $result.checks.generatedArtifacts.artifacts) {
        Write-Host "  - $($a.path) | $($a.lastWrite) | fresher=$($a.fresherThanImport)"
    }
    Write-Host ''
    Write-Host "Resumo    : $($result.summary)"
}

exit 0
