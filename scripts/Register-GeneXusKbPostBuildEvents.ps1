#requires -Version 7.4
<#
.SYNOPSIS
    Registra os eventos pos-build conhecidos de um environment em kb-source-metadata.md
    (autoridade: xpz-kb-parallel-setup).

.DESCRIPTION
    Le os eventos pos-build observados no JSON de um build (stdoutSignals.postBuildEvents,
    gravado por Invoke-GeneXusKbBuildAll.ps1 / Invoke-GeneXusKbSpecifyGenerate.ps1), filtra
    inertes (linhas REM comentadas, duração TimeSpan válida ou data civil válida),
    normaliza e gera fingerprints SHA-256, e grava:
      - kb_environment_post_build_event_hashes: campo plano (env=h1,h2; ...) que o build le.
      - secao-espelho legivel "## Eventos pos-build registrados": auditoria humana, com as
        linhas cruas; o build NÃO le o espelho, só os hashes.

    Ação sensivel: registrar desarma o rebaixamento por evento pos-build daquele environment.
    Exige confirmacao. Modo interativo pede frase exata; modo agente usa -ConfirmRegistration
    (o agente deve obter a confirmacao explicita do humano antes de passar o switch).

.PARAMETER BuildResultJsonPath
    Caminho do JSON de resultado de um build (BuildAll ou SpecifyGenerate) com
    stdoutSignals.postBuildEvents.

.PARAMETER EnvironmentName
    Environment a registrar. Quando omitido, usa observedContext.ActiveEnvironment do JSON.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB (para localizar kb-source-metadata.md).

.PARAMETER MetadataPath
    Caminho explicito para kb-source-metadata.md (prevalece sobre KbParallelRoot).

.PARAMETER ConfirmRegistration
    Confirma o registro em modo nao-interativo (agente). Sem este switch, o script pede
    frase exata via Read-Host.

.PARAMETER AsJson
    Emite JSON em vez de texto simples.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BuildResultJsonPath,

    [string]$EnvironmentName,

    [string]$KbParallelRoot,

    [string]$MetadataPath,

    [switch]$ConfirmRegistration,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusMsBuildPostBuildEventsSupport.ps1')
. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')
. (Join-Path $PSScriptRoot 'XpzTextFileEolSupport.ps1')

if ([string]::IsNullOrWhiteSpace($MetadataPath)) {
    if ([string]::IsNullOrWhiteSpace($KbParallelRoot)) {
        throw 'BLOCK: informe -KbParallelRoot ou -MetadataPath.'
    }
    $MetadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'
}
$MetadataPath = [System.IO.Path]::GetFullPath($MetadataPath)
if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md ausente: $MetadataPath"
}

if (-not (Test-Path -LiteralPath $BuildResultJsonPath -PathType Leaf)) {
    throw "BLOCK: JSON de build ausente: $BuildResultJsonPath"
}

$buildJson = (Get-Content -LiteralPath $BuildResultJsonPath -Raw) | ConvertFrom-Json

$observed = @()
if ($null -ne $buildJson.PSObject.Properties['stdoutSignals'] -and $null -ne $buildJson.stdoutSignals) {
    if ($null -ne $buildJson.stdoutSignals.PSObject.Properties['postBuildEvents']) {
        $observed = @($buildJson.stdoutSignals.postBuildEvents)
    }
}

$envName = $EnvironmentName
if ([string]::IsNullOrWhiteSpace($envName)) {
    if ($null -ne $buildJson.PSObject.Properties['observedContext'] -and $null -ne $buildJson.observedContext -and
        $null -ne $buildJson.observedContext.PSObject.Properties['ActiveEnvironment']) {
        $envName = $buildJson.observedContext.ActiveEnvironment
    }
}
if ([string]::IsNullOrWhiteSpace($envName)) {
    throw 'BLOCK: environment nao informado e ActiveEnvironment ausente no JSON do build. Use -EnvironmentName.'
}
$envName = $envName.Trim()

$rawEvents = New-Object System.Collections.Generic.List[string]
$seenRaw = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($line in $observed) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if (Test-GeneXusPostBuildEventInert -Line $line) { continue }
    $trimmed = $line.Trim()
    if ($seenRaw.Add($trimmed)) {
        $rawEvents.Add($trimmed) | Out-Null
    }
}

if ($rawEvents.Count -eq 0) {
    throw "BLOCK: nenhum evento pos-build executavel observado no JSON para o environment '$envName' (so inertes/REM ou lista vazia). Nada a registrar."
}

$hashes = New-Object System.Collections.Generic.List[string]
foreach ($evt in $rawEvents) {
    $hashes.Add((Get-GeneXusPostBuildEventNormalizedHash -Line $evt)) | Out-Null
}

$presentation = "Eventos pos-build a registrar para o environment '$envName':`n"
for ($i = 0; $i -lt $rawEvents.Count; $i++) {
    $presentation += ("  [{0}] {1}`n" -f ($i + 1), $rawEvents[$i])
}
$presentation += "`nApos registrar, estes eventos deixam de rebaixar o status do build neste environment."

$confirmed = $false
if ($ConfirmRegistration.IsPresent) {
    $confirmed = $true
} else {
    Write-Output $presentation
    $phrase = "registrar eventos pos-build de $envName"
    Write-Output "Para confirmar, digite exatamente: $phrase"
    $answer = Read-Host 'Confirmacao'
    if ($answer -eq $phrase) {
        $confirmed = $true
    }
}

