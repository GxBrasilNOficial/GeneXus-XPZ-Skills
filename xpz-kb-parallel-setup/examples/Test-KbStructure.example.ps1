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
    'Test-KbMetadataWrapper.ps1',
    'Test-KbStructure.ps1'
)) {
    Test-Component -Label "scripts\$script" -Path (Join-Path $scriptsDir $script) -Type Leaf
}

Test-Component -Label 'KbIntelligence\kb-intelligence.sqlite' `
    -Path (Join-Path $KbRoot 'KbIntelligence\kb-intelligence.sqlite') -Type Leaf

# Auditoria de parse dos scripts esperados
foreach ($scriptName in @(
    'Update-KbFromXpz.ps1',
    'Test-KbFullSnapshot.ps1',
    'Query-KbIntelligence.ps1',
    'Rebuild-KbIntelligenceIndex.ps1',
    'Test-KbGate.ps1',
    'Get-KbMetadata.ps1',
    'Test-KbMetadataWrapper.ps1',
    'Test-KbStructure.ps1'
)) {
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

# Auditoria de naming em ObjetosDaKbEmXml
$acervoPath = Join-Path $KbRoot 'ObjetosDaKbEmXml'
$namingDivergencias = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $acervoPath -PathType Container) {
    $guidToType = @{
        '36e32e2d-023e-4188-95df-d13573bac2e0' = 'API'
        '3affc0b3-494b-4d84-9ec1-3a6ab8349cda' = 'ColorPalette'
        '526aba9f-a725-4bc7-b1db-0b9f92ac9550' = 'Dashboard'
        '2a9e9aba-d2de-4801-ae7f-5e3819222daf' = 'DataProvider'
        'ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af' = 'DataSelector'
        'dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0' = 'DataStore'
        'bf08dfb1-361c-4e7e-ad54-391e56e60b49' = 'DeploymentUnit'
        '78b3fa0e-174c-4b2b-8716-718167a428b5' = 'DesignSystem'
        'faeb588c-dcce-4dad-9af3-cdd11b961a32' = 'Document'
        '00972a17-9975-449e-aab1-d26165d51393' = 'Domain'
        'c163e562-42c6-4158-ad83-5b21a14cf30e' = 'ExternalObject'
        '1132ac08-290f-4fd1-bd18-64777b7329d1' = 'File'
        'ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0' = 'Generator'
        '9fb193d9-64a4-4d30-b129-ff7c76830f7e' = 'Image'
        '88313f43-5eb2-0000-0028-e8d9f5bf9588' = 'Language'
        'd82625fd-5892-40b0-99c9-5c8559c197fc' = 'Panel'
        '83476c1e-fa72-4229-9930-f51b954fca2d' = 'PatternSettings'
        '84a12160-f59b-4ad7-a683-ea4481ac23e9' = 'Procedure'
        '447527b5-9210-4523-898b-5dccb17be60a' = 'SDT'
        '624a8b31-36f0-4292-adba-2d270d1e3537' = 'Stencil'
        '87313f43-5eb2-41d7-9b8c-e8d9f5bf9588' = 'SubTypeGroup'
        '857ca50e-7905-0000-0007-c5d9ff2975ec' = 'Table'
        'c804fdbd-7c0b-440d-8527-4316c92649a6' = 'Theme'
        'd4876646-98dd-419b-8c1c-896f83c48368' = 'ThemeClass'
        '5592de59-d30a-499d-9100-a7006d3674f2' = 'ThemeColor'
        '1db606f2-af09-4cf9-a3b5-b481519d28f6' = 'Transaction'
        '562f4793-aabe-449f-8821-fc77e550698e' = 'UserControl'
        'c9584656-94b6-4ccd-890f-332d11fc2c25' = 'WebPanel'
        '78cecefe-be7d-4980-86ce-8d6e91fba04b' = 'WorkWithForWeb'
        '00000000-0000-0000-0000-000000000008' = 'Folder'
        '00000000-0000-0000-0000-000000000006' = 'Module'
        'c88fffcd-b6f8-0000-8fec-00b5497e2117' = 'PackagedModule'
    }
    foreach ($dir in Get-ChildItem -LiteralPath $acervoPath -Directory | Sort-Object Name) {
        $xml = Get-ChildItem -LiteralPath $dir.FullName -Filter '*.xml' | Select-Object -First 1
        if (-not $xml) { continue }
        $content = Get-Content -LiteralPath $xml.FullName -Raw
        $first1024 = $content.Substring(0, [Math]::Min(1024, $content.Length))
        if ($first1024 -match '^\s*<\?xml[^>]*\?>\s*<Attributes?\b') {
            $canonicalType = 'Attribute'
        } elseif ($content -match '<Object\b[^>]*\btype="([^"]+)"') {
            $guid = $Matches[1]
            $canonicalType = if ($guidToType.ContainsKey($guid)) { $guidToType[$guid] } else { "GUID_DESCONHECIDO:$guid" }
        } else {
            $canonicalType = 'DESCONHECIDO'
        }
        $dirName = $dir.Name
        if ($dirName -eq $canonicalType) {
            $results.Add([pscustomobject]@{
                Component = "ObjetosDaKbEmXml\$dirName"
                Status    = 'NAMING_OK'
                Path      = $dir.FullName
            })
        } else {
            $results.Add([pscustomobject]@{
                Component = "ObjetosDaKbEmXml\$dirName"
                Status    = 'NAMING_DIVERGENTE'
                Path      = "tipo real: $canonicalType; renomear para '$canonicalType' via xpz-kb-parallel-setup"
            })
            $namingDivergencias.Add("  $dirName -> $canonicalType")
        }
    }
}

$results | Format-Table -AutoSize

if ($namingDivergencias.Count -gt 0) {
    Write-Warning "$($namingDivergencias.Count) diretorio(s) em ObjetosDaKbEmXml com nome divergente do tipo canonico:"
    $namingDivergencias | ForEach-Object { Write-Warning $_ }
    Write-Warning "Corrija os nomes via xpz-kb-parallel-setup (modo_atualizacao)."
}

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
