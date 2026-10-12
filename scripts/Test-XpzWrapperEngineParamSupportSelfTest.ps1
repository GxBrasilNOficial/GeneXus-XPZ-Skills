#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do helper XpzWrapperEngineParamSupport.ps1 — check forwards_unknown_engine_param +
  comment-based help (Get-XpzHelpSurfaceFinding). (O check de diff de superficie wrapper->molde
  `surface_mismatch`/`INVENTORY_SURFACE_ADVISORY` e coberto por Test-XpzWrapperInventorySelfTest.ps1.)

.DESCRIPTION
  Cria wrappers de fixture (apenas PARSEADOS, nunca executados) e os confronta com:
    - motores REAIS do repo (Sync-GeneXusXpzToXml.ps1) via EnginesRoot = scripts/ do auditor;
    - motores SINTETICOS (simple/advanced/parse-broken/adversarial) numa pasta temp.
  Inclui casos de UNIDADE do comment-based help (H1..H15): flag orfa em advanced, alias, prefixo
  ambiguo/nao-ambiguo, CommonParameters, outro script, simple, sem param()/dynamicparam, formas de
  parse, Join-Path, .PARAMETER orfao, ajuda invisivel, -AlternateSelfLeaf e paridade de molde.
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

    # --- Comment-based help (Get-XpzHelpSurfaceFinding) ---
    function Get-HelpReasons { param($Items) return ((@($Items | ForEach-Object { [string]$_.Reason }) -join ',')) }
    function Assert-HelpFinding {
        param([object]$Finding, [string]$Block, [string]$Adv, [string]$Message)
        $b = Get-HelpReasons $Finding.Blocking
        $a = Get-HelpReasons $Finding.Advisory
        if ($b -ne $Block) { throw "ASSERT_FAILED: $Message | blocking esperado=[$Block] obtido=[$b]" }
        if ($a -ne $Adv) { throw "ASSERT_FAILED: $Message | advisory esperado=[$Adv] obtido=[$a]" }
    }

    # H1 flag orfa em script advanced -> bloqueio
    $f = New-Fixture $wrapDir 'h1.ps1' @'
#requires -Version 7.4

<#
.SYNOPSIS
H1 unica.
.EXAMPLE
.\h1.ps1 -AsJson
#>
[CmdletBinding()]
param([string]$InputPath)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) 'help_example_undeclared_param:-AsJson' '' 'H1 flag orfa advanced'

    # H2 [Alias] usado no .EXAMPLE -> nao acusa
    $f = New-Fixture $wrapDir 'h2.ps1' @'
<#
.SYNOPSIS
H2 unica.
.EXAMPLE
.\h2.ps1 -Foo value
#>
[CmdletBinding()]
param([Alias('Foo')][string]$Bar)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' '' 'H2 alias aceito'

    # H3 prefixo nao-ambiguo aceito; prefixo ambiguo acusa
    $f = New-Fixture $wrapDir 'h3.ps1' @'
<#
.SYNOPSIS
H3 unica.
.EXAMPLE
.\h3.ps1 -Alf x
.\h3.ps1 -Al x
#>
[CmdletBinding()]
param([string]$Alfa, [string]$Alto)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) 'help_example_undeclared_param:-Al' '' 'H3 prefixo ambiguo acusa, nao-ambiguo nao'

    # H4 CommonParameters aceitos
    $f = New-Fixture $wrapDir 'h4.ps1' @'
<#
.SYNOPSIS
H4 unica.
.EXAMPLE
.\h4.ps1 -Verbose -ErrorVariable ev
#>
[CmdletBinding()]
param([string]$X)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' '' 'H4 common params aceitos'

    # H5 invocacao de OUTRO script nao acusa
    $f = New-Fixture $wrapDir 'h5.ps1' @'
<#
.SYNOPSIS
H5 unica.
.EXAMPLE
.\Other-Script.ps1 -AsJson
#>
[CmdletBinding()]
param([string]$X)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' '' 'H5 outro script ignorado'

    # H6 script simple com flag desconhecida -> advisory, nao bloqueio
    $f = New-Fixture $wrapDir 'h6.ps1' @'
<#
.SYNOPSIS
H6 unica.
.EXAMPLE
.\h6.ps1 -Whatever
#>
param([string]$InputPath)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' 'help_example_unknown_flag_simple_script:-Whatever' 'H6 simple -> advisory'

    # H7 sem param() de topo -> exemplo pulado
    $f = New-Fixture $wrapDir 'h7.ps1' @'
<#
.SYNOPSIS
H7 unica.
.EXAMPLE
.\h7.ps1 -X
#>
Write-Output 'x'
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' '' 'H7 sem param() de topo pulado'

    # H8 dynamicparam -> exemplo pulado
    $f = New-Fixture $wrapDir 'h8.ps1' @'
