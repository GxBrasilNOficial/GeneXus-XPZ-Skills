#requires -Version 7.4

<#
.SYNOPSIS
    Grava last_setup_audit_run_at e a assinatura do contrato de setup em kb-source-metadata.md.

.DESCRIPTION
    Atualiza ou insere somente os campos last_setup_audit_run_at,
    setup_contract_signature_version e setup_contract_signature_hash, preservando
    o restante do arquivo (conteúdo, EOL dominante e newline final).
    Autoridade desta operacao: xpz-kb-parallel-setup (auditoria de setup bem-sucedida).

    Projetado para ser chamado pelo wrapper local Set-*KbSetupAuditTimestamp.ps1 após auditoria
    completa com estado canonico bem-sucedido ou no subestado setup_apto_com_metadata_pendente.

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB (deve conter kb-source-metadata.md).

.PARAMETER AuditTimestamp
    Timestamp ISO 8601 com fuso horario. Quando omitido, usa o instante atual do sistema.

.PARAMETER SkillsRoot
    Raiz do repositório de skills XPZ. Quando omitido, usa a raiz pai da pasta scripts.

.PARAMETER AsJson
    Emite objeto JSON em vez de texto simples.

.OUTPUTS
    String "SETUP_AUDIT_TIMESTAMP_OK: <timestamp>" ou JSON com status.

.EXAMPLE
    .\Set-XpzSetupAuditTimestamp.ps1 -KbParallelRoot "C:\DevTests\Gx_MyCinema"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbParallelRoot,

    [string]$AuditTimestamp,

    [string]$SkillsRoot,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$metadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
  throw "BLOCK: kb-source-metadata.md ausente em $KbParallelRoot"
}

$isoValue = $null
if ([string]::IsNullOrWhiteSpace($AuditTimestamp)) {
  $isoValue = (Get-Date).ToString('o')
} else {
  try {
    $parsed = [DateTimeOffset]::Parse($AuditTimestamp.Trim())
    $isoValue = $parsed.ToString('o')
  } catch {
    throw "BLOCK: AuditTimestamp nao e timestamp valido: '$AuditTimestamp'"
  }
}

. (Join-Path $PSScriptRoot 'XpzTextFileEolSupport.ps1')

if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
  $SkillsRoot = Split-Path -Parent $PSScriptRoot
}

$signatureScriptPath = Join-Path $SkillsRoot 'scripts\Get-XpzSetupContractSignature.ps1'
if (-not (Test-Path -LiteralPath $signatureScriptPath -PathType Leaf)) {
  throw "BLOCK: motor de assinatura do contrato de setup ausente: $signatureScriptPath"
}

$signatureJson = & $signatureScriptPath -SkillsRoot $SkillsRoot -AsJson
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($signatureJson)) {
  throw "BLOCK: nao foi possivel calcular assinatura atual do contrato de setup em $SkillsRoot"
}

$currentSignature = $signatureJson | ConvertFrom-Json

$fileContext = Get-TextFileLineContext -Path $metadataPath
$fileLines = $fileContext.Lines

function Get-MetadataFieldLineIndex {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$FieldName
  )

  $fieldPattern = '^\s*{0}\s*[:=]\s*.+$' -f [regex]::Escape($FieldName)
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match $fieldPattern) {
      return $i
    }
  }

  return -1
}

function Get-DefaultMetadataInsertIndex {
  param(
    [System.Collections.Generic.List[string]]$Lines
  )

  $insertAt = -1
  $frontmatterClose = -1
  $hasFrontmatter = ($Lines.Count -gt 0 -and $Lines[0].Trim() -eq '---')

  if ($hasFrontmatter) {
    for ($i = 1; $i -lt $Lines.Count; $i++) {
      if ($Lines[$i].Trim() -eq '---') {
        $frontmatterClose = $i
        break
      }
    }

    if ($frontmatterClose -gt 0) {
      $insertAt = $frontmatterClose
      for ($j = 1; $j -lt $frontmatterClose; $j++) {
        if ($Lines[$j] -match '^\s*last_xpz_materialization_run_at\s*[:=]') {
          $insertAt = $j + 1
        }
      }
    }
  } else {
    for ($i = 0; $i -lt $Lines.Count; $i++) {
      if ($Lines[$i] -match '^\s*##\s+') {
        $insertAt = $i
        break
      }
    }

    if ($insertAt -lt 0) {
      $insertAt = $Lines.Count
    }

    for ($j = 0; $j -lt $insertAt; $j++) {
      if ($Lines[$j] -match '^\s*last_xpz_materialization_run_at\s*[:=]') {
        $insertAt = $j + 1
      }
    }
  }

  if ($insertAt -lt 0) {
    if ($frontmatterClose -gt 0) {
      $insertAt = $frontmatterClose
    } else {
      $insertAt = 0
    }
  }

  return $insertAt
}

function Set-MetadataFieldLine {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$FieldName,
    [string]$Value,
    [string]$AfterFieldName
  )

  $newFieldLine = "${FieldName}: $Value"
  $existingIndex = Get-MetadataFieldLineIndex -Lines $Lines -FieldName $FieldName
  if ($existingIndex -ge 0) {
    $Lines[$existingIndex] = $newFieldLine
    return
  }

  $insertAt = -1
  if (-not [string]::IsNullOrWhiteSpace($AfterFieldName)) {
    $afterIndex = Get-MetadataFieldLineIndex -Lines $Lines -FieldName $AfterFieldName
    if ($afterIndex -ge 0) {
      $insertAt = $afterIndex + 1
    }
  }

  if ($insertAt -lt 0) {
    $insertAt = Get-DefaultMetadataInsertIndex -Lines $Lines
  }

  $Lines.Insert($insertAt, $newFieldLine)
}

Set-MetadataFieldLine -Lines $fileLines -FieldName 'last_setup_audit_run_at' -Value $isoValue -AfterFieldName ''
Set-MetadataFieldLine -Lines $fileLines -FieldName 'setup_contract_signature_version' -Value $currentSignature.signatureVersion -AfterFieldName 'last_setup_audit_run_at'
Set-MetadataFieldLine -Lines $fileLines -FieldName 'setup_contract_signature_hash' -Value $currentSignature.signatureHash -AfterFieldName 'setup_contract_signature_version'

Write-TextFilePreservingEol -Path $metadataPath -FileContext $fileContext

if ($AsJson) {
  [pscustomobject]@{
    status = 'SETUP_AUDIT_TIMESTAMP_OK'
    last_setup_audit_run_at = $isoValue
    setup_contract_signature_version = $currentSignature.signatureVersion
    setup_contract_signature_hash = $currentSignature.signatureHash
    metadataPath = $metadataPath
  } | ConvertTo-Json -Compress
  exit 0
}

Write-Output "SETUP_AUDIT_TIMESTAMP_OK: $isoValue setup_contract_signature_hash=$($currentSignature.signatureHash)"
exit 0
