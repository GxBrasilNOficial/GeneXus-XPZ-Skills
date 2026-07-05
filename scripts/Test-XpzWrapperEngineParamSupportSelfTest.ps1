#requires -Version 7.4
<#
.SYNOPSIS
  Self-test do helper XpzWrapperEngineParamSupport.ps1 (check forwards_unknown_engine_param).

.DESCRIPTION
  Cria wrappers de fixture (apenas PARSEADOS, nunca executados) e os confronta com:
    - motores REAIS do repo (Sync-GeneXusXpzToXml.ps1) via EnginesRoot = scripts/ do auditor;
    - motores SINTETICOS (simple/advanced/parse-broken/adversarial) numa pasta temp.
  Sentinela final: XPZ_WRAPPER_ENGINE_PARAM_SELFTEST_OK.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'XpzWrapperEngineParamSupport.ps1')
# Fonte unica de encoding UTF-8 sem BOM (norma de reuso; ver 09-inventario, Utf8NoBomEncodingSupport.ps1).
. (Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1')

$utf8 = Get-Utf8NoBomEncoding
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-engineparam-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$wrapDir = Join-Path $tempRoot 'wrappers'
$synthEngines = Join-Path $tempRoot 'synthscripts'
[void](New-Item -ItemType Directory -Path $wrapDir -Force)
[void](New-Item -ItemType Directory -Path $synthEngines -Force)

function New-Fixture {
    param([string]$Dir, [string]$Name, [string]$Content)
    $p = Join-Path $Dir $Name
    [System.IO.File]::WriteAllText($p, $Content, $utf8)
    return $p
}

function Assert-Signal {
    param([object]$Finding, [string]$Reason, [string]$DetailLike, [string]$Message)
    $hit = @($Finding.Signals | Where-Object { $_.Reason -eq $Reason -and $_.Detail -like $DetailLike })
    if ($hit.Count -eq 0) {
        throw "ASSERT_FAILED: $Message | esperado sinal $Reason '$DetailLike'; obtido=$(($Finding.Signals | ForEach-Object { $_.Reason + ':' + $_.Detail }) -join ', ')"
    }
}

function Assert-NoSignalReason {
    param([object]$Finding, [string]$Reason, [string]$Message)
    $hit = @($Finding.Signals | Where-Object { $_.Reason -eq $Reason })
    if ($hit.Count -gt 0) {
        throw "ASSERT_FAILED: $Message | nao esperava $Reason; obtido=$(($hit | ForEach-Object { $_.Reason + ':' + $_.Detail }) -join ', ')"
    }
}

function Assert-Eq {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ([string]$Actual -ne [string]$Expected) { throw "ASSERT_FAILED: $Message | esperado=$Expected obtido=$Actual" }
}

try {
    # EnginesRoot real = scripts/ do auditor (onde vivem Sync-GeneXusXpzToXml.ps1 etc.)
    $realEngines = $scriptDir

    # 1. FALHA: repassa parametro inexistente a motor advanced real (Sync).
    $f = New-Fixture $wrapDir 'fail-unknown.ps1' @'
param([string]$InputPath)
$e = Join-Path $SharedSkillsRoot 'scripts\Sync-GeneXusXpzToXml.ps1'
& $e -InputPath $InputPath -BogusParam $x
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-Signal $r 'forwards_unknown_engine_param' '*-BogusParam -> Sync-GeneXusXpzToXml.ps1*' 'parametro inexistente em motor advanced deve sinalizar'
    Assert-Eq $r.AuditedSiteCount 1 'site advanced auditado deve contar 1'

    # 2. PASSA: so parametros declarados.
    $f = New-Fixture $wrapDir 'pass-valid.ps1' @'
param([string]$InputPath)
$e = Join-Path $SharedSkillsRoot 'scripts\Sync-GeneXusXpzToXml.ps1'
& $e -InputPath $InputPath -DestinationRoot $d
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-NoSignalReason $r 'forwards_unknown_engine_param' 'so parametros validos nao pode sinalizar'
    Assert-Eq $r.AuditedSiteCount 1 'site valido ainda conta como auditado'

    # 3. Join-Path aninhado.
    $f = New-Fixture $wrapDir 'nested.ps1' @'
$e = Join-Path $S (Join-Path 'scripts' 'Sync-GeneXusXpzToXml.ps1')
& $e -BogusNested $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-Signal $r 'forwards_unknown_engine_param' '*-BogusNested -> Sync-GeneXusXpzToXml.ps1*' 'forma aninhada deve resolver e sinalizar'

    # 4. Irmao local (sem segmento 'scripts') -> fora de escopo.
    $f = New-Fixture $wrapDir 'local-sibling.ps1' @'
$e = Join-Path $PSScriptRoot 'Rebuild-KbIntelligenceIndex.ps1'
& $e -Anything $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-NoSignalReason $r 'forwards_unknown_engine_param' 'irmao local nao pode sinalizar'
    Assert-Eq $r.AuditedSiteCount 0 'irmao local nao e auditado'

    # 5. Raiz renomeada ($MyBase) com leaf valido -> auditado normalmente (GAP-2 fix).
    $f = New-Fixture $wrapDir 'renamed-root.ps1' @'
$MyBase = 'C:\qualquer\GeneXus-XPZ-Skills'
$e = Join-Path $MyBase 'scripts\Sync-GeneXusXpzToXml.ps1'
& $e -BogusRenamed $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-Signal $r 'forwards_unknown_engine_param' '*-BogusRenamed -> Sync-GeneXusXpzToXml.ps1*' 'raiz renomeada com leaf valido deve ser auditada'

    # 6. shared_engine_unresolved: leaf inexistente sob expressao com 'scripts'.
    $f = New-Fixture $wrapDir 'unresolved.ps1' @'
$e = Join-Path $S 'scripts\NonExistentEngine-xyz.ps1'
& $e -Foo $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-Signal $r 'shared_engine_unresolved' 'NonExistentEngine-xyz.ps1' 'leaf inexistente deve virar shared_engine_unresolved'

    # 7. Splat com chave inexistente.
    $f = New-Fixture $wrapDir 'splat-bad.ps1' @'
$e = Join-Path $S 'scripts\Sync-GeneXusXpzToXml.ps1'
$p = @{ InputPath = $x; BogusKey = $z }
& $e @p
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-Signal $r 'forwards_unknown_engine_param' '*-BogusKey -> Sync-GeneXusXpzToXml.ps1*' 'chave de splat inexistente deve sinalizar'

    # 8. Splat com .Remove -> site pulado (mutacao nao-rastreavel).
    $f = New-Fixture $wrapDir 'splat-remove.ps1' @'
$e = Join-Path $S 'scripts\Sync-GeneXusXpzToXml.ps1'
$p = @{ InputPath = $x; BogusKey = $z }
$p.Remove('BogusKey')
& $e @p
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-NoSignalReason $r 'forwards_unknown_engine_param' 'splat com .Remove deve pular o site'
    Assert-Eq $r.AuditedSiteCount 0 'site com splat mutado nao e auditado'

    # 9. Forma com dois-pontos -Param:$v (nome extraido).
    $f = New-Fixture $wrapDir 'colon.ps1' @'
param([switch]$AsJson)
$e = Join-Path $S 'scripts\Sync-GeneXusXpzToXml.ps1'
& $e -InputPath $x -BogusColon:$AsJson
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $realEngines
    Assert-Signal $r 'forwards_unknown_engine_param' '*-BogusColon -> Sync-GeneXusXpzToXml.ps1*' 'forma -Param:$v deve extrair o nome'

    # --- Motores SINTETICOS (EnginesRoot temp) ---

    [void](New-Fixture $synthEngines 'SimpleEngine.ps1' "param([string]`$X)`n`"ok`"")
    [void](New-Fixture $synthEngines 'AdvancedEngine.ps1' "[CmdletBinding()]`nparam([string]`$X)`n`"ok`"")
    [void](New-Fixture $synthEngines 'AdversarialSimpleEngine.ps1' "param([switch]`$Verbose,[switch]`$Debug,[switch]`$ErrorAction,[switch]`$WarningAction,[switch]`$OutBuffer,[string]`$X)`n`"ok`"")
    [void](New-Fixture $synthEngines 'BrokenEngine.ps1' "[CmdletBinding()]`nparam([string]`$X`n`"oops")

    # 10. Motor SIMPLE -> pulado mesmo repassando -Foo.
    $f = New-Fixture $wrapDir 'use-simple.ps1' @'
$e = Join-Path $S 'scripts\SimpleEngine.ps1'
& $e -Foo $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $synthEngines
    Assert-NoSignalReason $r 'forwards_unknown_engine_param' 'motor SIMPLE e permissivo: nao auditar'
    Assert-Eq $r.AuditedSiteCount 0 'motor SIMPLE nao conta como auditado'

    # 11. Motor SIMPLE adversarial (declara Verbose/Debug/... literais) -> ainda pulado.
    $f = New-Fixture $wrapDir 'use-adversarial.ps1' @'
$e = Join-Path $S 'scripts\AdversarialSimpleEngine.ps1'
& $e -Foo $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $synthEngines
    Assert-NoSignalReason $r 'forwards_unknown_engine_param' 'SIMPLE com nomes CommonParameter literais ainda e SIMPLE'
    Assert-Eq $r.AuditedSiteCount 0 'adversarial SIMPLE nao e auditado'

    # 12. Motor ADVANCED sintetico -> sinaliza -Foo.
    $f = New-Fixture $wrapDir 'use-advanced.ps1' @'
$e = Join-Path $S 'scripts\AdvancedEngine.ps1'
& $e -Foo $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $synthEngines
    Assert-Signal $r 'forwards_unknown_engine_param' '*-Foo -> AdvancedEngine.ps1*' 'motor advanced com -Foo inexistente deve sinalizar'

    # 13. Motor parse-broken -> engine_unresolved_or_unparseable (diagnostico), nao crash.
    $f = New-Fixture $wrapDir 'use-broken.ps1' @'
$e = Join-Path $S 'scripts\BrokenEngine.ps1'
& $e -Foo $y
'@
    $r = Get-XpzWrapperEngineParamFinding -WrapperPath $f -EnginesRoot $synthEngines
    $diag = @($r.EngineDiagnostics | Where-Object { $_.Reason -eq 'engine_unresolved_or_unparseable' -and $_.Detail -eq 'BrokenEngine.ps1' })
    if ($diag.Count -eq 0) { throw "ASSERT_FAILED: motor parse-broken deve gerar engine_unresolved_or_unparseable" }
    Assert-NoSignalReason $r 'forwards_unknown_engine_param' 'motor quebrado nao pode gerar sinal de parametro'

    Write-Output 'XPZ_WRAPPER_ENGINE_PARAM_SELFTEST_OK'
} finally {
    if ($tempRoot.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