<#
.SYNOPSIS
H8 unica.
.EXAMPLE
.\h8.ps1 -X
#>
[CmdletBinding()]
param([string]$Y)
dynamicparam { }
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' '' 'H8 dynamicparam pulado'

    # H9 formas de parse: ; crase -Param:$v comentario # Tipo:Nome
    $f = New-Fixture $wrapDir 'h9.ps1' @'
<#
.SYNOPSIS
H9 unica.
.EXAMPLE
.\h9.ps1 -Good1:$v
.\h9.ps1 -Good2 a -Good3 b; .\h9.ps1 -Bad1
# comentario aqui
.\h9.ps1 -Good4 'Proc:X'
.\h9.ps1 `
    -Good5 x
.\h9.ps1 -Bad2
#>
[CmdletBinding()]
param([string]$Good1,[string]$Good2,[string]$Good3,[string]$Good4,[string]$Good5)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) 'help_example_undeclared_param:-Bad1,help_example_undeclared_param:-Bad2' '' 'H9 parse de .EXAMPLE'

    # H10 invocacao via & (Join-Path ... '<leaf>.ps1')
    $f = New-Fixture $wrapDir 'h10.ps1' @'
<#
.SYNOPSIS
H10 unica.
.EXAMPLE
& (Join-Path $PSScriptRoot 'h10.ps1') -BogusJoin
#>
[CmdletBinding()]
param([string]$X)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) 'help_example_undeclared_param:-BogusJoin' '' 'H10 Join-Path self'

    # H11 .PARAMETER sem $x -> help_parameter_orphan
    $f = New-Fixture $wrapDir 'h11.ps1' @'
<#
.SYNOPSIS
H11 unica.
.PARAMETER Ghost
Descreve ghost.
.EXAMPLE
.\h11.ps1 -Ok x
#>
[CmdletBinding()]
param([string]$Ok)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' 'help_parameter_orphan:-Ghost' 'H11 param orphan'

    # H12 ajuda invisivel (#requires colado) -> help_invisible
    $f = New-Fixture $wrapDir 'h12.ps1' @'
#requires -Version 7.4
<#
.SYNOPSIS
H12 invisivel unica.
#>
[CmdletBinding()]
param([string]$Ok)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' 'help_invisible' 'H12 ajuda invisivel'

    # H13 -AlternateSelfLeaf reconhece o nome generico do molde; terceiro script continua fora
    $f = New-Fixture $wrapDir 'h13.ps1' @'
<#
.SYNOPSIS
H13 unica.
.EXAMPLE
.\Generic-Molde.ps1 -BogusAlt
.\Third-Party.ps1 -AlsoBogus
#>
[CmdletBinding()]
param([string]$Ok)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f -AlternateSelfLeaf @('Generic-Molde.ps1')) 'help_example_undeclared_param:-BogusAlt' '' 'H13 alternate self leaf'

    # H14 sinopse com crase -> nao falsear invisibilidade (guarda IndexOf vs -like)
    $f = New-Fixture $wrapDir 'h14.ps1' @'
<#
.SYNOPSIS
H14 sinopse com `crase` unica.
.EXAMPLE
.\h14.ps1 -Ok x
#>
[CmdletBinding()]
param([string]$Ok)
'@
    Assert-HelpFinding (Get-XpzHelpSurfaceFinding -WrapperPath $f) '' '' 'H14 crase na sinopse'

    # H15 paridade de molde: suprime bloqueio identico e reporta o defeito do molde como diagnostico
    $molde = New-Fixture $wrapDir 'h15.example.ps1' @'
<#
.SYNOPSIS
H15 molde unica.
.EXAMPLE
.\h15.ps1 -AsJson
#>
[CmdletBinding()]
param([string]$Ok)
'@
    $local = New-Fixture $wrapDir 'h15.ps1' @'
<#
.SYNOPSIS
H15 unica.
.EXAMPLE
.\h15.ps1 -AsJson
#>
[CmdletBinding()]
param([string]$Ok)
'@
    $r = Get-XpzHelpSurfaceFinding -WrapperPath $local -MoldePath $molde -AlternateSelfLeaf @('h15.ps1')
    Assert-HelpFinding $r '' '' 'H15 paridade suprime bloqueio identico'
    $diag = @($r.EngineDiagnostics | Where-Object { $_.Reason -eq 'help_molde_help_example_undeclared_param:-AsJson' })
    if ($diag.Count -eq 0) { throw 'ASSERT_FAILED: H15 defeito do molde deve virar INVENTORY_ENGINE_DIAGNOSTIC help_molde_...' }

    Write-Output 'XPZ_WRAPPER_ENGINE_PARAM_SELFTEST_OK'
} finally {
    if ($tempRoot.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
