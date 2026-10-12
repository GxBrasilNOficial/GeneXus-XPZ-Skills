#requires -Version 7.4

<#
.SYNOPSIS
Wrapper local sanitizado para verificar a estrutura da pasta paralela da KB.

.DESCRIPTION
Verifica presenca de pastas obrigatórias, scripts esperados,
KbIntelligence\kb-intelligence.sqlite e kb-source-metadata.md. Retorna relatório
de presenca/ausencia de cada componente. Usado no setup inicial e em diagnostico
antes de qualquer operacao.

Os nomes de script verificados usam a forma curta sanitizada; na KB real, substituir
pelos nomes definitivos com o identificador da KB (ex: Test-FabricaBrasilKbIndexGate.ps1).
A auditoria detalhada de naming dos diretórios de ObjetosDaKbEmXml fica no wrapper
dedicado `Test-KbObjetosDaKbNaming.ps1`.

.PARAMETER KbRoot
Caminho opcional para a raiz da pasta paralela da KB.
Quando omitido, usa a pasta pai da pasta scripts deste wrapper.

.EXAMPLE
.\Test-KbStructure.ps1

.EXAMPLE
.\Test-KbStructure.ps1 -KbRoot "C:\CAMINHO\PARA\PastaParalelaDaKb"
#>

param(
    [string]$KbRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $KbRoot) {
    $KbRoot = Split-Path -Parent $PSScriptRoot
}

$results = [System.Collections.Generic.List[pscustomobject]]::new()

function Test-Component {
    param(
        [string]$Label,
        [string]$Path,
        [string]$Type  # 'Container' ou 'Leaf'
    )
    $exists = Test-Path -LiteralPath $Path -PathType $Type
    $results.Add([pscustomobject]@{
        Component = $Label
        Status    = if ($exists) { 'OK' } else { 'AUSENTE' }
        Path      = $Path
    })
}

foreach ($folder in @(
    'scripts',
    'Temp',
    'XpzExportadosPelaIDE',
    'ObjetosDaKbEmXml',
    'KbIntelligence',
    'ObjetosGeradosParaImportacaoNaKbNoGenexus',
    'PacotesGeradosParaImportacaoNaKbNoGenexus'
)) {
    Test-Component -Label "pasta\$folder" -Path (Join-Path $KbRoot $folder) -Type Container
}

foreach ($file in @('AGENTS.md', 'README.md', 'kb-source-metadata.md')) {
    Test-Component -Label $file -Path (Join-Path $KbRoot $file) -Type Leaf
}

$scriptsDir = Join-Path $KbRoot 'scripts'
foreach ($script in @(
    'Update-KbFromXpz.ps1',
    'Test-KbFullSnapshot.ps1',
    'Test-KbSetupFreshness.ps1',
    'Test-KbPowerShellRuntime.ps1',
    'Test-KbObjetosDaKbNaming.ps1',
    'Query-KbIntelligence.ps1',
    'Rebuild-KbIntelligenceIndex.ps1',
    'Test-KbIndexGate.ps1',
    'Get-KbMetadata.ps1',
    'Test-KbMetadataWrapper.ps1',
    'Test-KbStructure.ps1',
    'Test-KbSetupAudit.ps1'
)) {
    Test-Component -Label "scripts\$script" -Path (Join-Path $scriptsDir $script) -Type Leaf
}

foreach ($script in @(
    'New-KbImportPackage.ps1',
    'Set-KbSetupAuditTimestamp.ps1'
)) {
    $optionalPath = Join-Path $scriptsDir $script
    if (Test-Path -LiteralPath $optionalPath -PathType Leaf) {
        Test-Component -Label "scripts\$script" -Path $optionalPath -Type Leaf
    }
}

Test-Component -Label 'KbIntelligence\kb-intelligence.sqlite' `
    -Path (Join-Path $KbRoot 'KbIntelligence\kb-intelligence.sqlite') -Type Leaf

# Auditoria de parse dos scripts esperados
$scriptsToParse = @(
    'Update-KbFromXpz.ps1',
    'Test-KbFullSnapshot.ps1',
    'Test-KbSetupFreshness.ps1',
    'Test-KbPowerShellRuntime.ps1',
    'Test-KbObjetosDaKbNaming.ps1',
    'Query-KbIntelligence.ps1',
    'Rebuild-KbIntelligenceIndex.ps1',
    'Test-KbIndexGate.ps1',
    'Get-KbMetadata.ps1',
    'Test-KbMetadataWrapper.ps1',
    'Test-KbStructure.ps1',
    'Test-KbSetupAudit.ps1'
)

foreach ($optionalScriptName in @('New-KbImportPackage.ps1', 'Set-KbSetupAuditTimestamp.ps1')) {
    if (Test-Path -LiteralPath (Join-Path $scriptsDir $optionalScriptName) -PathType Leaf) {
        $scriptsToParse += $optionalScriptName
    }
}

foreach ($scriptName in $scriptsToParse) {
    $scriptPath = Join-Path $scriptsDir $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { continue }
    $parseTokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$parseTokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        $errorSummary = ($parseErrors | ForEach-Object { "linha $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
        $results.Add([pscustomobject]@{
            Component = "scripts\$scriptName"
            Status    = 'PARSE_ERROR'
            Path      = $errorSummary
        })
    }
}

$results | Format-Table -AutoSize

$blocked = @($results | Where-Object { $_.Status -in @('AUSENTE', 'PARSE_ERROR') })
if ($blocked.Count -gt 0) {
    $ausenteCount = @($results | Where-Object { $_.Status -eq 'AUSENTE' }).Count
    $parseCount   = @($results | Where-Object { $_.Status -eq 'PARSE_ERROR' }).Count
    if ($ausenteCount -gt 0) {
        Write-Warning ("$ausenteCount componente(s) ausente(s). Execute xpz-kb-parallel-setup para corrigir.")
    }
    if ($parseCount -gt 0) {
        Write-Warning ("$parseCount script(s) com erro de parse detectado pelo parser do PowerShell. Corrija antes de continuar.")
    }
    exit 1
}

Write-Output 'STRUCTURE_OK'
