#requires -Version 7.4
<#
.SYNOPSIS
    Provas sintéticas da v5: consumidores reais, sem KB/IDE/import/build.
    SkipGate isola somente a prova temporal do Build; não é receita operacional.
    Após sucesso, remove somente a pasta temporária criada nesta execução.
    Em falha, preserva os artefatos restantes e informa o caminho para diagnóstico.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GeneXusXmlSurgicalEditSupport.ps1')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('lastupdate-consumers-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
try {
$utf8 = Get-Utf8NoBomEncoding
$guid = 'bbbbbbbb-0000-0000-0000-000000000001'
$type = '447527b5-9210-4523-898b-5dccb17be60a'
$old = '2024-01-01T00:00:00.0000000Z'
$script:checks = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "ASSERT_FAILED: $Message" }
}
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
function Xml([string]$Root = 'Object', [string]$Id = $guid, [string]$Stamp = $old, [string]$Name = 'Teste') {
    return "<$Root guid=`"$Id`" name=`"$Name`" type=`"$type`" lastUpdate=`"$Stamp`" checksum=`"abc`">`r`n<Part type=`"babf62c5-0111-49e9-a1c3-cc004d90900a`"><InnerHtml><![CDATA[a]]></InnerHtml><Properties /></Part>`r`n</$Root>`r`n"
}
function Stamp([string]$Path) { return (Get-FirstObjectLastUpdateFromText -Text ([IO.File]::ReadAllText($Path))).Value }
function Run([string]$Script, [hashtable]$Arguments) {
    $raw = @(& (Join-Path $PSScriptRoot $Script) @Arguments) -join "`n"
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{ Exit = $exitCode; Json = ($raw | ConvertFrom-Json); Raw = $raw }
}
function Bump([hashtable]$Options) {
    $Options['AsJson'] = $true
    return (Run 'Set-GeneXusXmlLastUpdate.ps1' $Options)
}
function Edit([hashtable]$Options) {
    if (-not $Options.ContainsKey('Anchor')) { $Options['Anchor'] = 'CDATA[a' }
    if (-not $Options.ContainsKey('Replacement')) { $Options['Replacement'] = 'CDATA[b' }
    $Options['EditMode'] = 'Replace'; $Options['AsJson'] = $true
    return (Run 'Edit-GeneXusXmlSurgical.ps1' $Options)
}
function Window([string]$Path, [DateTimeOffset]$Before, [DateTimeOffset]$After) {
    $raw = Stamp $Path
    $instant = [DateTimeOffset]::Parse($raw)
    Assert-True ($instant -ge $Before.AddSeconds(59) -and $instant -le $After.AddSeconds(60)) 'janela UtcNow+60, resolução de segundo'
    Assert-True ($raw -cmatch '\.0000000Z$') 'formato literal no XML'
}
$acervo = Join-Path $testRoot 'ObjetosDaKbEmXml'
[void][IO.Directory]::CreateDirectory($acervo)
$template = Join-Path $testRoot 'template.import_file.xml'
Write-Text $template '<ExportFile><KMW name="Sintetica" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" /><Source kb="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" /><Dependencies /><ObjectsIdentityMapping /></ExportFile>'
$script:package = 0
function Envelope([string]$Path, [int]$Expected = 0) {
    $script:package++
    $out = Join-Path $testRoot ("Frente_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_20261009_{0:d2}.import_file.xml" -f $script:package)
    $r = Run 'Build-GeneXusImportFileEnvelope.ps1' @{ ObjectXmlPaths = @($Path); TemplatePackagePath = $template; OutputPath = $out; AcervoPath = $acervo; ModifiedObjectGuids = @($guid); SkipGate = $true }
    Assert-True ($r.Exit -eq $Expected) "envelope temporal exit $Expected : $($r.Raw)"
    Assert-True ((Test-Path -LiteralPath $out) -eq ($Expected -eq 0)) 'materialização de pacote somente em aceite'
}
$inputXml = Join-Path $testRoot 'Teste.xml'
$baseline = Join-Path $testRoot 'baseline.xml'
$outputXml = Join-Path $testRoot 'saida.xml'

