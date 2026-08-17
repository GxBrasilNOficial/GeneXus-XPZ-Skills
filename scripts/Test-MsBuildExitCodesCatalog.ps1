#requires -Version 7.4
<#
.SYNOPSIS
    Valida scripts/msbuild-exit-codes.catalog.json e paridade com exits nos wrappers MSBuild.

.DESCRIPTION
    Gate mecanico: parse JSON, schema mínimo, anexo de causes para exit 46, presenca de 48,
    e exits literais nos wrappers prioritarios documentados no catalogo.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$catalogPath = Join-Path $PSScriptRoot 'msbuild-exit-codes.catalog.json'
$findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $findings.Add([pscustomobject]@{
            code    = $Code
            message = $Message
        })
}

$wrapperScanList = @(
    'Invoke-GeneXusKbBuildAll.ps1'
    'Invoke-GeneXusKbSpecifyGenerate.ps1'
    'Test-GeneXusXpzImportPreview.ps1'
    'Invoke-GeneXusXpzImport.ps1'
    'Invoke-GeneXusXpzImportThenBuild.ps1'
    'Invoke-GeneXusXpzExport.ps1'
    'Open-GeneXusKbHeadless.ps1'
    'Get-GeneXusKbProperty.ps1'
    'Test-GeneXusKbConsistency.ps1'
    'Start-GeneXusKbBuildDetached.ps1'
    'Test-GeneXusMsBuildSetup.ps1'
)

