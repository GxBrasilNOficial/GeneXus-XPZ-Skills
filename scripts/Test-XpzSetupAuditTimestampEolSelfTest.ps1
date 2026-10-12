#requires -Version 7.4

<#
.SYNOPSIS
    Valida que Set-XpzSetupAuditTimestamp.ps1 preserva EOL LF em kb-source-metadata.md.

.DESCRIPTION
    Grava fixture LF, executa update e insert de last_setup_audit_run_at e da
    assinatura de contrato de setup, e verifica que nenhum CR foi introduzido
    na reescrita.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = Split-Path -Parent $PSCommandPath
$timestampScriptPath = Join-Path $scriptDir 'Set-XpzSetupAuditTimestamp.ps1'

function Get-CarriageReturnCount {
    param([string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    return ([regex]::Matches($raw, "`r")).Count
}

function New-LfMetadataFixture {
    param(
        [string]$RootPath,
        [switch]$IncludeAuditField
    )

    $lines = @(
        '---'
        'name: KB Source Metadata'
        'last_xpz_materialization_run_at: 2026-01-01T00:00:00.0000000+00:00'
    )

    if ($IncludeAuditField) {
        $lines += 'last_setup_audit_run_at: 2026-01-01T00:00:00.0000000+00:00'
    }

    $lines += @(
        '---'
        ''
        '## Source'
        ''
        '| Campo | Valor |'
        '|---|---|'
        '| kb (GUID) | {11111111-1111-1111-1111-111111111111} |'
        ''
        '## Source/Version'
        ''
        '| Campo | Valor |'
        '|---|---|'
        '| name | DemoKb |'
        ''
    )

    $content = ($lines -join "`n") + "`n"
    $metadataPath = Join-Path $RootPath 'kb-source-metadata.md'
    $utf8NoBom = (Get-Utf8NoBomEncoding)
    [System.IO.File]::WriteAllText($metadataPath, $content, $utf8NoBom)
    return $metadataPath
}

function Assert-ZeroCr {
    param(
        [string]$Path,
        [string]$Message
    )

    $crCount = Get-CarriageReturnCount -Path $Path
    if ($crCount -ne 0) {
        throw "ASSERT_FAILED: $Message | crCount=$crCount path=$Path"
    }
}

function Assert-ContainsField {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $raw = [System.IO.File]::ReadAllText($Path)
    if ($raw -notmatch $Pattern) {
        throw "ASSERT_FAILED: $Message | path=$Path"
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-setup-audit-ts-eol-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$updateRoot = Join-Path $tempRoot 'update'
$insertRoot = Join-Path $tempRoot 'insert'
$auditTimestamp = '2026-05-28T12:34:56.7890123+00:00'

try {
    [void](New-Item -ItemType Directory -Path $updateRoot -Force)
    [void](New-Item -ItemType Directory -Path $insertRoot -Force)

    $updateMetadataPath = New-LfMetadataFixture -RootPath $updateRoot -IncludeAuditField
    Assert-ZeroCr -Path $updateMetadataPath -Message 'fixture update deve iniciar sem CR'

    $updateOutput = & $timestampScriptPath -KbParallelRoot $updateRoot -AuditTimestamp $auditTimestamp 2>&1 | ForEach-Object { $_.ToString() }
    if ($updateOutput -notmatch 'SETUP_AUDIT_TIMESTAMP_OK') {
        throw "ASSERT_FAILED: update nao retornou SETUP_AUDIT_TIMESTAMP_OK | output=$updateOutput"
    }

    Assert-ZeroCr -Path $updateMetadataPath -Message 'update deve preservar EOL LF'
    Assert-ContainsField -Path $updateMetadataPath -Pattern 'last_setup_audit_run_at:\s*2026-05-28T12:34:56\.7890123\+00:00' -Message 'update deve gravar timestamp informado'
    Assert-ContainsField -Path $updateMetadataPath -Pattern 'setup_contract_signature_version:\s*xpz-setup-contract-signature-v1' -Message 'update deve gravar versao da assinatura de contrato'
    Assert-ContainsField -Path $updateMetadataPath -Pattern 'setup_contract_signature_hash:\s*[0-9a-f]{64}' -Message 'update deve gravar hash da assinatura de contrato'

    $insertMetadataPath = New-LfMetadataFixture -RootPath $insertRoot
    Assert-ZeroCr -Path $insertMetadataPath -Message 'fixture insert deve iniciar sem CR'

    $insertOutput = & $timestampScriptPath -KbParallelRoot $insertRoot -AuditTimestamp $auditTimestamp 2>&1 | ForEach-Object { $_.ToString() }
    if ($insertOutput -notmatch 'SETUP_AUDIT_TIMESTAMP_OK') {
        throw "ASSERT_FAILED: insert nao retornou SETUP_AUDIT_TIMESTAMP_OK | output=$insertOutput"
    }

    Assert-ZeroCr -Path $insertMetadataPath -Message 'insert deve preservar EOL LF'
    Assert-ContainsField -Path $insertMetadataPath -Pattern 'last_setup_audit_run_at:\s*2026-05-28T12:34:56\.7890123\+00:00' -Message 'insert deve gravar timestamp informado'
    Assert-ContainsField -Path $insertMetadataPath -Pattern 'setup_contract_signature_version:\s*xpz-setup-contract-signature-v1' -Message 'insert deve gravar versao da assinatura de contrato'
    Assert-ContainsField -Path $insertMetadataPath -Pattern 'setup_contract_signature_hash:\s*[0-9a-f]{64}' -Message 'insert deve gravar hash da assinatura de contrato'

    Write-Output 'XPZ_SETUP_AUDIT_TIMESTAMP_EOL_SELFTEST_OK'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
