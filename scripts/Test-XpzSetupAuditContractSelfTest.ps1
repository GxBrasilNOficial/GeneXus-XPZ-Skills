#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do CONTRATO -AsJson do motor Test-XpzSetupAudit.ps1 (gate K8 da rotina
  pre-push de pasta paralela de KB). Sentinela:
  XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK.

.DESCRIPTION
  Foca o contrato consumido pelo orquestrador K8 (estado_operacional_sugerido em
  JSON, -AsJson nunca lanca), nao o caminho verde (que exige pasta paralela real).
    A. Sem wrapper de runtime PowerShell -> estado runtime_powershell_bloqueado em
       JSON, exit 1, sem throw.
    B. Runtime OK (stub) mas kb-source-metadata.md ausente -> safety-net: estado
       auditoria_incompleta em JSON, sem throw.
    C. Gate com writability_coverage: partial e GATE_OK -> cobertura preservada e
       indice/gate OK.
    D. Gate com GATE_OK sem writability_coverage -> indice/gate PENDENTE e
       cobertura unknown; GATE_OK sozinho nao e aceito.
    E. Gate com source_mask_degraded=true -> indice/mascara true e aviso
       preservado, sem alterar o estado do gate.
    F. GATE_OK sem source_mask_degraded -> indice/gate PENDENTE e estado nao limpo.
    G. source_mask_degraded com sufixo invalido -> unknown e PENDENTE.
    H. source_mask_degraded=true sem aviso -> contrato incompleto.
    I. source_mask_degraded=false com aviso -> estado inconsistente.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Test-XpzSetupAudit.ps1'
$roots = [System.Collections.Generic.List[string]]::new()
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

function New-SetupAuditFixture {
  param([string]$GateText)

  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-setupaudit-c-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $root -Force)
  $roots.Add($root)

  $runtime = Join-Path $root 'runtime-ok.ps1'
  [System.IO.File]::WriteAllText($runtime, "'POWERSHELL_RUNTIME_OK'`n", $utf8NoBom)
  $metadata = Join-Path $root 'metadata-ok.ps1'
  [System.IO.File]::WriteAllText($metadata, "'METADATA_WRAPPER_OK'`n", $utf8NoBom)
  $naming = Join-Path $root 'naming-ok.ps1'
  [System.IO.File]::WriteAllText($naming, '{"status":"NAMING_OK","all":[],"divergent":[]}' + "`n", $utf8NoBom)
  $gate = Join-Path $root 'gate.ps1'
  [System.IO.File]::WriteAllText($gate, $GateText, $utf8NoBom)
  [System.IO.File]::WriteAllText(
    (Join-Path $root 'kb-source-metadata.md'),
    "last_xpz_materialization_run_at: 2026-01-01T00:00:00Z`n",
    $utf8NoBom)

  return [pscustomobject]@{
    Root = $root
    Gate = $gate
    Metadata = $metadata
    Runtime = $runtime
    Naming = $naming
  }
}

try {
  # --- A: runtime ausente -> runtime_powershell_bloqueado ---
  $a = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-setupaudit-a-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $a -Force); $roots.Add($a)
  $ra = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $a, '-GateWrapperPath', 'dummy', '-MetadataWrapperTestPath', 'dummy', '-AsJson')
  Assert-True ($ra.exit -eq 1) "A: exit 1 esperado; obtido $($ra.exit)"
  Assert-True ($null -ne $ra.json) "A: stdout deveria ser JSON parseavel (-AsJson nunca lanca)"
  Assert-True ($ra.json.estado_operacional_sugerido -eq 'runtime_powershell_bloqueado') "A: estado runtime_powershell_bloqueado esperado; obtido $($ra.json.estado_operacional_sugerido)"

  # --- B: runtime OK (stub) mas metadata ausente -> auditoria_incompleta ---
  $b = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-setupaudit-b-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $b -Force); $roots.Add($b)
  $runtimeStub = Join-Path $b 'runtime-ok.ps1'
  [System.IO.File]::WriteAllText($runtimeStub, "'POWERSHELL_RUNTIME_OK'`n", $utf8NoBom)
  $rb = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $b, '-GateWrapperPath', 'dummy', '-MetadataWrapperTestPath', 'dummy',
    '-PowerShellRuntimeTestPath', $runtimeStub, '-AsJson')
  Assert-True ($null -ne $rb.json) "B: stdout deveria ser JSON parseavel (safety-net -AsJson nunca lanca)"
  Assert-True ($rb.json.estado_operacional_sugerido -eq 'auditoria_incompleta') "B: estado auditoria_incompleta esperado; obtido $($rb.json.estado_operacional_sugerido)"

  # --- C: gate com cobertura partial -> GATE_OK aceito e cobertura preservada ---
  $c = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: partial'
Write-Output 'source_mask_degraded: false'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $rc = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $c.Root, '-GateWrapperPath', $c.Gate, '-MetadataWrapperTestPath', $c.Metadata,
    '-PowerShellRuntimeTestPath', $c.Runtime, '-NamingWrapperPath', $c.Naming, '-AsJson')
  Assert-True ($null -ne $rc.json) "C: stdout deveria ser JSON parseavel"
  Assert-True ($rc.json.'indice/gate' -eq 'OK') "C: indice/gate OK esperado; obtido $($rc.json.'indice/gate')"
  Assert-True ($rc.json.'indice/gravabilidade.cobertura' -eq 'partial') "C: cobertura partial esperada; obtida $($rc.json.'indice/gravabilidade.cobertura')"

  # --- D: GATE_OK sem cobertura -> nao pode ser aceito ---
  $d = New-SetupAuditFixture -GateText @'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $rd = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $d.Root, '-GateWrapperPath', $d.Gate, '-MetadataWrapperTestPath', $d.Metadata,
    '-PowerShellRuntimeTestPath', $d.Runtime, '-NamingWrapperPath', $d.Naming, '-AsJson')
  Assert-True ($null -ne $rd.json) "D: stdout deveria ser JSON parseavel"
  Assert-True ($rd.json.'indice/gate' -eq 'PENDENTE') "D: indice/gate PENDENTE esperado; obtido $($rd.json.'indice/gate')"
  Assert-True ($rd.json.'indice/gravabilidade.cobertura' -eq 'unknown') "D: cobertura unknown esperada; obtida $($rd.json.'indice/gravabilidade.cobertura')"
  Assert-True ([string]$rd.json.'indice/gravabilidade.aviso' -match 'sem campo writability_coverage') "D: aviso de cobertura ausente esperado"

  # --- E: mascara degradada -> estado exposto sem bloquear o gate ---
  $e = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: true'