if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    Add-Finding -Code 'CATALOG_MISSING' -Message "Arquivo ausente: $catalogPath"
}
else {
    $raw = [System.IO.File]::ReadAllText($catalogPath)
    try {
        $catalog = $raw | ConvertFrom-Json -Depth 20
    }
    catch {
        Add-Finding -Code 'CATALOG_JSON_PARSE' -Message $_.Exception.Message
        $catalog = $null
    }

    if ($null -ne $catalog) {
        foreach ($requiredTop in @('schemaVersion', 'lastUpdated', 'legend', 'codes')) {
            if (-not ($catalog.PSObject.Properties.Name -contains $requiredTop)) {
                Add-Finding -Code 'CATALOG_SCHEMA' -Message "Campo top-level ausente: $requiredTop"
            }
        }

        $catalogExits = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($entry in @($catalog.codes)) {
            if ($null -eq $entry.exit) {
                Add-Finding -Code 'CATALOG_SCHEMA' -Message 'Entrada em codes[] sem exit.'
                continue
            }
            [void]$catalogExits.Add([int]$entry.exit)

            if ([int]$entry.exit -eq 46) {
                if (-not $entry.disambiguationRequired) {
                    Add-Finding -Code 'CATALOG_46' -Message 'exit 46 deve ter disambiguationRequired=true.'
                }
                if (@($entry.causes).Count -lt 1) {
                    Add-Finding -Code 'CATALOG_46' -Message 'exit 46 deve ter causes[] nao vazio.'
                }
            }

            if ([int]$entry.exit -eq 48 -and [string]::IsNullOrWhiteSpace($entry.summary)) {
                Add-Finding -Code 'CATALOG_48' -Message 'exit 48 deve ter summary.'
            }
        }

        if (-not $catalogExits.Contains(48)) {
            Add-Finding -Code 'CATALOG_48' -Message 'Catalogo deve documentar exit 48 (Categoria B).'
        }

        $documentedInWrappers = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($entry in @($catalog.codes)) {
            $wrappers = @($entry.wrappers)
            if ($wrappers -contains '*') {
                continue
            }
            foreach ($w in $wrappers) {
                if ($wrapperScanList -contains $w) {
                    [void]$documentedInWrappers.Add([int]$entry.exit)
                }
            }
        }

        # Case-sensitive em "exit N" — evita falso positivo em "ExitCode = N".
        $exitPattern = [regex]::new('(?<![A-Za-z])exit\s+(\d+)\b')
        $exitCodeAssignPattern = [regex]::new('\bexitCode\s*=\s*(\d+)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        foreach ($wrapperName in $wrapperScanList) {
            $wrapperPath = Join-Path $PSScriptRoot $wrapperName
            if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
                Add-Finding -Code 'WRAPPER_MISSING' -Message "Wrapper ausente: $wrapperName"
                continue
            }

            $text = [System.IO.File]::ReadAllText($wrapperPath)
            $found = [System.Collections.Generic.HashSet[int]]::new()

            foreach ($m in $exitPattern.Matches($text)) {
                [void]$found.Add([int]$m.Groups[1].Value)
            }
            foreach ($m in $exitCodeAssignPattern.Matches($text)) {
                [void]$found.Add([int]$m.Groups[1].Value)
            }

            foreach ($code in $found) {
                if ($code -eq 0) {
                    continue
                }
                if (-not $catalogExits.Contains($code)) {
                    Add-Finding -Code 'EXIT_UNDOCUMENTED' -Message "exit $code em $wrapperName nao consta em codes[]."
                }
            }
        }

        # Lockstep do exit 46: causa 'watcher-sem-monitor-log' deriva os 5 wrappers do
        # proprio catalogo; helper deve conter a atribuicao literal da causa e cada
        # wrapper deve propagar causeId no payload JSON do bloqueio.
        $exit46Entry = @($catalog.codes | Where-Object { [int]$_.exit -eq 46 })[0]
        if ($null -eq $exit46Entry) {
            Add-Finding -Code 'CATALOG_46_CAUSE' -Message 'Entrada de exit 46 ausente no catalogo.'
        }
        else {
            $watcherCause = @($exit46Entry.causes | Where-Object { $_.id -eq 'watcher-sem-monitor-log' })[0]
            if ($null -eq $watcherCause) {
                Add-Finding -Code 'CATALOG_46_CAUSE' -Message "Causa 'watcher-sem-monitor-log' ausente em causes[] do exit 46."
            }
            else {
                $causeWrappers = @($watcherCause.wrappers)
                $expectedWrappers = @(
                    'Invoke-GeneXusKbBuildAll.ps1'
                    'Invoke-GeneXusKbSpecifyGenerate.ps1'
                    'Invoke-GeneXusXpzImport.ps1'
                    'Invoke-GeneXusXpzExport.ps1'
                    'Test-GeneXusXpzImportPreview.ps1'
                )
                foreach ($expected in $expectedWrappers) {
                    if ($causeWrappers -notcontains $expected) {
                        Add-Finding -Code 'CATALOG_46_CAUSE' -Message "Wrapper esperado ausente na causa 'watcher-sem-monitor-log': $expected"
                    }
                }
                foreach ($w in $causeWrappers) {
                    if ($expectedWrappers -notcontains $w) {
                        Add-Finding -Code 'CATALOG_46_CAUSE' -Message "Wrapper inesperado na causa 'watcher-sem-monitor-log': $w"
                    }
                }

                $watcherSupportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildWatcherSupport.ps1'
                if (-not (Test-Path -LiteralPath $watcherSupportPath -PathType Leaf)) {
                    Add-Finding -Code 'WRAPPER_MISSING' -Message "Helper ausente: GeneXusMsBuildWatcherSupport.ps1"
                }
                else {
                    $supportText = [System.IO.File]::ReadAllText($watcherSupportPath)
                    if ($supportText -notmatch 'causeId\s*=\s*''watcher-sem-monitor-log''') {
                        Add-Finding -Code 'CAUSEID_LITERAL' -Message "Helper GeneXusMsBuildWatcherSupport.ps1 deve conter a atribuicao literal causeId = 'watcher-sem-monitor-log'."
                    }
                }

                foreach ($w in $causeWrappers) {
                    $wrapperPath = Join-Path $PSScriptRoot $w
                    if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
                        Add-Finding -Code 'WRAPPER_MISSING' -Message "Wrapper ausente: $w"
                        continue
                    }
                    $text = [System.IO.File]::ReadAllText($wrapperPath)
                    if ($text -notmatch 'causeId\s*=\s*\$watcherParameterValidation\.causeId') {
                        Add-Finding -Code 'CAUSEID_MISSING' -Message "Wrapper $w deve propagar causeId = `$watcherParameterValidation.causeId no payload de exit 46."
                    }
                }
            }
        }
    }
}

$ok = ($findings.Count -eq 0)
$result = [ordered]@{
    ok       = $ok
    catalog  = 'scripts/msbuild-exit-codes.catalog.json'
    findings = @($findings)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    if ($ok) {
        Write-Output 'MSBUILD_EXIT_CODES_CATALOG_OK'
    }
    else {
        foreach ($f in $findings) {
            Write-Output ("{0}: {1}" -f $f.code, $f.message)
        }
    }
}

if (-not $ok) {
    exit 1
}

exit 0
