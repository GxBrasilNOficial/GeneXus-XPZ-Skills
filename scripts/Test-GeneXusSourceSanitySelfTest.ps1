#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do gate Test-GeneXusSourceSanity.ps1: regra type-aware
    procedural-in-conditions (Procedure + parte Conditions nao-vazia) e modo
    declarativo da parte Rules de Transaction.

.DESCRIPTION
    Cobre:
    (1) positivo  — Procedure (84a12160) com parte Conditions (763f0d8b) nao-vazia -> fail;
    (2) negativo  — Procedure com Conditions vazia (CDATA vazio) -> nao dispara;
    (3) negativo  — Procedure com Conditions whitespace-only -> nao dispara (skip antes da regra);
    (4) negativo  — Procedure SEM a parte Conditions -> nao dispara;
    (5) negativo  — WebPanel (c9584656) com Conditions nao-vazia (filtro legitimo) -> nao dispara;
    (6) ExportFile com 2 objetos (Procedure sujo + WebPanel limpo) -> fail so para o Procedure;
    (7) declarativo — Transaction (1db606f2) + Rules (9b0a32a3) com bloco procedural
        desbalanceado: suprime unexpected-close/mismatched-close/unclosed-block,
        preserva o aviso (iif) -> sourceSanityStatus 'warn', probablyImportable true;
    (8) Conditions multiline — WebPanel com Conditions usando `when` multiline -> pass;
    (9) procedural — Procedure com bloco If sem fechamento na parte principal (528d1c06)
        ainda falha por unclosed-block (o modo declarativo nao vaza para outros pares).

    O gate emite JSON SEMPRE (sem -AsJson); o self-test invoca sem essa flag.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8SupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8SupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8SupportPath"
}
. $utf8SupportPath

$scriptPath  = Join-Path $PSScriptRoot 'Test-GeneXusSourceSanity.ps1'
$utf8        = Get-Utf8NoBomEncoding
$tempRoot    = Join-Path ([System.IO.Path]::GetTempPath()) ('sourcesanity-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$procType    = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webType     = 'c9584656-94b6-4ccd-890f-332d11fc2c25'
$trnType     = '1db606f2-af09-4cf9-a3b5-b481519d28f6'
$rulesPart   = '9b0a32a3-de6d-4be1-a4dd-1b85d3741534'
$mainPart    = '528d1c06-a9c2-420d-bd35-21dca83f12ff'
$condPartId  = '763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9'
$findingCode = 'procedural-in-conditions'
$balanceCodes = @('unexpected-close', 'mismatched-close', 'unclosed-block')

function New-ObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$ObjectType,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$MainSource = "msg('ok')",
        [ValidateSet('none', 'empty', 'whitespace', 'content')][string]$Conditions = 'none',
        [string]$ConditionsSource = ''
    )
    $condPart = ''
    if ($Conditions -ne 'none') {
        if ($Conditions -eq 'content') {
            $inner = $ConditionsSource
        } elseif ($Conditions -eq 'whitespace') {
            $inner = "`r`n   `r`n"
        } else {
            $inner = ''
        }
        $condPart = @"
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Source><![CDATA[$inner]]></Source>
  </Part>
"@
    }
    return @"
<Object type="$ObjectType" name="$Name" guid="11111111-1111-1111-1111-111111111111">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[$MainSource]]></Source>
  </Part>
$condPart</Object>
"@
}

function New-SinglePartObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$ObjectType,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$PartType,
        [Parameter(Mandatory = $true)][string]$Source
    )
    return @"
<Object type="$ObjectType" name="$Name" guid="44444444-4444-4444-4444-444444444444">
  <Part type="$PartType">
    <Source><![CDATA[$Source]]></Source>
  </Part>
</Object>
"@
}

function Test-HasBalanceFinding {
    param($Result)
    return @($Result.findings | Where-Object { $balanceCodes -contains $_.code }).Count -gt 0
}

function Test-HasCode {
    param($Result, [string]$Code)
    return @($Result.findings | Where-Object { $_.code -eq $Code }).Count -gt 0
}