# Ambos consumidores: recuperação de futuro acumulado, sequência rápida e default.
foreach ($consumer in @('setter', 'editor')) {
    Write-Text $inputXml (Xml -Stamp ([DateTime]::UtcNow.AddMinutes(20).ToString('o')))
    for ($i = 0; $i -lt 4; $i++) {
        $beforeText = [IO.File]::ReadAllText($inputXml)
        $before = [DateTimeOffset]::UtcNow
        if ($consumer -eq 'setter') { $r = Bump @{ InputPath = $inputXml; NewObjectNotImported = $true } }
        else {
            $anchor = "CDATA[$i"; if ($i -eq 0) { $anchor = 'CDATA[a' }
            $r = Edit @{ InputPath = $inputXml; NewObjectNotImported = $true; Anchor = $anchor; Replacement = "CDATA[$($i+1)" }
        }
        Assert-True ($r.Exit -eq 0 -and $r.Json.newObjectNotImported) 'modo novo aplicado'
        Window $inputXml $before ([DateTimeOffset]::UtcNow)
        Envelope $inputXml
        $afterText = [IO.File]::ReadAllText($inputXml)
        Assert-True ($afterText.Contains("`r`n") -and -not $afterText.Replace("`r`n", '').Contains("`n")) 'CRLF preservado'
        Assert-True ($afterText.Contains("guid=`"$guid`"") -and $afterText.Contains('<![CDATA[')) 'identidade e CDATA preservados'
        if ($consumer -eq 'setter') {
            Assert-True (($beforeText -replace 'lastUpdate="[^"]+"', '') -ceq ($afterText -replace 'lastUpdate="[^"]+"', '')) 'setter só muda lastUpdate'
        }
        $json = [System.Text.Json.JsonDocument]::Parse($r.Raw)
        try { Assert-True ($json.RootElement.GetProperty('lastUpdateAfter').GetString() -ceq (Stamp $inputXml)) 'JSON literal sem coerção' } finally { $json.Dispose() }
    }
    Write-Text $inputXml (Xml)
    for ($i = 0; $i -lt 4; $i++) {
        if ($consumer -eq 'setter') { $r = Bump @{ InputPath = $inputXml } }
        else {
            $anchor = "CDATA[$i"; if ($i -eq 0) { $anchor = 'CDATA[a' }
            $r = Edit @{ InputPath = $inputXml; Anchor = $anchor; Replacement = "CDATA[$($i+1)" }
        }
        Assert-True ($r.Exit -eq 0 -and -not $r.Json.newObjectNotImported) 'default preservado'
    }
    Envelope $inputXml 20
}

# Contradições precedem âncora/no-op/EOL e NO_LASTUPDATE; 14/15 precedem 30.
foreach ($dry in @($false, $true)) {
    foreach ($separate in @($false, $true)) {
        Write-Text $inputXml '<Object />'
        Write-Text $outputXml 'sentinela'
        foreach ($consumer in @('setter', 'editor')) {
            $args = @{ InputPath = $inputXml; NewObjectNotImported = $true; DryRun = $dry }
            if ($separate) { $args['OutputPath'] = $outputXml }
            if ($consumer -eq 'setter') { $args['BaselineXmlPath'] = 'inexistente'; $r = Bump $args }
            else { $args['PreserveLastUpdate'] = $true; $args['Anchor'] = ''; $r = Edit $args }
            Assert-True ($r.Exit -eq 30 -and $r.Json.code -eq 'LASTUPDATE_CONTEXT_CONFLICT') 'conflito estruturado'
            Assert-True ([IO.File]::ReadAllText($inputXml) -ceq '<Object />') 'input intacto'
            Assert-True ([IO.File]::ReadAllText($outputXml) -ceq 'sentinela') 'output intacto'
            Assert-True (-not (Test-Path "$inputXml.bak") -and -not (Test-Path "$outputXml.bak")) 'sem backup'
            $args['InputPath'] = Join-Path $testRoot 'ausente.xml'
            if ($consumer -eq 'setter') { $r = Bump $args } else { $r = Edit $args }
            Assert-True ($r.Exit -eq 14) '14 antes de 30'
            $args['InputPath'] = $inputXml; $args['OutputPath'] = Join-Path $testRoot 'ausente/saida.xml'
            if ($consumer -eq 'setter') { $r = Bump $args } else { $r = Edit $args }
            Assert-True ($r.Exit -eq 15) '15 antes de 30'
        }
    }
}

# Baseline explícito: raízes, GUID normalizado, renomeio, erro em ambos os lados.
foreach ($root in @('Object', 'Attribute')) {
    foreach ($id in @('', 'inválido', '00000000-0000-0000-0000-000000000000', 'cccccccc-0000-0000-0000-000000000001', $guid.ToUpperInvariant())) {
        Write-Text $inputXml (Xml -Root $root)
        Write-Text $baseline (Xml -Root $root -Id $id -Name 'NomeAnterior')
        foreach ($consumer in @('setter', 'editor')) {
            foreach ($dry in @($false, $true)) {
                $args = @{ InputPath = $inputXml; OutputPath = $outputXml; DryRun = $dry }
                $outputBefore = [IO.File]::ReadAllText($outputXml)
                if ($consumer -eq 'setter') { $args['BaselineXmlPath'] = $baseline; $r = Bump $args }
                else { $args['LastUpdateBaselinePath'] = $baseline; $r = Edit $args }
                $expected = 31; if ($id -ceq $guid.ToUpperInvariant()) { $expected = 0 }
                Assert-True ($r.Exit -eq $expected) "baseline $root/$id : $($r.Raw)"
                if ($expected -eq 31) {
                    Assert-True ($r.Json.code -eq 'LASTUPDATE_BASELINE_IDENTITY_MISMATCH') 'code identidade'
                    Assert-True ([IO.File]::ReadAllText($inputXml) -ceq (Xml -Root $root)) 'identidade: input intacto'
                    Assert-True (-not (Test-Path "$outputXml.bak")) 'identidade: sem backup'
                    Assert-True ([IO.File]::ReadAllText($outputXml) -ceq $outputBefore) 'identidade: saída separada intacta'
                }
            }
        }
    }
}
foreach ($badXml in @((Xml -Root 'Attribute'), (Xml -Root 'Outro'), (Xml -Id 'inválido'), ('<!DOCTYPE Object>' + (Xml)), '<!-- lastUpdate="2024-01-01T00:00:00.0000000Z" sem raiz -->')) {
    Write-Text $inputXml (Xml); Write-Text $baseline $badXml
    Assert-True ((Bump @{ InputPath = $inputXml; BaselineXmlPath = $baseline }).Exit -eq 31) 'raiz divergente/ilegível no baseline'
    Write-Text $baseline (Xml); Write-Text $inputXml $badXml
    Assert-True ((Edit @{ InputPath = $inputXml; LastUpdateBaselinePath = $baseline; Anchor = '>'; Replacement = '> ' ; ExpectedAnchorCount = ([regex]::Matches($badXml, '>').Count); ApplyToAllOccurrences = $true }).Exit -eq 31) 'raiz inválida no input'
}
Write-Text $inputXml ((Xml).Replace('</Object>', '</Errado>')); Write-Text $baseline (Xml)
$r = Edit @{ InputPath = $inputXml; LastUpdateBaselinePath = $baseline; Anchor = '</Errado>'; Replacement = '</Object>' }
Assert-True ($r.Exit -eq 0) 'corpo reparável sem parse antecipado'
Assert-True ((Edit @{ InputPath = $inputXml; LastUpdateBaselinePath = 'ausente'; PreserveLastUpdate = $true }).Exit -eq 0) 'Preserve ignora baseline (c20)'
Assert-True ((Bump @{ InputPath = $inputXml; BaselineXmlPath = 'ausente' }).Exit -eq 16) 'baseline inexistente continua 16'

# Contradições editor com baseline: também antes de no-op e EOL; whitespace não conflita.
foreach ($pair in @(@{ Anchor = 'CDATA[a'; Replacement = 'CDATA[a' }, @{ Anchor = 'CDATA[a'; Replacement = "CDATA[b`n" })) {
    Write-Text $inputXml (Xml)
    $pair['InputPath'] = $inputXml; $pair['NewObjectNotImported'] = $true; $pair['LastUpdateBaselinePath'] = $baseline
    Assert-True ((Edit $pair).Exit -eq 30) 'conflito antes de no-op/EOL'
}
Write-Text $inputXml (Xml)
Assert-True ((Edit @{ InputPath = $inputXml; NewObjectNotImported = $true; LastUpdateBaselinePath = '   '; DryRun = $true }).Exit -eq 0) 'baseline branco é omitido no editor'
Assert-True ((Bump @{ InputPath = $inputXml; NewObjectNotImported = $true; BaselineXmlPath = '   '; DryRun = $true }).Exit -eq 0) 'baseline branco é omitido no setter'
Write-Text $baseline ((Xml).Replace("guid=`"$guid`"", ''))
Assert-True ((Bump @{ InputPath = $inputXml; BaselineXmlPath = $baseline }).Exit -eq 31) 'GUID ausente explícito'
Write-Text $baseline ('<?xml version="1.0"?><!-- prefixo --><?teste valor?>' + (Xml -Name 'Anterior'))
Assert-True ((Edit @{ InputPath = $inputXml; LastUpdateBaselinePath = $baseline; DryRun = $true }).Exit -eq 0) 'XML declaration/comentário/PI antes da raiz'
Assert-True (([IO.File]::ReadAllBytes($inputXml))[0] -ne 239) 'UTF-8 sem BOM no XML'
$rawGenerator = [string](& (Join-Path $PSScriptRoot 'Get-GeneXusXpzLastUpdate.ps1') -Count 1)
Assert-True ($rawGenerator -cmatch '\.0000000Z$') 'formato literal da emissão bruta do gerador'

# Futuro oficial e importação apenas modelada: referência velha não garante avanço.
$future = [DateTime]::UtcNow.AddMinutes(10).ToString("yyyy-MM-ddTHH:mm:ss.0000000Z")
Write-Text $inputXml (Xml); Write-Text $baseline (Xml -Stamp $future)
$r = Bump @{ InputPath = $inputXml; BaselineXmlPath = $baseline }
$live = Stamp $inputXml
Assert-True ([DateTimeOffset]::Parse($live) -eq [DateTimeOffset]::Parse($future).AddSeconds(60)) 'margem sobre referência futura'
$r = Bump @{ InputPath = $inputXml; BaselineXmlPath = $baseline }
Assert-True ((Stamp $inputXml) -ceq $live) 'baseline velho pode repetir o vivo modelado'
Write-Text $baseline ([IO.File]::ReadAllText($inputXml))
$r = Bump @{ InputPath = $inputXml; BaselineXmlPath = $baseline }
Assert-True ([DateTimeOffset]::Parse((Stamp $inputXml)) -eq [DateTimeOffset]::Parse($live).AddSeconds(60)) 'referência renovada supera vivo modelado'

# Lote: opt-in, misto, default, existing e recarimbo final.
$front = Join-Path $testRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus/Frente'
[void][IO.Directory]::CreateDirectory((Join-Path $front 'SDT'))
[void][IO.Directory]::CreateDirectory((Join-Path $acervo 'SDT'))
$newPath = Join-Path $front 'SDT/Teste.xml'
$existingPath = Join-Path $front 'SDT/Existente.xml'
$existingGuid = 'cccccccc-0000-0000-0000-000000000001'
$official = Join-Path $acervo 'SDT/Existente.xml'
Write-Text $official (Xml -Id $existingGuid -Name 'Existente')
Write-Text $existingPath ([IO.File]::ReadAllText($official))
Write-Text $newPath (Xml -Stamp $future)
$manifest = Join-Path $testRoot 'manifest.json'
function Operation([string]$Name, [string]$Id, [string]$State, [string]$Previous, [string]$Next) {
    $op = @{ id = $Name; op = 'setDocumentation'; objectState = $State; target = @{ guid = $Id; expectedType = 'SDT'; expectedName = $Name; xmlPath = "SDT/$Name.xml" }; new = @{ documentation = $Next } }
    if ($State -eq 'existing') { $op['expected'] = @{ documentation = $Previous } }
    return $op
}
function Batch([object[]]$Operations, [bool]$NewMode, [bool]$Apply = $true, [string]$Report = '') {
    Write-Text $manifest (@{ Kind = 'xpz-batch-metadata-manifest'; SchemaVersion = 1; operations = $Operations } | ConvertTo-Json -Depth 10)
    $args = @{ InputPath = $manifest; FrontFolder = $front; NewObjectsNotImported = $NewMode; Apply = $Apply }
    if ($Report -ne '') { $args['ReportPath'] = $Report }
    return (Run 'Edit-GeneXusXmlBatchMetadata.ps1' $args)
}
for ($i = 0; $i -lt 4; $i++) {
    $previous = 'a'; if ($i -gt 0) { $previous = "doc$i" }
    $ops = @((Operation 'Teste' $guid 'new' $previous "doc$($i+1)"), (Operation 'Existente' $existingGuid 'existing' $previous "doc$($i+1)"))
    $before = [DateTimeOffset]::UtcNow
    $plan = Batch $ops $true $false
    Assert-True ($plan.Exit -eq 0 -and $plan.Json.files[0].baselineSource -eq 'new-not-imported') 'previsão usa ramo explícito'
    $r = Batch $ops $true
    Assert-True ($r.Exit -eq 0 -and $r.Json.newObjectsNotImported) "lote misto: $($r.Raw)"
    Assert-True ($r.Json.files[0].baselineSource -eq 'new-not-imported' -and $r.Json.files[1].baselineSource -ne 'new-not-imported') 'somente new descarta frente'
    Assert-True (@($r.Json.warnings | Where-Object { $_.kind -eq 'baselineFutureAnomaly' -and $_.path -eq 'SDT/Teste.xml' }).Count -eq 0) 'sem aviso para termo descartado'
    Window $newPath $before ([DateTimeOffset]::UtcNow)
    Envelope $newPath
    $journal = [IO.File]::ReadAllText($r.Json.journalPath) | ConvertFrom-Json
    Assert-True $journal.newObjectsNotImported 'journal registra declaração'
}
Envelope $existingPath 20
$r = Bump @{ InputPath = $existingPath; BaselineXmlPath = $official }
Assert-True ($r.Exit -eq 0) 'recarimbo existing após lote acumulativo'
Envelope $existingPath
$r = Batch @((Operation 'Existente' $existingGuid 'existing' 'doc4' 'final')) $true
Assert-True ($r.Exit -eq 0 -and $r.Json.files[0].baselineSource -ne 'new-not-imported') 'switch sem new preserva existing'
Write-Text $newPath (Xml -Stamp $future)
$report = Join-Path $testRoot 'blocked.json'
$r = Batch @((Operation 'Teste' $guid 'new' 'a' 'b')) $false $true $report
Assert-True ($r.Exit -eq 20 -and @($r.Json.blocks.code) -contains 'NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE') 'default lote mantém bloqueio'
Assert-True (-not $r.Json.newObjectsNotImported -and (Test-Path $report)) 'ReportPath em falha preservado'
Write-Text $newPath (Xml)
for ($i = 0; $i -lt 3; $i++) {
    $r = Batch @((Operation 'Teste' $guid 'new' '' "default$i")) $false
    if ($i -lt 2) { Assert-True ($r.Exit -eq 0) 'default new: rodadas iniciais' }
    else { Assert-True ($r.Exit -eq 20 -and @($r.Json.blocks.code) -contains 'NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE') 'default new: terceiro acúmulo bloqueado' }
}
Write-Text $newPath ((Xml).Replace('</Object>', '</Errado>'))
$r = Batch @((Operation 'Teste' $guid 'new' 'a' 'b')) $true
Assert-True ($r.Exit -eq 20) 'opt-in mantém bloqueio de XML malformado'
Write-Text $newPath (Xml -Stamp 'inválido')
$r = Batch @((Operation 'Teste' $guid 'new' 'a' 'b')) $true
Assert-True ($r.Exit -eq 20 -and @($r.Json.blocks.code) -contains 'LASTUPDATE_UNREADABLE') 'opt-in não oculta valor inválido'
Write-Text $newPath (Xml); Write-Text (Join-Path $acervo 'SDT/Teste.xml') (Xml)
$r = Batch @((Operation 'Teste' $guid 'new' 'a' 'b')) $true
Assert-True ($r.Exit -eq 20) 'opt-in mantém sanidade de ausência no acervo'
$r = Run 'Edit-GeneXusXmlBatchMetadata.ps1' @{ InputPath = $manifest; FrontFolder = (Join-Path $testRoot 'ausente'); NewObjectsNotImported = $true }
Assert-True ($r.Exit -eq 20 -and $r.Json.newObjectsNotImported) 'rastro na falha mais precoce'
# A primeira gravação do journal já contém a declaração, mesmo sem steps.
$journalPath = Join-Path $testRoot 'primeiro.journal.json'
. (Join-Path $PSScriptRoot 'GeneXusXmlBatchMetadataSupport.ps1')
$j = New-GeneXusBatchJournal -Path $journalPath -RunId 'sintetico' -WorkDir $testRoot -NewObjectsNotImported
$firstJournal = [IO.File]::ReadAllText($journalPath) | ConvertFrom-Json
Assert-True ($firstJournal.newObjectsNotImported -and @($firstJournal.steps).Count -eq 0) 'primeira materialização do journal'
# Antes da remoção recursiva, confirmar o filho direto e o nome gerado nesta execução.
$cleanupRoot = [IO.Path]::GetFullPath($testRoot)
$cleanupParent = [IO.Path]::GetDirectoryName($cleanupRoot)
$expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
if (-not [string]::Equals($cleanupParent, $expectedParent, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($cleanupRoot) -cnotmatch '^lastupdate-consumers-[0-9a-f]{32}$') {
    throw "Caminho temporário inesperado; limpeza recusada: $cleanupRoot"
}
Remove-Item -LiteralPath $cleanupRoot -Recurse -Force -ErrorAction Stop
Write-Output "LASTUPDATE_CONSUMER_CONTRACT_OK: $script:checks verificações; fixtures removidas=$testRoot"
} catch {
    Write-Warning "Falha na bateria; artefatos restantes preservados para diagnóstico: $testRoot"
    throw
}
