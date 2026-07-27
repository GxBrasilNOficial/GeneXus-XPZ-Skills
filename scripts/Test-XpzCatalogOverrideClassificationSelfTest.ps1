#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da classificacao de gx-object-type-catalog.override.json.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusObjectTypeCatalogSupport.ps1')
. (Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1')

function Assert-True { param([bool]$Condition,[string]$Message) if(-not $Condition){ throw $Message } }
function Write-JsonFile { param([string]$Path,[object]$Value) [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 8), (Get-Utf8NoBomEncoding)) }
function New-CaseRoot { param([string]$Name) $root=Join-Path ([IO.Path]::GetTempPath()) ("gx-catalog-override-$Name-" + [guid]::NewGuid().ToString('N')); [void](New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force); return $root }
function Invoke-Reminder { param([string]$Root) return Get-GeneXusCatalogOverrideSessionReminder -ParallelKbRoot $Root }

$basePath = Get-GeneXusObjectTypeCatalogDefaultBasePath
$base = Read-GeneXusObjectTypeCatalogFile -Path $basePath
$workWith = $base.types.WorkWith
$procedure = $base.types.Procedure

# Sem override.
$emptyRoot = New-CaseRoot 'empty'
$r = Invoke-Reminder -Root $emptyRoot
Assert-True ($r.status -eq 'OK' -and -not $r.noticeRequired) 'sem override deve ser OK'

# Redundante identico, mas sem exportTaskLabel local: cleanup, sem pendencia efetiva, exportTaskLabel da base preservado.
$redundantRoot = New-CaseRoot 'redundant'
$overridePath = Join-Path $redundantRoot 'scripts/gx-object-type-catalog.override.json'
Write-JsonFile -Path $overridePath -Value ([ordered]@{
    schemaVersion = 1
    upstreamPending = $true
    types = [ordered]@{
        WorkWith = [ordered]@{
            objectTypeGuid = $workWith.objectTypeGuid
            rootKind = $workWith.rootKind
            folderName = $workWith.folderName
            inventoryEligible = $workWith.inventoryEligible
            queryableByKbIntelligence = $workWith.queryableByKbIntelligence
            containerType = $workWith.containerType
            notes = 'metadata only for local evidence'
        }
    }
})
$r = Invoke-Reminder -Root $redundantRoot
Assert-True ($r.status -eq 'CLEANUP_RECOMMENDED') 'redundante deve recomendar limpeza'
Assert-True (-not $r.effectiveUpstreamPending -and $r.declaredUpstreamPending) 'pendencia declarada nao pode virar pendencia efetiva em redundante'
Assert-True ($r.redundantTypeNames -contains 'WorkWith' -and $r.pendingTypeNames.Count -eq 0) 'WorkWith deve ser redundante, nao pendente'
$res = Resolve-GeneXusObjectTypeCatalogPaths -ParallelKbRoot $redundantRoot
Assert-True ($res.UpstreamPending -eq $false -and $res.DeclaredUpstreamPending -eq $true -and $res.EffectiveUpstreamPending -eq $false) 'aliases de pendencia devem refletir efetivo/declarado'
Assert-True ($res.MergedCatalog.types.WorkWith.exportTaskLabel -eq $workWith.exportTaskLabel) 'merge deve preservar exportTaskLabel da base'
Assert-True ($res.MergedCatalog.types.WorkWith.canonicalType -eq 'WorkWith') 'canonicalType deve ser derivado'

# Pendente real.
$pendingRoot = New-CaseRoot 'pending'
Write-JsonFile -Path (Join-Path $pendingRoot 'scripts/gx-object-type-catalog.override.json') -Value ([ordered]@{
    schemaVersion = 1
    upstreamPending = $true
    types = [ordered]@{
        LocalOnlyType = [ordered]@{
            objectTypeGuid = '11111111-2222-3333-4444-555555555555'
            rootKind = 'Object'
            folderName = 'LocalOnlyType'
            inventoryEligible = $true
            queryableByKbIntelligence = $true
            containerType = $false
        }
    }
})
$r = Invoke-Reminder -Root $pendingRoot
Assert-True ($r.status -eq 'REMINDER_REQUIRED' -and $r.pendingTypeNames -contains 'LocalOnlyType') 'tipo ausente deve ser pending'

