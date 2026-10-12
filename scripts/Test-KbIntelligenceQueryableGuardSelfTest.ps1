#requires -Version 7.4

<#
.SYNOPSIS
    Valida bloqueio de consultas semanticas quando queryableByKbIntelligence=false.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
$buildScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'
$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.ps1'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kb-queryable-guard-selftest-{0}" -f ([guid]::NewGuid().ToString('N')))
$objetosPath = Join-Path $tempRoot 'ObjetosDaKbEmXml'
$scriptsPath = Join-Path $tempRoot 'scripts'
$sdpDir = Join-Path $objetosPath 'SmartDevicesPlus'
$sqlitePath = Join-Path $tempRoot 'KbIntelligence\kb-intelligence.sqlite'

[void](New-Item -ItemType Directory -Path $sdpDir -Force)
[void](New-Item -ItemType Directory -Path $scriptsPath -Force)
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $sqlitePath) -Force)

$sdpXml = @'
<Object type="c84ec0ea-d159-46e2-a118-2108860379bb" name="SmartDevicesPlus" description="Smart Devices Plus" parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361"><Properties><Property><Name>SDPlus_Settings_Theme</Name><Value>DarkBlue</Value></Property></Properties></Object>
'@
[System.IO.File]::WriteAllText((Join-Path $sdpDir 'SmartDevicesPlus.xml'), $sdpXml, (Get-Utf8NoBomEncoding))

& $buildScript -SourceRoot $objetosPath -OutputPath $sqlitePath -ParallelKbRoot $tempRoot
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex falhou; exit $LASTEXITCODE"
}

$blockedJson = & $queryScript `
    -IndexPath $sqlitePath `
    -ParallelKbRoot $tempRoot `
    -Query impact-basic `
    -ObjectType SmartDevicesPlus `
    -ObjectName SmartDevicesPlus `
    -Format json 2>&1 | Out-String
$blockedExit = $LASTEXITCODE

if ($blockedExit -ne 11) {
    throw "impact-basic em SmartDevicesPlus (base) deveria exit 11; obtido $blockedExit"
}

$blocked = $blockedJson | ConvertFrom-Json
if (-not $blocked.blocked) {
    throw 'impact-basic deveria retornar blocked=true'
}
if ($blocked.reason -ne 'QUERY_NOT_SEMANTIC_FOR_TYPE') {
    throw "reason esperado QUERY_NOT_SEMANTIC_FOR_TYPE; obtido $($blocked.reason)"
}

$infoJson = & $queryScript `
    -IndexPath $sqlitePath `
    -ParallelKbRoot $tempRoot `
    -Query object-info `
    -ObjectType SmartDevicesPlus `
    -ObjectName SmartDevicesPlus `
    -Format json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "object-info deveria exit 0; obtido $LASTEXITCODE"
}
if ($infoJson.found -ne $true) {
    throw 'object-info deveria encontrar SmartDevicesPlus no indice'
}

$overridePath = Join-Path $scriptsPath 'gx-object-type-catalog.override.json'
$overrideJson = @{
    schemaVersion                   = 1
    upstreamPending                 = $true
    registrationRequiresUpstreamSync = $true
    types                           = @{
        SmartDevicesPlus = @{
            objectTypeGuid              = 'c84ec0ea-d159-46e2-a118-2108860379bb'
            rootKind                    = 'Object'
            folderName                  = 'SmartDevicesPlus'
            inventoryEligible           = $true
            queryableByKbIntelligence   = $true
            containerType               = $false
            notes                       = 'override selftest: liberar consulta semantica'
        }
        Procedure        = @{
            objectTypeGuid              = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
            rootKind                    = 'Object'
            folderName                  = 'Procedure'
            inventoryEligible           = $true
            queryableByKbIntelligence   = $false
            containerType               = $false
            notes                       = 'override selftest: bloquear consulta semantica'
        }
    }
}
$overrideJson | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $overridePath -Encoding utf8

$allowedJson = & $queryScript `
    -IndexPath $sqlitePath `
    -ParallelKbRoot $tempRoot `
    -CatalogOverridePath $overridePath `
    -Query impact-basic `
    -ObjectType SmartDevicesPlus `
    -ObjectName SmartDevicesPlus `
    -Format json 2>&1 | Out-String
if ($LASTEXITCODE -eq 11) {
    throw 'impact-basic em SmartDevicesPlus com override queryable=true nao deveria exit 11'
}

$procDir = Join-Path $objetosPath 'Procedure'
[void](New-Item -ItemType Directory -Path $procDir -Force)
$procXml = @'
<Object type="84a12160-f59b-4ad7-a683-ea4481ac23e9" name="procSelfTestQueryable" description="proc selftest" parentGuid="afa47377-41d5-4ae8-9755-6f53150aa361" moduleGuid="afa47377-41d5-4ae8-9755-6f53150aa361"><Properties><Property><Name>Name</Name><Value>procSelfTestQueryable</Value></Property></Properties><Source><![CDATA[]]></Source></Object>
'@
[System.IO.File]::WriteAllText((Join-Path $procDir 'procSelfTestQueryable.xml'), $procXml, (Get-Utf8NoBomEncoding))

& $buildScript -SourceRoot $objetosPath -OutputPath $sqlitePath -ParallelKbRoot $tempRoot -CatalogOverridePath $overridePath
if ($LASTEXITCODE -ne 0) {
    throw "Rebuild com Procedure falhou; exit $LASTEXITCODE"
}

$procBlocked = & $queryScript `
    -IndexPath $sqlitePath `
    -ParallelKbRoot $tempRoot `
    -CatalogOverridePath $overridePath `
    -Query impact-basic `
    -ObjectType Procedure `
    -ObjectName procSelfTestQueryable `
    -Format json 2>&1 | Out-String
if ($LASTEXITCODE -ne 11) {
    throw "impact-basic em Procedure com override queryable=false deveria exit 11; obtido $LASTEXITCODE"
}

$procBlockedObj = $procBlocked | ConvertFrom-Json
if ($procBlockedObj.reason -ne 'QUERY_NOT_SEMANTIC_FOR_TYPE') {
    throw "Procedure override: reason esperado QUERY_NOT_SEMANTIC_FOR_TYPE"
}

Write-Output 'OK: Test-KbIntelligenceQueryableGuardSelfTest.ps1'
exit 0
