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

  # --- J: evento pos-build observado em Temp\ sem registro -> pos-build/registro PENDENTE ---
  $j = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $jTemp = Join-Path $j.Root 'Temp\build-pb'
  [void](New-Item -ItemType Directory -Path $jTemp -Force)
  $jBuild = Join-Path $jTemp 'build.json'
  $jDoc = [ordered]@{
    observedContext = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals   = [ordered]@{ postBuildEvents = @('Powershell Write-Output teste-pb-x') }
  }
  [System.IO.File]::WriteAllText($jBuild, ($jDoc | ConvertTo-Json -Depth 6), $utf8NoBom)
  $rj = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $j.Root, '-GateWrapperPath', $j.Gate, '-MetadataWrapperTestPath', $j.Metadata,
    '-PowerShellRuntimeTestPath', $j.Runtime, '-NamingWrapperPath', $j.Naming, '-AsJson')
  Assert-True ($null -ne $rj.json) "J: stdout deveria ser JSON parseavel"
  Assert-True ($rj.json.'pos-build/registro' -eq 'PENDENTE') "J: pos-build/registro PENDENTE esperado; obtido $($rj.json.'pos-build/registro')"
  Assert-True ([string]$rj.json.'pos-build/registro.evidencia' -match 'NETFrameworkSQLServer') "J: evidencia deve citar o environment"
  Assert-True ($rj.json.estado_operacional_sugerido -ne 'materializado_e_indice_validado') "J: estado nao pode ser limpo com registro pendente"

  # --- K: mesmo build apos registro feito pelo motor oficial -> pos-build/registro OK ---
  $register = Join-Path $PSScriptRoot 'Register-GeneXusKbPostBuildEvents.ps1'
  $rk0 = Invoke-XpzSelfTestScript -ScriptPath $register -ScriptArgs @(
    '-BuildResultJsonPath', $jBuild, '-KbParallelRoot', $j.Root, '-EnvironmentName', 'NETFrameworkSQLServer',
    '-ConfirmRegistration', '-AsJson')
  Assert-True ($rk0.exit -eq 0) "K: registro deveria sair 0; obtido $($rk0.exit)"
  $rk = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $j.Root, '-GateWrapperPath', $j.Gate, '-MetadataWrapperTestPath', $j.Metadata,
    '-PowerShellRuntimeTestPath', $j.Runtime, '-NamingWrapperPath', $j.Naming, '-AsJson')
  Assert-True ($null -ne $rk.json) "K: stdout deveria ser JSON parseavel"
  Assert-True ($rk.json.'pos-build/registro' -eq 'OK') "K: pos-build/registro OK esperado apos registro; obtido $($rk.json.'pos-build/registro')"

  # --- L: sem nenhum build com eventos em Temp\ -> SEM_EVIDENCIA (nem pendencia, nem limpo) ---
  $l = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $rl = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $l.Root, '-GateWrapperPath', $l.Gate, '-MetadataWrapperTestPath', $l.Metadata,
    '-PowerShellRuntimeTestPath', $l.Runtime, '-NamingWrapperPath', $l.Naming, '-AsJson')
  Assert-True ($null -ne $rl.json) "L: stdout deveria ser JSON parseavel"
  Assert-True ($rl.json.'pos-build/registro' -eq 'SEM_EVIDENCIA') "L: SEM_EVIDENCIA esperado; obtido $($rl.json.'pos-build/registro')"

  # --- M: registro na forma de familia; build com contagens diferentes -> OK (comparacao por hash) ---
  . (Join-Path $PSScriptRoot 'GeneXusMsBuildPostBuildEventsSupport.ps1')
  $pbLine1 = '[APLICADO] .js varridos=2968 | arquivos com chave negativa em gx.domain=3 | chaves corrigidas=5'
  $pbLine2 = '[APLICADO] .js varridos=2178 | arquivos com chave negativa em gx.domain=1 | chaves corrigidas=2'
  $m = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $mDir1 = Join-Path $m.Root 'Temp\build-m1'
  [void](New-Item -ItemType Directory -Path $mDir1 -Force)
  $mBuild1 = Join-Path $mDir1 'build.json'
  $mDoc1 = [ordered]@{
    observedContext = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals   = [ordered]@{ postBuildEvents = @($pbLine1) }
  }
  [System.IO.File]::WriteAllText($mBuild1, ($mDoc1 | ConvertTo-Json -Depth 6), $utf8NoBom)
  (Get-Item -LiteralPath $mBuild1).LastWriteTime = (Get-Date).AddMinutes(-5)
  $register2 = Join-Path $PSScriptRoot 'Register-GeneXusKbPostBuildEvents.ps1'
  $rm0 = Invoke-XpzSelfTestScript -ScriptPath $register2 -ScriptArgs @(
    '-BuildResultJsonPath', $mBuild1, '-KbParallelRoot', $m.Root, '-EnvironmentName', 'NETFrameworkSQLServer',
    '-ConfirmRegistration', '-AsJson')
  Assert-True ($rm0.exit -eq 0) "M: registro deveria sair 0; obtido $($rm0.exit)"
  $mDir2 = Join-Path $m.Root 'Temp\build-m2'
  [void](New-Item -ItemType Directory -Path $mDir2 -Force)
  $mDoc2 = [ordered]@{
    observedContext = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals   = [ordered]@{ postBuildEvents = @($pbLine2) }
  }
  [System.IO.File]::WriteAllText((Join-Path $mDir2 'build.json'), ($mDoc2 | ConvertTo-Json -Depth 6), $utf8NoBom)
  $rm = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $m.Root, '-GateWrapperPath', $m.Gate, '-MetadataWrapperTestPath', $m.Metadata,
    '-PowerShellRuntimeTestPath', $m.Runtime, '-NamingWrapperPath', $m.Naming, '-AsJson')
  Assert-True ($null -ne $rm.json) "M: stdout deveria ser JSON parseavel"
  Assert-True ($rm.json.'pos-build/registro' -eq 'OK') "M: OK esperado (forma de familia cobre contagem diferente); obtido $($rm.json.'pos-build/registro') / $($rm.json.'pos-build/registro.evidencia')"

  # --- N: registro so na forma legada, mesma contagem -> PENDENTE com aviso de regravacao ---
  $n = New-SetupAuditFixture -GateText @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@
  $nLegacyHash = Get-GeneXusPostBuildEventNormalizedHash -Line $pbLine1
  Add-Content -LiteralPath (Join-Path $n.Root 'kb-source-metadata.md') -Value "kb_environment_post_build_event_hashes: NETFrameworkSQLServer=$nLegacyHash" -Encoding utf8
  $nDir = Join-Path $n.Root 'Temp\build-n'
  [void](New-Item -ItemType Directory -Path $nDir -Force)
  $nDoc = [ordered]@{
    observedContext = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals   = [ordered]@{ postBuildEvents = @($pbLine1) }
  }
  [System.IO.File]::WriteAllText((Join-Path $nDir 'build.json'), ($nDoc | ConvertTo-Json -Depth 6), $utf8NoBom)
  $rn = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-KbRoot', $n.Root, '-GateWrapperPath', $n.Gate, '-MetadataWrapperTestPath', $n.Metadata,
    '-PowerShellRuntimeTestPath', $n.Runtime, '-NamingWrapperPath', $n.Naming, '-AsJson')
  Assert-True ($null -ne $rn.json) "N: stdout deveria ser JSON parseavel"
  Assert-True ($rn.json.'pos-build/registro' -eq 'PENDENTE') "N: PENDENTE esperado para registro legado; obtido $($rn.json.'pos-build/registro')"
  Assert-True ([string]$rn.json.'pos-build/registro.evidencia' -match 'forma legada') "N: evidencia deve avisar forma legada; obtido $($rn.json.'pos-build/registro.evidencia')"

  'XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK'
}
finally {
  foreach ($r in $roots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
