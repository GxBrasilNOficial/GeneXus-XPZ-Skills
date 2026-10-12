#requires -Version 7.4

<#
.SYNOPSIS
    Valida que Update-XpzKbSourceMetadataFromSync preserva last_setup_audit_run_at, setup_contract_signature_* e EOL LF.

.DESCRIPTION
    Fixture LF com carimbo/assinatura de setup e tabelas minimas; simula refresh de materialização
    e verifica campos de setup intactos, CR=0 e campos de materialização atualizados.
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
$editSupportPath = Join-Path $scriptDir 'XpzKbSourceMetadataEditSupport.ps1'
$auditTimestamp = '2026-01-15T08:00:00.0000000+00:00'
$setupSignatureVersion = '2026-06-04T00:00:00Z'
$setupSignatureHash = 'sha256:selftest-setup-contract'
$oldMaterializationTimestamp = '2026-01-01T00:00:00.0000000+00:00'

function Get-CarriageReturnCount {
    param([string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    return ([regex]::Matches($raw, "`r")).Count
}

function New-LfMetadataFixture {
    param([string]$RootPath)

    $lines = @(
        '---'
        'name: KB Source Metadata'
        'description: fixture de self-test'
        'last_xpz_materialization_run_at: 2026-01-01T00:00:00.0000000+00:00'
        'last_setup_audit_run_at: ' + $auditTimestamp
        'setup_contract_signature_version: ' + $setupSignatureVersion
        'setup_contract_signature_hash: ' + $setupSignatureHash
        'custom_future_field: keep-me'
        'source_xpz: C:\Old\Package.xpz'
        'source_refresh_status: partial-preserved'
        '---'
        ''
        '## KMW'
        ''
        '| Campo | Valor |'
        '|---|---|'
        '| MajorVersion | 17 |'
        '| MinorVersion | 0 |'
        '| Build | 100 |'
        ''
        '## Source'
        ''
        '| Campo | Valor |'
        '|---|---|'
        '| kb (GUID) | {11111111-1111-1111-1111-111111111111} |'
        '| username | olduser |'
        '| UNCPath | \\old\share |'
        ''
        '## Source/Version'
        ''
        '| Campo | Valor |'
        '|---|---|'
        '| guid | {22222222-2222-2222-2222-222222222222} |'
        '| name | OldVersion |'
        ''
        '## Uso'
        ''
        'Texto auxiliar preservado pelo self-test.'
    )

    $content = ($lines -join "`n") + "`n"
    $metadataPath = Join-Path $RootPath 'kb-source-metadata.md'
    $utf8NoBom = (Get-Utf8NoBomEncoding)
    [System.IO.File]::WriteAllText($metadataPath, $content, $utf8NoBom)
    return $metadataPath
}

function New-MinimalExportFileXml {
    param([string]$Path)

    $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW>
    <MajorVersion>18</MajorVersion>
    <MinorVersion>1</MinorVersion>
    <Build>200</Build>
  </KMW>
  <Source kb="{33333333-3333-3333-3333-333333333333}" username="newuser" UNCPath="\\new\share">
    <Version guid="{44444444-4444-4444-4444-444444444444}" name="NewVersion" />
  </Source>
  <Objects />
</ExportFile>
'@

    $utf8NoBom = (Get-Utf8NoBomEncoding)
    [System.IO.File]::WriteAllText($Path, $xml, $utf8NoBom)
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

function Assert-ContainsPattern {
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

function Assert-NotContainsPattern {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $raw = [System.IO.File]::ReadAllText($Path)
    if ($raw -match $Pattern) {
        throw "ASSERT_FAILED: $Message | path=$Path"
    }
}

. $editSupportPath

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-sync-kb-metadata-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$packageXmlPath = Join-Path $tempRoot 'minimal-export.xml'
$sourceXpzPath = 'C:\Dev\Test\Packages\SelfTestPackage.xpz'

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    $metadataPath = New-LfMetadataFixture -RootPath $tempRoot
    New-MinimalExportFileXml -Path $packageXmlPath

    Assert-ZeroCr -Path $metadataPath -Message 'fixture deve iniciar sem CR'
    Assert-ContainsPattern -Path $metadataPath -Pattern ('last_setup_audit_run_at:\s*' + [regex]::Escape($auditTimestamp)) -Message 'fixture deve conter carimbo de setup'
    Assert-ContainsPattern -Path $metadataPath -Pattern ('setup_contract_signature_version:\s*' + [regex]::Escape($setupSignatureVersion)) -Message 'fixture deve conter versao da assinatura de setup'
    Assert-ContainsPattern -Path $metadataPath -Pattern ('setup_contract_signature_hash:\s*' + [regex]::Escape($setupSignatureHash)) -Message 'fixture deve conter hash da assinatura de setup'

    [xml]$packageXml = Get-Content -LiteralPath $packageXmlPath -Raw
    $result = Update-XpzKbSourceMetadataFromSync -XmlDocument $packageXml -SourceXpzPath $sourceXpzPath -MetadataPath $metadataPath

    if ($result.WriteMode -ne 'surgical-update') {
        throw "ASSERT_FAILED: esperado WriteMode surgical-update | actual=$($result.WriteMode)"
    }

    Assert-ZeroCr -Path $metadataPath -Message 'refresh de materializacao deve preservar EOL LF'
    Assert-ContainsPattern -Path $metadataPath -Pattern ('last_setup_audit_run_at:\s*' + [regex]::Escape($auditTimestamp)) -Message 'carimbo de setup deve permanecer intacto'
    Assert-ContainsPattern -Path $metadataPath -Pattern ('setup_contract_signature_version:\s*' + [regex]::Escape($setupSignatureVersion)) -Message 'versao da assinatura de setup deve permanecer intacta'
    Assert-ContainsPattern -Path $metadataPath -Pattern ('setup_contract_signature_hash:\s*' + [regex]::Escape($setupSignatureHash)) -Message 'hash da assinatura de setup deve permanecer intacto'
    Assert-NotContainsPattern -Path $metadataPath -Pattern ('last_xpz_materialization_run_at:\s*' + [regex]::Escape($oldMaterializationTimestamp)) -Message 'timestamp de materializacao antigo deve ser substituido'

    $rawAfter = [System.IO.File]::ReadAllText($metadataPath)
    if ($rawAfter -notmatch '(?m)^updated:\s*(.+)$') {
        throw 'ASSERT_FAILED: campo updated ausente apos refresh'
    }
    $updatedValue = $Matches[1].Trim()
    if ($rawAfter -notmatch '(?m)^last_xpz_materialization_run_at:\s*(.+)$') {
        throw 'ASSERT_FAILED: campo last_xpz_materialization_run_at ausente apos refresh'
    }
    $materializedValue = $Matches[1].Trim()
    if ($updatedValue -ne $materializedValue) {
        throw "ASSERT_FAILED: updated e last_xpz_materialization_run_at devem coincidir | updated=$updatedValue materialized=$materializedValue"
    }
    if ($materializedValue -eq $oldMaterializationTimestamp) {
        throw 'ASSERT_FAILED: timestamp de materializacao nao foi atualizado'
    }
    Assert-ContainsPattern -Path $metadataPath -Pattern ('source_xpz:\s*' + [regex]::Escape($sourceXpzPath)) -Message 'source_xpz deve ser atualizado'
    Assert-ContainsPattern -Path $metadataPath -Pattern 'source_refresh_status:\s*complete' -Message 'source_refresh_status deve refletir Source completo do pacote'
    Assert-ContainsPattern -Path $metadataPath -Pattern '\| MajorVersion \| 18 \|' -Message 'tabela KMW MajorVersion deve ser atualizada'
    Assert-ContainsPattern -Path $metadataPath -Pattern '\| username \| newuser \|' -Message 'tabela Source username deve ser atualizada'
    Assert-ContainsPattern -Path $metadataPath -Pattern 'custom_future_field:\s*keep-me' -Message 'frontmatter fora do escopo do sync deve ser preservado'
    Assert-ContainsPattern -Path $metadataPath -Pattern 'Texto auxiliar preservado pelo self-test' -Message 'secao ## Uso deve ser preservada'
    Assert-NotContainsPattern -Path $metadataPath -Pattern '\| username \| olduser \|' -Message 'valor antigo de username nao deve permanecer'

    Write-Output 'XPZ_SYNC_KB_METADATA_SELFTEST_OK'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