if (-not $confirmed) {
    throw 'BLOCK: registro nao confirmado. Nenhuma alteracao gravada.'
}

# Merge dos hashes deste environment ao mapa existente.
$fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $MetadataPath
$hashMap = [ordered]@{}
foreach ($k in $fields.kb_environment_post_build_event_hashes.Keys) {
    $hashMap[$k] = @($fields.kb_environment_post_build_event_hashes[$k])
}
$hashMap[$envName] = @($hashes)

$entries = New-Object System.Collections.Generic.List[string]
foreach ($k in @($hashMap.Keys | Sort-Object)) {
    $entries.Add(('{0}={1}' -f $k, (@($hashMap[$k]) -join ','))) | Out-Null
}
$fieldValue = ($entries -join '; ')

$fileContext = Get-TextFileLineContext -Path $MetadataPath
$fileLines = $fileContext.Lines

# --- Campo plano no frontmatter (update ou insert) ---
$fieldName = 'kb_environment_post_build_event_hashes'
$newLine = '{0}: {1}' -f $fieldName, $fieldValue
$fieldPattern = '^\s*{0}\s*[:=]\s*.+$' -f [regex]::Escape($fieldName)
$updated = $false
for ($i = 0; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match $fieldPattern) {
        $fileLines[$i] = $newLine
        $updated = $true
        break
    }
}
if (-not $updated) {
    $insertAt = -1
    $hasFrontmatter = ($fileLines.Count -gt 0 -and $fileLines[0].Trim() -eq '---')
    if ($hasFrontmatter) {
        for ($i = 1; $i -lt $fileLines.Count; $i++) {
            if ($fileLines[$i].Trim() -eq '---') { $insertAt = $i; break }
        }
    }
    if ($insertAt -lt 0) {
        for ($i = 0; $i -lt $fileLines.Count; $i++) {
            if ($fileLines[$i] -match '^\s*##\s+') { $insertAt = $i; break }
        }
    }
    if ($insertAt -lt 0) { $insertAt = $fileLines.Count }
    $fileLines.Insert($insertAt, $newLine)
}

# --- Espelho legivel (atualizacao cirurgica da subsecao do environment) ---
$mirrorHeader = '## Eventos pos-build registrados'
$mirrorIntro  = '> Espelho legivel de `kb_environment_post_build_event_hashes` (autoria: xpz-kb-parallel-setup). O build compara por fingerprint; esta secao e so para auditoria humana.'
$subHeader = '### env: ' + $envName

$subsectionLines = New-Object System.Collections.Generic.List[string]
$subsectionLines.Add($subHeader)
$subsectionLines.Add('')
foreach ($evt in $rawEvents) {
    $subsectionLines.Add(('- `{0}`' -f $evt))
}
$subsectionLines.Add('')

$headerIdx = -1
for ($i = 0; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i].Trim() -eq $mirrorHeader) { $headerIdx = $i; break }
}

if ($headerIdx -lt 0) {
    $createBlock = New-Object System.Collections.Generic.List[string]
    $createBlock.Add('')
    $createBlock.Add($mirrorHeader)
    $createBlock.Add('')
    $createBlock.Add($mirrorIntro)
    $createBlock.Add('')
    foreach ($l in $subsectionLines) { $createBlock.Add($l) }

    $insertAt = $fileLines.Count
    if ($fileLines.Count -gt 0 -and $fileLines[$fileLines.Count - 1] -eq '') {
        $insertAt = $fileLines.Count - 1
    }
    $fileLines.InsertRange($insertAt, $createBlock)
} else {
    $sectionEnd = $fileLines.Count
    for ($i = $headerIdx + 1; $i -lt $fileLines.Count; $i++) {
        if ($fileLines[$i] -match '^##\s') { $sectionEnd = $i; break }
    }

    $subIdx = -1
    for ($i = $headerIdx + 1; $i -lt $sectionEnd; $i++) {
        if ($fileLines[$i].Trim() -eq $subHeader) { $subIdx = $i; break }
    }

    if ($subIdx -ge 0) {
        $subEnd = $sectionEnd
        for ($i = $subIdx + 1; $i -lt $sectionEnd; $i++) {
            if (($fileLines[$i] -match '^###\s') -or ($fileLines[$i] -match '^##\s')) { $subEnd = $i; break }
        }
        $fileLines.RemoveRange($subIdx, $subEnd - $subIdx)
        $fileLines.InsertRange($subIdx, $subsectionLines)
    } else {
        $fileLines.InsertRange($sectionEnd, $subsectionLines)
    }
}

Write-TextFilePreservingEol -Path $MetadataPath -FileContext $fileContext

$result = [ordered]@{
    status                = 'KB_POST_BUILD_EVENTS_REGISTERED_OK'
    metadataPath          = $MetadataPath
    environmentName       = $envName
    registeredEventCount  = $rawEvents.Count
    registeredEvents      = @($rawEvents)
    registeredHashes      = @($hashes)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("KB_POST_BUILD_EVENTS_REGISTERED_OK: env=$envName events=$($rawEvents.Count) metadata=$MetadataPath")
}
