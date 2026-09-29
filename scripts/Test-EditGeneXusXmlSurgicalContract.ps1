#requires -Version 7.4
<#
.SYNOPSIS
    Bateria de contrato de Edit-GeneXusXmlSurgical.ps1 (secao 5 da v6 congelada).

.DESCRIPTION
    Cobre os casos base e os 33 itens da secao 5 do desenho congelado
    (edit-genexus-xml-surgical-design.md). O harness e tolerante a stdout nao-JSON
    (erros de binding/bootstrap): preserva Raw + exitCode em try/catch, sem
    engolir stderr.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
. (Join-Path $PSScriptRoot 'GeneXusXmlSurgicalEditSupport.ps1')

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir 'Edit-GeneXusXmlSurgical.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Edit-GeneXusXmlSurgical.ps1 nao encontrado: $scriptPath"
}

$script:failures = 0
$script:cases = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $script:failures++
        Write-Host "FAIL: $Message" -ForegroundColor Red
    }
}

function Assert-Eq {
    param([object]$Expected, [object]$Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        $script:failures++
        Write-Host "FAIL: $Message (esperado=$Expected obtido=$Actual)" -ForegroundColor Red
    }
}

function Invoke-Surgical {
    param([hashtable]$Arguments)
    $all = @{}
    foreach ($k in $Arguments.Keys) { $all[$k] = $Arguments[$k] }
    $all['AsJson'] = $true
    $global:LASTEXITCODE = 0
    $raw = ''
    try {
        $raw = (& $scriptPath @all 2>&1 | Out-String)
    } catch {
        $raw = ($_ | Out-String)
    }
    $exitCode = $global:LASTEXITCODE
    $json = $null
    try { $json = $raw | ConvertFrom-Json } catch { $json = $null }
    return [pscustomobject]@{ ExitCode = $exitCode; Json = $json; Raw = $raw.Trim() }
}

function New-Xml {
    param(
        [string]$Body,
        [string]$ExtraAttrs = '',
        [string]$LastUpdate = '2026-05-25T12:00:00.0000000Z'
    )
    return '<Object type="1db606f2-af09-4cf9-a3b5-b481519d28f6" name="ContractTest" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"' +
        $ExtraAttrs + ' lastUpdate="' + $LastUpdate + '">' + "`r`n" +
        '  <Rules><![CDATA[' + "`r`n" + $Body + ']]></Rules>' + "`r`n" +
        '</Object>' + "`r`n"
}

function Write-Fixture {
    param([string]$Path, [string]$Text, [System.Text.Encoding]$Encoding)
    [System.IO.File]::WriteAllText($Path, $Text, $Encoding)
    return $Text
}

function ConvertTo-Instant {
    param([object]$Value)
    if ($null -eq $Value) { throw 'timestamp nulo' }
    if ($Value -is [datetime]) { return [DateTimeOffset]::new($Value.ToUniversalTime()) }
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed)
    if (-not $ok) { throw "timestamp invalido: $Value" }
    return $parsed
}

