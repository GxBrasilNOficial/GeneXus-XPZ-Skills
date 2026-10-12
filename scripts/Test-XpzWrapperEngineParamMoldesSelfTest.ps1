#requires -Version 7.4

<#
.SYNOPSIS
  Self-test de SEGURANCA: roda o check forwards_unknown_engine_param sobre TODOS os moldes
  xpz-kb-parallel-setup/examples/*.example.ps1 contra os motores REAIS do repo.

.DESCRIPTION
  Os moldes sao, por definicao, corretos: um sinal forwards_unknown_engine_param sobre eles
  e falso-positivo do extrator. Alem de "zero sinais", assevera COBERTURA EXATA (constante
  nomeada derivada do inventario de sites) para o "zero sinais" nao passar por vacuidade, e
  cobertura por molde (prova as formas reais: var intermediaria, Join-Path aninhado, splat com
  chaves condicionais, redirecionamento 2>&1, forma -Param:$v). Aplica tambem
  Get-XpzHelpSurfaceFinding sobre os moldes (recorrencia): ajuda visivel e 0 orfao no .EXAMPLE,
  com PISO de cobertura (medido: 20) contra vacuidade.
  Sentinela final: XPZ_WRAPPER_ENGINE_PARAM_MOLDES_OK.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'XpzWrapperEngineParamSupport.ps1')

$repoRoot = Split-Path -Parent $scriptDir
$examplesDir = Join-Path $repoRoot 'xpz-kb-parallel-setup\examples'
if (-not (Test-Path -LiteralPath $examplesDir -PathType Container)) {
    throw "ASSERT_FAILED: pasta de moldes nao encontrada: $examplesDir"
}

# Inventario canonico das 4 formas conhecidas (constante nomeada, derivada da tabela do
# desenho). Cada molde -> nº exato de sites de motor advanced auditados, provando cada forma.
# Outros moldes tambem delegam a motores compartilhados (cobertura agregada maior); aqui
# fixamos so as formas-prova e usamos um PISO derivado (soma destas) para anti-vacuidade,
# tolerante a novos moldes (evita numero magico fragil).
$ExpectedAuditedByMolde = [ordered]@{
    'Update-KbFromXpz.example.ps1'  = 3  # Sync (splat) + reminder (-AsJson) + inventory (-FailOnUnknownTypes 2>&1)
    'Test-KbIndexGate.example.ps1'  = 1  # Join-Path aninhado + splat por indice condicional
    'Test-KbSetupAudit.example.ps1' = 1  # explicitos com continuacao + -AsJson:$AsJson
    'Test-KbSourceSanity.example.ps1' = 1  # & $enginePath -InputPath $file
}
$MinExpectedAuditedSites = (@($ExpectedAuditedByMolde.Values) | Measure-Object -Sum).Sum  # = 6

$totalAudited = 0
$totalSignals = [System.Collections.Generic.List[string]]::new()
$perMolde = [ordered]@{}

foreach ($molde in (Get-ChildItem -LiteralPath $examplesDir -Filter '*.example.ps1' -File | Sort-Object Name)) {
    $finding = Get-XpzWrapperEngineParamFinding -WrapperPath $molde.FullName -EnginesRoot $scriptDir
    $totalAudited += [int]$finding.AuditedSiteCount
    $perMolde[$molde.Name] = [int]$finding.AuditedSiteCount
    foreach ($sig in $finding.Signals) {
        $totalSignals.Add(('{0}: {1}={2}' -f $molde.Name, $sig.Reason, $sig.Detail))
    }
}

# 1. Zero sinais sobre os moldes (corretos por definicao).
if ($totalSignals.Count -gt 0) {
    throw "ASSERT_FAILED: moldes nao podem gerar sinais; obtidos=$($totalSignals -join ' | ')"
}

# 2. Anti-vacuidade: cobertura agregada nunca abaixo do piso das formas-prova.
if ($totalAudited -lt $MinExpectedAuditedSites) {
    throw "ASSERT_FAILED: auditedSiteCount agregado=$totalAudited abaixo do piso $MinExpectedAuditedSites (cobertura parcial?) (perMolde=$(($perMolde.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '))"
}

# 3. Cobertura por molde (prova as formas reais).
foreach ($name in $ExpectedAuditedByMolde.Keys) {
    $got = if ($perMolde.Contains($name)) { [int]$perMolde[$name] } else { -1 }
    if ($got -ne [int]$ExpectedAuditedByMolde[$name]) {
        throw "ASSERT_FAILED: molde $name esperava $($ExpectedAuditedByMolde[$name]) site(s) auditado(s); obtido=$got"
    }
}

# 4. Comment-based help dos moldes (recorrencia): todo molde com invocacao do proprio nome no
# .EXAMPLE tem ajuda visivel e 0 achado (flag orfa, .PARAMETER orfao, ajuda invisivel). Anti-vacuidade
# por PISO de cobertura (medido: 20), tolerante a novos moldes.
$helpFindings = [System.Collections.Generic.List[string]]::new()
$moldesWithExampleSelf = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($molde in (Get-ChildItem -LiteralPath $examplesDir -Filter '*.example.ps1' -File | Sort-Object Name)) {
    $base = $molde.Name -replace '\.example\.ps1$', ''
    $r = Get-XpzHelpSurfaceFinding -WrapperPath $molde.FullName -AlternateSelfLeaf @("$base.ps1")
    foreach ($x in @(@($r.Blocking) + @($r.Advisory) + @($r.EngineDiagnostics))) {
        $helpFindings.Add(('{0}: {1}' -f $molde.Name, $x.Reason))
    }
    $body = Get-XpzHelpCommentBody -Text ([System.IO.File]::ReadAllText($molde.FullName))
    if ($null -ne $body) {
        foreach ($sec in (Get-XpzHelpSections -Body $body -Keyword 'EXAMPLE')) {
            $raw = Get-XpzHelpSectionRaw -Section $sec
            if (($raw -match [regex]::Escape($molde.Name)) -or ($raw -match [regex]::Escape("$base.ps1"))) {
                [void]$moldesWithExampleSelf.Add($molde.Name)
            }
        }
    }
}
if ($helpFindings.Count -gt 0) {
    throw "ASSERT_FAILED: moldes nao podem ter achados de comment-based help; obtidos=$($helpFindings -join ' | ')"
}
if ($moldesWithExampleSelf.Count -lt 20) {
    throw "ASSERT_FAILED: cobertura de .EXAMPLE com invocacao do proprio nome=$($moldesWithExampleSelf.Count) abaixo do piso 20 (recorrencia de help seria vacua)"
}

Write-Output 'XPZ_WRAPPER_ENGINE_PARAM_MOLDES_OK'