Write-Output 'source_mask_degraded_warning: Mascara de Source degradada; cobertura parcial.'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $re = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $e.Root, '-GateWrapperPath', $e.Gate, '-MetadataWrapperTestPath', $e.Metadata,
    '-PowerShellRuntimeTestPath', $e.Runtime, '-NamingWrapperPath', $e.Naming, '-AsJson')
  Assert-True ($null -ne $re.json) "E: stdout deveria ser JSON parseavel"
  Assert-True ($re.json.'indice/gate' -eq 'OK') "E: indice/gate OK esperado; obtido $($re.json.'indice/gate')"
  Assert-True ($re.json.'indice/mascara' -eq 'true') "E: indice/mascara true esperado; obtido $($re.json.'indice/mascara')"
  Assert-True ([string]$re.json.'indice/mascara.aviso' -match 'degradada') "E: aviso de mascara degradada esperado"

  # --- F: GATE_OK sem source_mask_degraded -> gate PENDENTE e estado nao limpo ---
  $f = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $rf = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $f.Root, '-GateWrapperPath', $f.Gate, '-MetadataWrapperTestPath', $f.Metadata,
    '-PowerShellRuntimeTestPath', $f.Runtime, '-NamingWrapperPath', $f.Naming, '-AsJson')
  Assert-True ($null -ne $rf.json) "F: stdout deveria ser JSON parseavel"
  Assert-True ($rf.json.'indice/gate' -eq 'PENDENTE') "F: indice/gate PENDENTE esperado; obtido $($rf.json.'indice/gate')"
  Assert-True ($rf.json.'indice/mascara' -eq 'unknown') "F: indice/mascara unknown esperado; obtido $($rf.json.'indice/mascara')"
  Assert-True ([string]$rf.json.'indice/mascara.aviso' -match 'sem source_mask_degraded') "F: aviso de contrato ausente esperado"
  Assert-True ($rf.json.estado_operacional_sugerido -ne 'materializado_e_indice_validado') "F: estado nao pode ser materializado_e_indice_validado"

  # --- G: valor invalido nao pode ser aceito por prefixo ---
  $g = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false-corrompido'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $rg = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $g.Root, '-GateWrapperPath', $g.Gate, '-MetadataWrapperTestPath', $g.Metadata,
    '-PowerShellRuntimeTestPath', $g.Runtime, '-NamingWrapperPath', $g.Naming, '-AsJson')
  Assert-True ($null -ne $rg.json) "G: stdout deveria ser JSON parseavel"
  Assert-True ($rg.json.'indice/gate' -eq 'PENDENTE') "G: indice/gate PENDENTE esperado; obtido $($rg.json.'indice/gate')"
  Assert-True ($rg.json.'indice/mascara' -eq 'unknown') "G: indice/mascara unknown esperado; obtido $($rg.json.'indice/mascara')"

  # --- H: source_mask_degraded=true sem aviso -> contrato incompleto ---
  $h = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: true'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $rh = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $h.Root, '-GateWrapperPath', $h.Gate, '-MetadataWrapperTestPath', $h.Metadata,
    '-PowerShellRuntimeTestPath', $h.Runtime, '-NamingWrapperPath', $h.Naming, '-AsJson')
  Assert-True ($null -ne $rh.json) "H: stdout deveria ser JSON parseavel"
  Assert-True ($rh.json.'indice/gate' -eq 'PENDENTE') "H: indice/gate PENDENTE esperado; obtido $($rh.json.'indice/gate')"
  Assert-True ($rh.json.'indice/mascara' -eq 'unknown') "H: indice/mascara unknown esperado; obtido $($rh.json.'indice/mascara')"
  Assert-True ([string]$rh.json.'indice/mascara.aviso' -match 'sem source_mask_degraded_warning') "H: aviso de contrato incompleto esperado"

  # --- I: false com aviso -> estado inconsistente ---
  $i = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false'
Write-Output 'source_mask_degraded_warning: aviso indevido'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $ri = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $i.Root, '-GateWrapperPath', $i.Gate, '-MetadataWrapperTestPath', $i.Metadata,
    '-PowerShellRuntimeTestPath', $i.Runtime, '-NamingWrapperPath', $i.Naming, '-AsJson')
  Assert-True ($null -ne $ri.json) "I: stdout deveria ser JSON parseavel"
  Assert-True ($ri.json.'indice/gate' -eq 'PENDENTE') "I: indice/gate PENDENTE esperado; obtido $($ri.json.'indice/gate')"
  Assert-True ($ri.json.'indice/mascara' -eq 'unknown') "I: indice/mascara unknown esperado; obtido $($ri.json.'indice/mascara')"
  Assert-True ([string]$ri.json.'indice/mascara.aviso' -match 'inconsistente') "I: aviso de estado inconsistente esperado"

  'XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK'
}
finally {
  foreach ($r in $roots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