$utf8 = Get-Utf8NoBomEncoding
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('surgical-contract-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

function New-CaseFile {
    param([string]$Name, [string]$Body, [string]$ExtraAttrs = '', [System.Text.Encoding]$Encoding = $null)
    $path = Join-Path $tempRoot "$Name.xml"
    $enc = if ($null -eq $Encoding) { $utf8 } else { $Encoding }
    [void](Write-Fixture -Path $path -Text (New-Xml -Body $Body -ExtraAttrs $ExtraAttrs) -Encoding $enc)
    return $path
}

try {
    $anchor = 'Default(Field,proc());'
    $loneBody = $anchor + "`r`n"
    $dupBody = $anchor + "`r`n" + $anchor + "`r`n"

    # ---- Base 1: Replace + bump -------------------------------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base1' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = $anchor + "`r`n" + 'Field = 1 if cond;'; EditMode = 'Replace' }
    Assert-Eq 0 $r.ExitCode 'base1 exit'
    Assert-Eq 1 $r.Json.replacementsApplied 'base1 applied'
    $written = [System.IO.File]::ReadAllText($f)
    Assert-True ($written -match 'Field = 1 if cond') 'base1 replacement ausente'
    $baseDto = ConvertTo-Instant '2026-05-25T12:00:00.0000000Z'
    Assert-True ((ConvertTo-Instant $r.Json.lastUpdateAfter) -gt $baseDto) 'base1 bump nao avancou lastUpdate'

    # ---- Base 2: InsertAfter ----------------------------------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base2' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = "`r`n// inserted"; EditMode = 'InsertAfter' }
    Assert-Eq 0 $r.ExitCode 'base2 exit'
    Assert-True ([System.IO.File]::ReadAllText($f).Contains($anchor + "`r`n// inserted")) 'base2 insercao ausente'

    # ---- Base 3: DryRun nao grava ----------------------------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base3' -Body $loneBody
    $before = [System.IO.File]::ReadAllText($f)
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'NOPE'; EditMode = 'Replace'; DryRun = $true }
    Assert-Eq 0 $r.ExitCode 'base3 exit'
    Assert-True ($r.Json.dryRun) 'base3 dryRun esperado true'
    Assert-True ([System.IO.File]::ReadAllText($f) -eq $before) 'base3 arquivo alterado'

    # ---- Base 4: OutputPath copia ----------------------------------------------
    $script:cases++
    $src = New-CaseFile -Name 'base4src' -Body $loneBody
    $dst = Join-Path $tempRoot 'base4dst.xml'
    $srcText = [System.IO.File]::ReadAllText($src)
    $r = Invoke-Surgical @{ InputPath = $src; OutputPath = $dst; Anchor = $anchor; Replacement = $anchor + "`r`n" + 'copied = true;'; EditMode = 'Replace' }
    Assert-Eq 0 $r.ExitCode 'base4 exit'
    Assert-True ([System.IO.File]::ReadAllText($src) -eq $srcText) 'base4 origem alterada'
    Assert-True ([System.IO.File]::ReadAllText($dst) -match 'copied = true') 'base4 destino sem patch'

    # ---- Base 5: ancora ausente -------------------------------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base5' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'ANCORA_INEXISTENTE'; Replacement = 'x'; EditMode = 'Replace' }
    Assert-Eq 11 $r.ExitCode 'base5 exit'
    Assert-Eq 'ANCHOR_FAIL' ([string]$r.Json.code) 'base5 code'

    # ---- Base 6: ancora duplicada (default count 1) ----------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base6' -Body $dupBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'once'; EditMode = 'Replace' }
    Assert-Eq 11 $r.ExitCode 'base6 exit'

    # ---- Base 7: malformado + restore ------------------------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base7' -Body $loneBody
    $orig = [System.IO.File]::ReadAllText($f)
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = ']]></Rules>'; Replacement = 'BROKEN'; EditMode = 'Replace' }
    Assert-Eq 13 $r.ExitCode 'base7 exit'
    Assert-Eq 'XML_NOT_WELLFORMED_AFTER' ([string]$r.Json.code) 'base7 code'
    Assert-True ([System.IO.File]::ReadAllText($f) -eq $orig) 'base7 nao restaurado'

    # ---- Base 8: PreserveLastUpdate --------------------------------------------
    $script:cases++
    $f = New-CaseFile -Name 'base8' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = $anchor + "`r`n" + 'preserved = 1;'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'base8 exit'
    Assert-True ((ConvertTo-Instant $r.Json.lastUpdateAfter) -eq (ConvertTo-Instant '2026-05-25T12:00:00.0000000Z')) 'base8 lastUpdate preservado'

    # ==== 1) Replace 2x + switch -> 2, texto final exato =========================
    $script:cases++
    $f = New-CaseFile -Name 'c1' -Body $dupBody
    $expected1 = New-Xml -Body ('UU' + "`r`n" + 'UU' + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'UU'; EditMode = 'Replace'; ExpectedAnchorCount = 2; ApplyToAllOccurrences = $true; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c1 exit'
    Assert-Eq 2 $r.Json.replacementsApplied 'c1 applied'
    Assert-True ([System.IO.File]::ReadAllText($f) -eq $expected1) 'c1 texto final exato'

    # ==== 2) Replace 2x sem switch -> 18, arquivo byte-identico (apply e dry-run) ==
    $script:cases++
    foreach ($dry in @($false, $true)) {
        $f = New-CaseFile -Name ('c2_' + $dry) -Body $dupBody
        $orig = [System.IO.File]::ReadAllText($f)
        $args = @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; ExpectedAnchorCount = 2 }
        if ($dry) { $args['DryRun'] = $true }
        $r = Invoke-Surgical $args
        Assert-Eq 18 $r.ExitCode ('c2 dry=' + $dry + ' exit')
        Assert-Eq 'AMBIGUOUS_APPLY_SCOPE' ([string]$r.Json.code) ('c2 dry=' + $dry + ' code')
        Assert-True ([System.IO.File]::ReadAllText($f) -eq $orig) ('c2 dry=' + $dry + ' arquivo alterado')
    }

    # ==== 3) InsertAfter 2x +- switch ===========================================
    $script:cases++
    $f = New-CaseFile -Name 'c3a' -Body $dupBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'InsertAfter'; ExpectedAnchorCount = 2; ApplyToAllOccurrences = $true; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c3a exit'
    Assert-Eq 2 $r.Json.replacementsApplied 'c3a applied'
    $t3 = [System.IO.File]::ReadAllText($f)
    Assert-Eq 2 ([regex]::Matches($t3, [regex]::Escape($anchor + 'Z'))).Count 'c3a insercoes'
    $f = New-CaseFile -Name 'c3b' -Body $dupBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'InsertAfter'; ExpectedAnchorCount = 2 }
    Assert-Eq 18 $r.ExitCode 'c3b exit'

    # ==== 4) count 0 / negativo -> 17 ===========================================
    $script:cases++
    foreach ($count in @(0, -3)) {
        $f = New-CaseFile -Name ('c4_' + $count) -Body $loneBody
        $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; ExpectedAnchorCount = $count }
        Assert-Eq 17 $r.ExitCode ('c4 count=' + $count + ' exit')
        Assert-Eq 'EXPECTED_ANCHOR_COUNT_INVALID' ([string]$r.Json.code) ('c4 count=' + $count + ' code')
    }

    # ==== 5) ancora ausente -> 11 (publico e enumerador) ========================
    $script:cases++
    $f = New-CaseFile -Name 'c5' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'NOPE'; Replacement = 'x'; EditMode = 'Replace' }
    Assert-Eq 11 $r.ExitCode 'c5 publico exit'
    $text = [System.IO.File]::ReadAllText($f)
    $idx = [int[]]@(Get-GeneXusXmlAnchorOccurrenceIndexes -Text $text -Anchor 'NOPE')
    Assert-Eq 0 $idx.Count 'c5 enumerador vazio'
    Assert-Eq 0 (Get-AnchorOccurrenceCount -Text $text -Anchor 'NOPE') 'c5 contador vazio'

    # ==== 6) Anchor '' -> 27 (inclusive count 0) ================================
    $script:cases++
    $f = New-CaseFile -Name 'c6' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = ''; Replacement = 'Z'; EditMode = 'Replace'; ExpectedAnchorCount = 0 }
    Assert-Eq 27 $r.ExitCode 'c6 exit'
    Assert-Eq 'ANCHOR_EMPTY' ([string]$r.Json.code) 'c6 code'

    # ==== 7) R>0: apply bem-sucedido reporta replacementsApplied > 0 ============
    $script:cases++
    $f = New-CaseFile -Name 'c7' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace' }
    Assert-Eq 0 $r.ExitCode 'c7 exit'
    Assert-True ([int]$r.Json.replacementsApplied -gt 0) 'c7 replacementsApplied > 0'

    # ==== 8) emenda abb / ab->a =================================================
    $script:cases++
    $f = New-CaseFile -Name 'c8' -Body ('abb' + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'ab'; Replacement = 'a'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c8 exit'
    Assert-Eq (New-Xml -Body ('ab' + "`r`n")) ([System.IO.File]::ReadAllText($f)) 'c8 emenda'

    # ==== 9) sobreposicao aa / aaa =============================================
    $script:cases++
    $f = New-CaseFile -Name 'c9a' -Body ('zzz' + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'zz'; Replacement = 'Q'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c9a exit (count 1)'
    Assert-Eq 1 $r.Json.replacementsApplied 'c9a applied'
    $f = New-CaseFile -Name 'c9b' -Body ('zzz' + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'zz'; Replacement = 'Q'; EditMode = 'Replace'; ExpectedAnchorCount = 2; ApplyToAllOccurrences = $true }
    Assert-Eq 11 $r.ExitCode 'c9b exit (count 2)'

    # ==== 10) ancora sobre o lastUpdate, mantendo o token -> OK =================
    $script:cases++
    $lu = ' lastUpdate="2026-05-25T12:00:00.0000000Z"'
    $f = New-CaseFile -Name 'c10' -Body $loneBody
    $anchor10 = 'name="ContractTest" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"' + $lu
    $repl10 = 'name="ContractTest" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" data-x="1"' + $lu
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor10; Replacement = $repl10; EditMode = 'Replace' }
    Assert-Eq 0 $r.ExitCode 'c10 exit'
    Assert-True ((ConvertTo-Instant $r.Json.lastUpdateAfter) -gt (ConvertTo-Instant '2026-05-25T12:00:00.0000000Z')) 'c10 bump embutido'

    # ==== 11) ancora que remove lastUpdate -> 12 ================================
    $script:cases++
    $f = New-CaseFile -Name 'c11' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor10; Replacement = 'name="ContractTest" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"'; EditMode = 'Replace' }
    Assert-Eq 12 $r.ExitCode 'c11 exit'
    Assert-Eq 'NO_LASTUPDATE' ([string]$r.Json.code) 'c11 code'

    # ==== 12) Replace '' remocao ===============================================
    $script:cases++
    $f = New-CaseFile -Name 'c12' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = ''; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c12 exit'
    Assert-Eq 1 $r.Json.replacementsApplied 'c12 applied'
    Assert-True (-not ([System.IO.File]::ReadAllText($f).Contains($anchor))) 'c12 ancora removida'

    # ==== 13) InsertAfter '' -> 26 =============================================
    $script:cases++
    $f = New-CaseFile -Name 'c13' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = ''; EditMode = 'InsertAfter' }
    Assert-Eq 26 $r.ExitCode 'c13 exit'
    Assert-Eq 'NOOP_REPLACEMENT' ([string]$r.Json.code) 'c13 code'

    # ==== 14) Replace identico -> 26 ===========================================
    $script:cases++
    $f = New-CaseFile -Name 'c14' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = $anchor; EditMode = 'Replace' }
    Assert-Eq 26 $r.ExitCode 'c14 exit'
    Assert-Eq 'NOOP_REPLACEMENT' ([string]$r.Json.code) 'c14 code'

    # ==== 15) CRLF multilinha + Replacement LF -> mismatch true ================
    $script:cases++
    $f = New-CaseFile -Name 'c15' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = ('A' + "`n" + 'B'); EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 'CRLF' ([string]$r.Json.detectedEol) 'c15 detectedEol'
    Assert-True ($r.Json.replacementEolMismatch -eq $true) 'c15 mismatch true'

    # ==== 16) Mixed -> null + sourceEolMixed true ==============================
    $script:cases++
    $mixed = New-Xml -Body ($anchor + "`n")
    $f = Join-Path $tempRoot 'c16.xml'
    $mixed = $mixed.Replace("`r`n", "`n").Replace("`n  <Rules", "`r`n  <Rules")
    [void](Write-Fixture -Path $f -Text $mixed -Encoding $utf8)
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = ('A' + "`n" + 'B'); EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 'MIXED' ([string]$r.Json.detectedEol) 'c16 detectedEol'
    Assert-True ($r.Json.sourceEolMixed -eq $true) 'c16 sourceEolMixed true'
    Assert-True ($null -eq $r.Json.replacementEolMismatch) 'c16 mismatch null'

    # ==== 17) Replacement sem quebra -> false; fonte so-CR =====================
    $script:cases++
    $f = New-CaseFile -Name 'c17a' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-True ($r.Json.replacementEolMismatch -eq $false) 'c17a mismatch false'
    $crText = (New-Xml -Body ($anchor + "`r")).Replace("`r`n", "`r")
    $f = Join-Path $tempRoot 'c17b.xml'
    [void](Write-Fixture -Path $f -Text $crText -Encoding $utf8)
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = ('A' + "`r" + 'B'); EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 'CR' ([string]$r.Json.detectedEol) 'c17b detectedEol CR'
    Assert-True ($r.Json.replacementEolMismatch -eq $false) 'c17b mismatch false (mesmo CR)'

    # ==== 18) dry-run paridade =================================================
    $script:cases++
    $fa = New-CaseFile -Name 'c18a' -Body $dupBody
    $fb = New-CaseFile -Name 'c18b' -Body $dupBody
    $rdr = Invoke-Surgical @{ InputPath = $fa; Anchor = $anchor; Replacement = 'Q'; EditMode = 'Replace'; ExpectedAnchorCount = 2; ApplyToAllOccurrences = $true; DryRun = $true }
    $rap = Invoke-Surgical @{ InputPath = $fb; Anchor = $anchor; Replacement = 'Q'; EditMode = 'Replace'; ExpectedAnchorCount = 2; ApplyToAllOccurrences = $true }
    Assert-Eq 0 $rdr.ExitCode 'c18 dry exit'
    Assert-Eq $rap.Json.replacementsApplied $rdr.Json.replacementsApplied 'c18 paridade applied'
    Assert-Eq $rap.Json.detectedEol $rdr.Json.detectedEol 'c18 paridade eol'

    # ==== 19) mutatedIntervals = delta real + total/truncated ==================
    $script:cases++
    $f = New-CaseFile -Name 'c19' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'LONGO'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c19 exit'
    $mi = $r.Json.mutatedIntervals.anchor[0]
    Assert-Eq 1 $r.Json.mutatedIntervals.total 'c19 total'
    Assert-True ($r.Json.mutatedIntervals.truncated -eq $false) 'c19 truncated false'
    Assert-Eq ('LONGO'.Length - $anchor.Length) ($mi.FinalLength - $mi.OriginalLength) 'c19 delta real'

    # ==== 20) baseline inexistente -> 16; dir -> 16; PreserveLastUpdate passa ==
    $script:cases++
    $f = New-CaseFile -Name 'c20' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; LastUpdateBaselinePath = (Join-Path $tempRoot 'nao_existe.xml') }
    Assert-Eq 16 $r.ExitCode 'c20 inexistente exit'
    Assert-Eq 'BASELINE_NOT_FOUND' ([string]$r.Json.code) 'c20 code'
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; LastUpdateBaselinePath = $tempRoot }
    Assert-Eq 16 $r.ExitCode 'c20 diretorio exit'
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; PreserveLastUpdate = $true; LastUpdateBaselinePath = (Join-Path $tempRoot 'nao_existe.xml') }
    Assert-Eq 0 $r.ExitCode 'c20 preserve passa'

    # ==== 21) OutputPath dir ausente -> 15; InputPath ausente -> 14 ============
    $script:cases++
    $f = New-CaseFile -Name 'c21' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = (Join-Path $tempRoot 'inexistente.xml'); Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace' }
    Assert-Eq 14 $r.ExitCode 'c21 input exit'
    Assert-Eq 'INPUT_NOT_FOUND' ([string]$r.Json.code) 'c21 input code'
    $r = Invoke-Surgical @{ InputPath = $f; OutputPath = (Join-Path $tempRoot 'sem_dir\out.xml'); Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace' }
    Assert-Eq 15 $r.ExitCode 'c21 output exit'
    Assert-Eq 'OUTPUT_DIR_MISSING' ([string]$r.Json.code) 'c21 output code'

    # ==== 22) limites offset 0 / ultimo ========================================
    $script:cases++
    $f = New-CaseFile -Name 'c22a' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = '<Object'; Replacement = '<Object data-b="1"'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c22a (offset 0) exit'
    $f = New-CaseFile -Name 'c22b' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = '</Rules>'; Replacement = ('</Rules>' + "`r`n" + '<!--x-->'); EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c22b (ultimo) exit'
    Assert-True ($r.Json.wellFormed -eq $true) 'c22b wellFormed'

    # ==== 23) replay a -> aa ===================================================
    $script:cases++
    $f = New-CaseFile -Name 'c23' -Body ('z' + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'z'; Replacement = 'zz'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c23 exit'
    Assert-Eq (New-Xml -Body ('zz' + "`r`n")) ([System.IO.File]::ReadAllText($f)) 'c23 replay'

    # ==== 24) ApplyToAll sem ExpectedAnchorCount 2 -> 11 =======================
    $script:cases++
    $f = New-CaseFile -Name 'c24' -Body $dupBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; ApplyToAllOccurrences = $true }
    Assert-Eq 11 $r.ExitCode 'c24 exit'
    Assert-Eq 'ANCHOR_FAIL' ([string]$r.Json.code) 'c24 code'

    # ==== 25) InsertAfter inserindo lastUpdate anterior -> 28 ==================
    $script:cases++
    $f = New-CaseFile -Name 'c25' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = '<Object '; Replacement = ('data-z="9"' + $lu + ' '); EditMode = 'InsertAfter' }
    Assert-Eq 28 $r.ExitCode 'c25 exit'
    Assert-Eq 'LASTUPDATE_TARGET_MOVED' ([string]$r.Json.code) 'c25 code'

    # ==== 26) metachars de regex / case / zero-width ===========================
    $script:cases++
    $meta = 'a.b(c)[d]$e^f*+?'
    $f = New-CaseFile -Name 'c26a' -Body ($meta + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $meta; Replacement = 'LITERAL'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c26a metachars exit'
    Assert-Eq 1 $r.Json.replacementsApplied 'c26a metachars applied'
    $f = New-CaseFile -Name 'c26b' -Body ('axb' + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'a.b'; Replacement = 'Z'; EditMode = 'Replace' }
    Assert-Eq 11 $r.ExitCode 'c26b regex-dot nao casa'
    $zw = 'Z' + [char]0x200B + 'Z'
    $f = New-CaseFile -Name 'c26c' -Body ($zw + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $zw; Replacement = 'W'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c26c zero-width exit'

    # ==== 27) BOM na entrada ===================================================
    $script:cases++
    $bomEnc = [System.Text.UTF8Encoding]::new($true)
    $f = New-CaseFile -Name 'c27' -Body $loneBody -Encoding $bomEnc
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c27 exit'
    Assert-Eq 1 $r.Json.replacementsApplied 'c27 applied'
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    Assert-True (-not $hasBom) 'c27 saida sem BOM'

    # ==== 28) mutatedIntervalsTruncated com N grande ===========================
    $script:cases++
    $many = 'X' * 150
    $f = New-CaseFile -Name 'c28' -Body ($many + "`r`n")
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'X'; Replacement = 'Y'; EditMode = 'Replace'; ExpectedAnchorCount = 150; ApplyToAllOccurrences = $true; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c28 exit'
    Assert-Eq 150 $r.Json.mutatedIntervals.total 'c28 total'
    Assert-True ($r.Json.mutatedIntervals.truncated -eq $true) 'c28 truncated true'
    Assert-Eq 100 $r.Json.mutatedIntervals.anchor.Count 'c28 mostrados'

    # ==== 29) ExpectedAnchorCount gigante -> 11 ================================
    $script:cases++
    $f = New-CaseFile -Name 'c29' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace'; ExpectedAnchorCount = 100001 }
    Assert-Eq 11 $r.ExitCode 'c29 exit'

    # ==== 30) esquema JSON =====================================================
    $script:cases++
    $f = New-CaseFile -Name 'c30' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'Z'; EditMode = 'Replace' }
    Assert-True ($null -ne $r.Json) 'c30 json presente'
    foreach ($key in @('status', 'code', 'replacementsApplied', 'postPatchAnchorCount', 'detectedEol', 'sourceEolMixed', 'replacementEolMismatch', 'mutatedIntervals')) {
        Assert-True ($null -ne $r.Json.PSObject.Properties[$key]) ("c30 chave ausente: " + $key)
    }
    foreach ($key in @('anchor', 'lastUpdate', 'total', 'truncated', 'limit')) {
        Assert-True ($null -ne $r.Json.mutatedIntervals.PSObject.Properties[$key]) ("c30 mutatedIntervals chave ausente: " + $key)
    }
    $f = New-CaseFile -Name 'c30err' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = 'NOPE'; Replacement = 'Z'; EditMode = 'Replace' }
    foreach ($key in @('status', 'code', 'message', 'exitCode', 'details')) {
        Assert-True ($null -ne $r.Json.PSObject.Properties[$key]) ("c30 erro chave ausente: " + $key)
    }

    # ==== 31) .bak apos erro 13 com details.bakPath ============================
    $script:cases++
    $f = New-CaseFile -Name 'c31' -Body $loneBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = ']]></Rules>'; Replacement = 'BROKEN'; EditMode = 'Replace' }
    Assert-Eq 13 $r.ExitCode 'c31 exit'
    Assert-True ($null -ne $r.Json.details) 'c31 details presente'
    Assert-Eq ($f + '.bak') ([string]$r.Json.details.bakPath) 'c31 bakPath'
    Assert-True (Test-Path -LiteralPath ($f + '.bak')) 'c31 .bak remanescente'

    # ==== 32) pos-condicao no arquivo lido de volta ============================
    $script:cases++
    $f = New-CaseFile -Name 'c32' -Body $dupBody
    $r = Invoke-Surgical @{ InputPath = $f; Anchor = $anchor; Replacement = 'XYZ'; EditMode = 'Replace'; ExpectedAnchorCount = 2; ApplyToAllOccurrences = $true; PreserveLastUpdate = $true }
    Assert-Eq 0 $r.ExitCode 'c32 exit'
    Assert-Eq (New-Xml -Body ('XYZ' + "`r`n" + 'XYZ' + "`r`n")) ([System.IO.File]::ReadAllText($f)) 'c32 pos-condicao no disco'

    # ==== 33) consumidores: contador compartilhado =============================
    $script:cases++
    $f = New-CaseFile -Name 'c33' -Body $dupBody
    $text = [System.IO.File]::ReadAllText($f)
    Assert-Eq 2 (Get-AnchorOccurrenceCount -Text $text -Anchor $anchor) 'c33 contador unicidade (Add-GeneXusButton)'
    Assert-Eq 2 ([int[]]@(Get-GeneXusXmlAnchorOccurrenceIndexes -Text $text -Anchor $anchor)).Count 'c33 enumerador'
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($script:failures -gt 0) {
    throw "EDIT_GENEXUS_XML_SURGICAL_CONTRACT_FAILED: $($script:failures) falha(s) em $($script:cases) caso(s)."
}

Write-Output ("Casos: {0}" -f $script:cases)
Write-Output 'EDIT_GENEXUS_XML_SURGICAL_CONTRACT_OK'
