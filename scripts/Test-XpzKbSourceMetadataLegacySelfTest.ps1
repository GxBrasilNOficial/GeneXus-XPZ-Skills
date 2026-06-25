#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do ramo legado de XpzKbSourceMetadataEditSupport.ps1 (-IsLegacyExport).

.DESCRIPTION
    Exercita Update-XpzKbSourceMetadataFromSync com as 3 salvaguardas da Opcao 1
    (spec congelada Fase 2 v2.8.5, secao 4.4 / 6.4 a-b):
    (a) export legado (-IsLegacyExport $true, KMW/MaxGxBuildSaved, sem <Source>): Build
        preenchido por MaxGxBuildSaved; hint legado literal presente; warning generico ausente;
    (b) NAO-REGRESSAO moderno: o MESMO pacote sem -IsLegacyExport mantem o comportamento atual
        (warning generico quando Source ausente; sem hint legado; sem fallback de Build);
    (c) NAO-REGRESSAO moderno completo: pacote moderno com KMW/Build e Source completo ->
        status 'complete', sem warnings, Build vindo de KMW/Build.
    Token de sucesso no stdout + exit 0.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptsRoot 'XpzKbSourceMetadataEditSupport.ps1')

function New-MetaPath {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('legacy-meta-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
    [void](New-Item -ItemType Directory -Path $root)
    return @{ Root = $root; Meta = (Join-Path $root 'kb-source-metadata.md') }
}

function New-LegacyXmlDoc {
    [xml]$doc = @'
<ExportFile>
  <KMW>
    <MajorVersion>2</MajorVersion>
    <MinorVersion>2</MinorVersion>
    <MaxGxBuildSaved>2601</MaxGxBuildSaved>
  </KMW>
</ExportFile>
'@
    return $doc
}

function New-ModernCompleteXmlDoc {
    [xml]$doc = @'
<ExportFile>
  <KMW>
    <MajorVersion>18</MajorVersion>
    <MinorVersion>0</MinorVersion>
    <Build>250000</Build>
  </KMW>
  <Source kb="11111111-1111-1111-1111-111111111111" username="dev" UNCPath="\\srv\kb">
    <Version guid="22222222-2222-2222-2222-222222222222" name="Trunk"/>
  </Source>
</ExportFile>
'@
    return $doc
}

$genericNeedles = @(
    'KMW ou Source vieram ausentes',
    'Source incompleto'
)

# =====================================================================================
# (a) export legado: -IsLegacyExport $true
# =====================================================================================
$ctxA = New-MetaPath
try {
    $docA = New-LegacyXmlDoc
    $resultA = Update-XpzKbSourceMetadataFromSync -XmlDocument $docA -SourceXpzPath 'C:\fake\fin.xpz' -MetadataPath $ctxA.Meta -IsLegacyExport $true
    $warningsA = @($resultA.Warnings)

    if ($warningsA -notcontains $script:LegacyExportMetadataHintMessage) {
        throw "(a): hint legado literal ausente nos warnings. Obtido: $($warningsA -join ' || ')"
    }
    foreach ($needle in $genericNeedles) {
        if (@($warningsA | Where-Object { $_ -like "*$needle*" }).Count -gt 0) {
            throw "(a): warning generico '$needle' NAO deveria aparecer no ramo legado."
        }
    }
    $metaTextA = Get-Content -LiteralPath $ctxA.Meta -Raw
    if ($metaTextA -notmatch '(?m)^\|\s*Build\s*\|\s*2601\s*\|') {
        throw '(a): Build=2601 (MaxGxBuildSaved) nao gravado no metadata legado.'
    }
} finally {
    if (Test-Path -LiteralPath $ctxA.Root) { Remove-Item -LiteralPath $ctxA.Root -Recurse -Force }
}

# =====================================================================================
# (b) NAO-REGRESSAO moderno: MESMO pacote sem -IsLegacyExport
# =====================================================================================
$ctxB = New-MetaPath
try {
    $docB = New-LegacyXmlDoc
    $resultB = Update-XpzKbSourceMetadataFromSync -XmlDocument $docB -SourceXpzPath 'C:\fake\fin.xpz' -MetadataPath $ctxB.Meta
    $warningsB = @($resultB.Warnings)

    if ($warningsB -contains $script:LegacyExportMetadataHintMessage) {
        throw '(b): hint legado NAO deveria aparecer sem -IsLegacyExport.'
    }
    # Source ausente -> warning generico esperado (comportamento atual preservado)
    if (@($warningsB | Where-Object { $_ -like '*KMW ou Source vieram ausentes*' }).Count -eq 0) {
        throw "(b): warning generico de KMW/Source ausente esperado no ramo moderno. Obtido: $($warningsB -join ' || ')"
    }
    # Sem fallback de Build no ramo moderno: Build permanece vazio
    $metaTextB = Get-Content -LiteralPath $ctxB.Meta -Raw
    if ($metaTextB -match '(?m)^\|\s*Build\s*\|\s*2601\s*\|') {
        throw '(b): Build NAO deveria receber fallback MaxGxBuildSaved sem -IsLegacyExport.'
    }
} finally {
    if (Test-Path -LiteralPath $ctxB.Root) { Remove-Item -LiteralPath $ctxB.Root -Recurse -Force }
}

# =====================================================================================
# (c) NAO-REGRESSAO moderno completo: status complete, sem warnings, Build de KMW/Build
# =====================================================================================
$ctxC = New-MetaPath
try {
    $docC = New-ModernCompleteXmlDoc
    $resultC = Update-XpzKbSourceMetadataFromSync -XmlDocument $docC -SourceXpzPath 'C:\fake\modern.xpz' -MetadataPath $ctxC.Meta
    if ($resultC.MetadataStatus -ne 'complete') { throw "(c): MetadataStatus='$($resultC.MetadataStatus)' (esperado complete)." }
    if (@($resultC.Warnings).Count -ne 0) { throw "(c): pacote moderno completo nao deveria emitir warnings. Obtido: $(@($resultC.Warnings) -join ' || ')" }
    $metaTextC = Get-Content -LiteralPath $ctxC.Meta -Raw
    if ($metaTextC -notmatch '(?m)^\|\s*Build\s*\|\s*250000\s*\|') { throw '(c): Build=250000 (KMW/Build) nao gravado no metadata moderno.' }
} finally {
    if (Test-Path -LiteralPath $ctxC.Root) { Remove-Item -LiteralPath $ctxC.Root -Recurse -Force }
}

Write-Output 'XPZ_KB_SOURCE_METADATA_LEGACY_SELFTEST_OK'
exit 0
