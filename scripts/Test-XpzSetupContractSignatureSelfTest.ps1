#requires -Version 7.4

<#
.SYNOPSIS
    Valida o contrato de assinatura usado pelo freshness de setup.

.DESCRIPTION
    Cobre a migracao conservadora sem assinatura gravada, o caminho GATE_ONLY
    após gravar assinatura, mudanca fora da superficie assinada e mudanca dentro
    da superficie assinada.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptDir

$utf8NoBomEncodingSupportPath = Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function Write-Utf8NoBomText {
    param(
        [string]$Path,
        [string]$Text
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }

    $utf8NoBom = Get-Utf8NoBomEncoding
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Copy-SelfTestScript {
    param(
        [string]$Name,
        [string]$DestinationScriptsDir
    )

    Copy-Item -LiteralPath (Join-Path $scriptDir $Name) -Destination (Join-Path $DestinationScriptsDir $Name) -Force
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw "ASSERT_FAILED: $Message | output=$Text"
    }
}

function Invoke-Freshness {
    param(
        [string]$KbRoot,
        [string]$SkillsRoot
    )

    $freshnessPath = Join-Path $SkillsRoot 'scripts\Test-XpzSetupFreshness.ps1'
    $output = & $freshnessPath -KbParallelRoot $KbRoot -SkillsRoot $SkillsRoot 2>&1 | ForEach-Object { $_.ToString() }
    return ($output -join [Environment]::NewLine).Trim()
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-setup-contract-signature-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$skillsRoot = Join-Path $tempRoot 'skills'
$kbRoot = Join-Path $tempRoot 'kb'
$tempScriptsDir = Join-Path $skillsRoot 'scripts'
$tempSetupDir = Join-Path $skillsRoot 'xpz-kb-parallel-setup'
$tempExamplesDir = Join-Path $tempSetupDir 'examples'
$auditTimestamp = '2026-06-04T12:00:00.0000000+00:00'

try {
    [void](New-Item -ItemType Directory -Path $tempScriptsDir -Force)
    [void](New-Item -ItemType Directory -Path $tempExamplesDir -Force)
    [void](New-Item -ItemType Directory -Path $kbRoot -Force)

    Copy-SelfTestScript -Name 'Get-XpzSetupContractSignature.ps1' -DestinationScriptsDir $tempScriptsDir
    Copy-SelfTestScript -Name 'Test-XpzSetupFreshness.ps1' -DestinationScriptsDir $tempScriptsDir
    Copy-SelfTestScript -Name 'Set-XpzSetupAuditTimestamp.ps1' -DestinationScriptsDir $tempScriptsDir
    Copy-SelfTestScript -Name 'XpzTextFileEolSupport.ps1' -DestinationScriptsDir $tempScriptsDir
    Copy-SelfTestScript -Name 'Utf8NoBomEncodingSupport.ps1' -DestinationScriptsDir $tempScriptsDir

    $manifestText = @'
{
  "signatureVersion": "xpz-setup-contract-signature-v1",
  "description": "Fixture de self-test",
  "include": [
    "xpz-kb-parallel-setup/SKILL.md",
    "xpz-kb-parallel-setup/examples/*",
    "scripts/Get-XpzSetupContractSignature.ps1",
    "scripts/Test-XpzSetupFreshness.ps1",
    "scripts/Set-XpzSetupAuditTimestamp.ps1"
  ]
}
'@

    Write-Utf8NoBomText -Path (Join-Path $tempSetupDir 'setup-contract.manifest.json') -Text $manifestText
    Write-Utf8NoBomText -Path (Join-Path $tempSetupDir 'SKILL.md') -Text "# xpz-kb-parallel-setup`n`nContrato fixture.`n"
    Write-Utf8NoBomText -Path (Join-Path $tempExamplesDir 'Test-KbSetupFreshness.example.ps1') -Text "#requires -Version 7.4`n# fixture`n"
    Write-Utf8NoBomText -Path (Join-Path $skillsRoot '08-guia-para-agente-gpt.md') -Text "fora da superficie assinada`n"

    $metadataPath = Join-Path $kbRoot 'kb-source-metadata.md'
    $metadataText = @"
---
name: KB Source Metadata
last_xpz_materialization_run_at: 2026-06-04T11:00:00.0000000+00:00
last_setup_audit_run_at: $auditTimestamp
---

## Source
"@
    Write-Utf8NoBomText -Path $metadataPath -Text ($metadataText + "`n")

    $migrationOutput = Invoke-Freshness -KbRoot $kbRoot -SkillsRoot $skillsRoot
    Assert-Contains -Text $migrationOutput -Pattern 'AUDIT_REQUIRED: campo setup_contract_signature_version ausente' -Message 'metadata sem assinatura deve exigir auditoria de migracao'

    $setTimestampPath = Join-Path $tempScriptsDir 'Set-XpzSetupAuditTimestamp.ps1'
    $setOutput = & $setTimestampPath -KbParallelRoot $kbRoot -SkillsRoot $skillsRoot -AuditTimestamp $auditTimestamp 2>&1 | ForEach-Object { $_.ToString() }
    Assert-Contains -Text ($setOutput -join ' ') -Pattern 'SETUP_AUDIT_TIMESTAMP_OK' -Message 'gravacao de timestamp deve passar'

    $gateOnlyOutput = Invoke-Freshness -KbRoot $kbRoot -SkillsRoot $skillsRoot
    Assert-Contains -Text $gateOnlyOutput -Pattern '^GATE_ONLY$' -Message 'assinatura gravada deve liberar caminho leve'

    Write-Utf8NoBomText -Path (Join-Path $skillsRoot '08-guia-para-agente-gpt.md') -Text "mudanca irrelevante ao contrato de setup`n"
    $outsideOutput = Invoke-Freshness -KbRoot $kbRoot -SkillsRoot $skillsRoot
    Assert-Contains -Text $outsideOutput -Pattern '^GATE_ONLY$' -Message 'mudanca fora da superficie assinada nao deve exigir auditoria'

    Write-Utf8NoBomText -Path (Join-Path $tempExamplesDir 'Test-KbSetupFreshness.example.ps1') -Text "#requires -Version 7.4`n# fixture alterado`n"
    $insideOutput = Invoke-Freshness -KbRoot $kbRoot -SkillsRoot $skillsRoot
    Assert-Contains -Text $insideOutput -Pattern 'AUDIT_REQUIRED: contrato de setup atualizado' -Message 'mudanca na superficie assinada deve exigir auditoria'

    Write-Output 'XPZ_SETUP_CONTRACT_SIGNATURE_SELFTEST_OK'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