function Invoke-Gate {
    param([string]$Xml)
    $f = Join-Path $tempRoot ('o-{0}.xml' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($f, $Xml, $utf8)
    return (& $scriptPath -InputPath $f | ConvertFrom-Json)
}

function Test-HasCondFinding {
    param($Result)
    return @($Result.findings | Where-Object { $_.code -eq $findingCode }).Count -gt 0
}

$dirtyConditions = @'
// Comentario indevido
&varMsg = ''
If &foundA
Return
Endif
'@

# Caso 1: Procedure + Conditions nao-vazia -> fail
$r1 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procDirty' -Conditions 'content' -ConditionsSource $dirtyConditions)
if (-not (Test-HasCondFinding $r1)) { throw "Caso 1: deveria disparar '$findingCode'." }
if ($r1.sourceSanityStatus -ne 'fail') { throw "Caso 1: sourceSanityStatus deveria ser 'fail'; obtido '$($r1.sourceSanityStatus)'." }
if ($r1.probablyImportable) { throw 'Caso 1: probablyImportable deveria ser false.' }

# Caso 2: Procedure + Conditions vazia -> nao dispara
$r2 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procEmpty' -Conditions 'empty')
if (Test-HasCondFinding $r2) { throw 'Caso 2: Conditions vazia nao deveria disparar.' }

# Caso 3: Procedure + Conditions whitespace-only -> nao dispara (skip antes da regra)
$r3 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procWs' -Conditions 'whitespace')
if (Test-HasCondFinding $r3) { throw 'Caso 3: Conditions whitespace-only nao deveria disparar.' }

# Caso 4: Procedure SEM a parte Conditions -> nao dispara
$r4 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procNoCond' -Conditions 'none')
if (Test-HasCondFinding $r4) { throw 'Caso 4: Procedure sem parte Conditions nao deveria disparar.' }

# Caso 5: WebPanel + Conditions nao-vazia (filtro legitimo) -> nao dispara
$r5 = Invoke-Gate (New-ObjectXml -ObjectType $webType -Name 'wpClean' -Conditions 'content' -ConditionsSource 'AttrA = &x;')
if (Test-HasCondFinding $r5) { throw 'Caso 5: WebPanel com Conditions legitima nao deveria disparar.' }

# Caso 6: ExportFile com 2 objetos -> fail so para o Procedure
$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$procType" name="procDirty2" guid="22222222-2222-2222-2222-222222222222">
      <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
        <Source><![CDATA[msg('ok')]]></Source>
      </Part>
      <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
        <Source><![CDATA[$dirtyConditions]]></Source>
      </Part>
    </Object>
    <Object type="$webType" name="wpClean2" guid="33333333-3333-3333-3333-333333333333">
      <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
        <Source><![CDATA[AttrA = &x;]]></Source>
      </Part>
    </Object>
  </Objects>
</ExportFile>
"@
$r6 = Invoke-Gate $exportXml
$condFindings = @($r6.findings | Where-Object { $_.code -eq $findingCode })
if ($condFindings.Count -ne 1) { throw "Caso 6: deveria haver exatamente 1 finding '$findingCode'; obtido $($condFindings.Count)." }
if ($condFindings[0].message -notmatch 'procDirty2') { throw 'Caso 6: o finding deveria referenciar o Procedure procDirty2.' }
if ($r6.sourceSanityStatus -ne 'fail') { throw "Caso 6: sourceSanityStatus deveria ser 'fail'." }

# Caso 7: Transaction + Rules com bloco procedural desbalanceado -> declarativo suprime
#         balanceamento (unclosed-block do 'If') mas preserva o aviso (iif).
$trnRules = @'
[web]
{
DocumentoFiscalId = &Id if not &Id.IsEmpty();
If &Mode = TrnMode.Insert
&x = iif(&a, 1, 2)
}
'@
$r7 = Invoke-Gate (New-SinglePartObjectXml -ObjectType $trnType -Name 'trnDecl' -PartType $rulesPart -Source $trnRules)
if (Test-HasBalanceFinding $r7) { throw 'Caso 7: Transaction Rules declarativa nao deveria emitir finding de balanceamento.' }
if (-not (Test-HasCode $r7 'iif')) { throw "Caso 7: o aviso 'iif' deveria ser preservado no modo declarativo." }
if ($r7.sourceSanityStatus -ne 'warn') { throw "Caso 7: sourceSanityStatus deveria ser 'warn'; obtido '$($r7.sourceSanityStatus)'." }
if (-not $r7.probablyImportable) { throw 'Caso 7: probablyImportable deveria ser true (so avisos).' }

# Caso 8: WebPanel + Conditions com `when` multiline -> passa (nao casa If/For/Do/Sub).
$wpConditions = @'
DocumentoFiscalEmitenteId = &x
   when &Mode = TrnMode.Insert;
DocumentoFiscalDestinatarioId = &y
   when not &y.IsEmpty()
   and &z;
'@
$r8 = Invoke-Gate (New-SinglePartObjectXml -ObjectType $webType -Name 'wpWhen' -PartType $condPartId -Source $wpConditions)
if (Test-HasBalanceFinding $r8) { throw 'Caso 8: Conditions multiline (when) nao deveria emitir finding de balanceamento.' }
if ($r8.sourceSanityStatus -ne 'pass') { throw "Caso 8: sourceSanityStatus deveria ser 'pass'; obtido '$($r8.sourceSanityStatus)'." }

# Caso 9: Procedure com bloco If sem fechamento na parte principal (528d1c06) -> ainda
#         falha por unclosed-block; o modo declarativo NAO vaza para outros pares.
$procUnclosed = @'
&total = 0
If &Mode = TrnMode.Insert
&total = &total + 1
'@
$r9 = Invoke-Gate (New-SinglePartObjectXml -ObjectType $procType -Name 'procUnclosed' -PartType $mainPart -Source $procUnclosed)
if (-not (Test-HasCode $r9 'unclosed-block')) { throw "Caso 9: Procedure com If sem fechamento deveria emitir 'unclosed-block'." }
if ($r9.sourceSanityStatus -ne 'fail') { throw "Caso 9: sourceSanityStatus deveria ser 'fail'; obtido '$($r9.sourceSanityStatus)'." }
if ($r9.probablyImportable) { throw 'Caso 9: probablyImportable deveria ser false.' }

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-GeneXusSourceSanitySelfTest.ps1'
exit 0