# Divergente comum.
$divRoot = New-CaseRoot 'divergent'
Write-JsonFile -Path (Join-Path $divRoot 'scripts/gx-object-type-catalog.override.json') -Value ([ordered]@{
    schemaVersion = 1
    upstreamPending = $true
    types = [ordered]@{
        Procedure = [ordered]@{
            objectTypeGuid = $procedure.objectTypeGuid
            rootKind = $procedure.rootKind
            folderName = $procedure.folderName
            inventoryEligible = $procedure.inventoryEligible
            queryableByKbIntelligence = (-not [bool]$procedure.queryableByKbIntelligence)
            containerType = $procedure.containerType
        }
    }
})
$r = Invoke-Reminder -Root $divRoot
Assert-True ($r.status -eq 'REMINDER_REQUIRED' -and $r.divergentTypeNames -contains 'Procedure') 'campo divergente deve ser divergent'
Assert-True (@($r.classificationEntries[0].divergentFields) -contains 'queryableByKbIntelligence') 'campo divergente deve ser nomeado'

# Metadata-only / types vazio.
$metaRoot = New-CaseRoot 'metadata'
Write-JsonFile -Path (Join-Path $metaRoot 'scripts/gx-object-type-catalog.override.json') -Value ([ordered]@{ schemaVersion = 1; upstreamPending = $true; notes = 'legacy root metadata' })
$r = Invoke-Reminder -Root $metaRoot
Assert-True ($r.status -eq 'CLEANUP_RECOMMENDED' -and -not $r.effectiveUpstreamPending) 'metadata-only deve ser cleanup sem pendencia efetiva'

# Shape invalido.
$invalidRoot = New-CaseRoot 'invalid'
[IO.File]::WriteAllText((Join-Path $invalidRoot 'scripts/gx-object-type-catalog.override.json'), '{"upstreamPending":"yes","types":{}}', (Get-Utf8NoBomEncoding))
$r = Invoke-Reminder -Root $invalidRoot
Assert-True ($r.status -eq 'INVALID_OVERRIDE_SHAPE' -and $r.diagnosticReason -eq 'upstream-pending-not-boolean') 'upstreamPending invalido deve ser shape invalido'

# Unsafe shadowing e GUID duplicado.
$shadowRoot = New-CaseRoot 'shadow'
Write-JsonFile -Path (Join-Path $shadowRoot 'scripts/gx-object-type-catalog.override.json') -Value ([ordered]@{ types = [ordered]@{ Attribute = [ordered]@{ objectTypeGuid='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'; rootKind='Attribute'; folderName='Attribute'; inventoryEligible=$true; queryableByKbIntelligence=$true; containerType=$false } } })
$r = Invoke-Reminder -Root $shadowRoot
Assert-True ($r.status -eq 'OVERRIDE_RESOLUTION_BLOCKED' -and $r.reason -eq 'unsafe-shadowing') 'Attribute com GUID deve bloquear por shadowing'

$dupRoot = New-CaseRoot 'dupguid'
Write-JsonFile -Path (Join-Path $dupRoot 'scripts/gx-object-type-catalog.override.json') -Value ([ordered]@{ types = [ordered]@{ ProcedureAlias = [ordered]@{ objectTypeGuid=$procedure.objectTypeGuid; rootKind=$procedure.rootKind; folderName=$procedure.folderName; inventoryEligible=$procedure.inventoryEligible; queryableByKbIntelligence=$procedure.queryableByKbIntelligence; containerType=$procedure.containerType } } })
$r = Invoke-Reminder -Root $dupRoot
Assert-True ($r.status -eq 'CLEANUP_RECOMMENDED' -and $r.redundantTypeNames -contains 'ProcedureAlias' -and $r.classificationEntries[0].baseTypeName -eq 'Procedure') 'alias por GUID equivalente deve ser redundante'
Assert-True (-not (Resolve-GeneXusObjectTypeCatalogPaths -ParallelKbRoot $dupRoot).MergedCatalog.types.PSObject.Properties['ProcedureAlias']) 'alias redundante nao deve criar tipo efetivo novo'

# Paridade Python basica: redundante preserva exportTaskLabel.
$py = @"
from pathlib import Path
from GeneXusObjectTypeCatalogCore import resolve_effective_object_type_catalog
cat, override = resolve_effective_object_type_catalog(Path(r'$redundantRoot') / 'ObjetosDaKbEmXml', parallel_kb_root=Path(r'$redundantRoot'))
assert cat['types']['WorkWith']['exportTaskLabel'] == '$($workWith.exportTaskLabel)'
assert 'canonicalType' in cat['types']['WorkWith']
"@
$env:PYTHONPATH = $scriptDir
$py | python -
if($LASTEXITCODE -ne 0){ throw 'paridade Python falhou para WorkWith redundante' }

Write-Output 'OK: Test-XpzCatalogOverrideClassificationSelfTest.ps1'
exit 0
