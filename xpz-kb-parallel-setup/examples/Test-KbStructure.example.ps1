#requires -version 5.1
<#
.SYNOPSIS
Wrapper local sanitizado para verificar a estrutura da pasta paralela da KB.

.DESCRIPTION
Verifica presenca de pastas obrigatorias, scripts esperados,
KbIntelligence\kb-intelligence.sqlite e kb-source-metadata.md. Retorna relatorio
de presenca/ausencia de cada componente. Usado no setup inicial e em diagnostico
antes de qualquer operacao.

Os nomes de script verificados usam a forma curta sanitizada; na KB real, substituir
pelos nomes definitivos com o identificador da KB (ex: Test-FabricaBrasilKbGate.ps1).

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
    'Query-KbIntelligence.ps1',
    'Rebuild-KbIntelligenceIndex.ps1',
    'Test-KbGate.ps1',
    'Get-KbMetadata.ps1',
    'Test-KbStructure.ps1'
)) {
    Test-Component -Label "scripts\$script" -Path (Join-Path $scriptsDir $script) -Type Leaf
}

Test-Component -Label 'KbIntelligence\kb-intelligence.sqlite' `
    -Path (Join-Path $KbRoot 'KbIntelligence\kb-intelligence.sqlite') -Type Leaf

$results | Format-Table -AutoSize

$blocked = @($results | Where-Object { $_.Status -eq 'AUSENTE' })
if ($blocked.Count -gt 0) {
    Write-Warning ("$($blocked.Count) componente(s) ausente(s). Execute xpz-kb-parallel-setup para corrigir.")
    exit 1
}

Write-Host 'STRUCTURE_OK' -ForegroundColor Green
