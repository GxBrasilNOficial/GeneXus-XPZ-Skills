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
    exitCode          = 0
    status            = 'compilou limpo'
    executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
    observedContext   = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals     = [ordered]@{ postBuildEvents = @('Powershell Write-Output teste-pb-x') }
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
    exitCode          = 0
    status            = 'compilou limpo'
    executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
    observedContext   = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals     = [ordered]@{ postBuildEvents = @($pbLine1) }
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
  Assert-True ([string]$rn.json.'pos-build/registro.evidencia' -match 'regravar com Register-\*KbPostBuildEvents\.ps1') "N: evidencia deve dizer a acao exata (regravar); obtido $($rn.json.'pos-build/registro.evidencia')"

  # --- O/P/Q/R: espelho e campo, sem build (regras de forma e divergencia) ---
  $pbRun = {
    param($f)
    Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
      '-KbRoot', $f.Root, '-GateWrapperPath', $f.Gate, '-MetadataWrapperTestPath', $f.Metadata,
      '-PowerShellRuntimeTestPath', $f.Runtime, '-NamingWrapperPath', $f.Naming, '-AsJson')
  }
  $pbFamily1 = Get-GeneXusPostBuildEventFamilyHash -Line $pbLine1
  $pbLegacy1 = Get-GeneXusPostBuildEventNormalizedHash -Line $pbLine1
  $pbFamily2 = Get-GeneXusPostBuildEventFamilyHash -Line $pbLine2
  $pbGateText = @'
Write-Output 'writability_coverage: complete-in-model'
Write-Output 'source_mask_degraded: false'
Write-Output 'inventory_validation_status: OK'
Write-Output 'GATE_OK'
'@

  # O: espelho ausente, campo de familia, sem build -> SEM_EVIDENCIA (nunca OK sem build)
  $o = New-SetupAuditFixture -GateText $pbGateText
  [System.IO.File]::WriteAllText((Join-Path $o.Root 'kb-source-metadata.md'),
    "kb_environment_post_build_event_hashes: NETFrameworkSQLServer=$pbFamily1`n", $utf8NoBom)
  $ro = & $pbRun $o
  Assert-True ($null -ne $ro.json) "O: stdout deveria ser JSON parseavel"
  Assert-True ($ro.json.'pos-build/registro' -eq 'SEM_EVIDENCIA') "O: SEM_EVIDENCIA esperado sem espelho e sem build; obtido $($ro.json.'pos-build/registro')"

  # P: espelho com duas familias (linha de familia + evento executavel de outra familia) e campo com uma
  #    -> PENDENTE por divergencia. Linhas com a mesma familia e contagens diferentes contam como uma so.
  $pbOther = 'Powershell Write-Output teste-pb-x'
  $p = New-SetupAuditFixture -GateText $pbGateText
  [System.IO.File]::WriteAllText((Join-Path $p.Root 'kb-source-metadata.md'), @"
kb_environment_post_build_event_hashes: NETFrameworkSQLServer=$pbFamily1

## Eventos pos-build registrados

### env: NETFrameworkSQLServer

- ``$pbLine1``
- ``$pbOther``

"@, $utf8NoBom)
  $rp = & $pbRun $p
  Assert-True ($null -ne $rp.json) "P: stdout deveria ser JSON parseavel"
  Assert-True ($rp.json.'pos-build/registro' -eq 'PENDENTE') "P: PENDENTE esperado com espelho divergente; obtido $($rp.json.'pos-build/registro')"
  Assert-True ([string]$rp.json.'pos-build/registro.evidencia' -match 'espelho divergente') "P: evidencia deve citar espelho divergente; obtido $($rp.json.'pos-build/registro.evidencia')"

  # Q: campo com hash legado e espelho coerente com a linha crua, sem build -> PENDENTE por forma legada
  $q = New-SetupAuditFixture -GateText $pbGateText
  [System.IO.File]::WriteAllText((Join-Path $q.Root 'kb-source-metadata.md'), @"
kb_environment_post_build_event_hashes: NETFrameworkSQLServer=$pbLegacy1

## Eventos pos-build registrados

### env: NETFrameworkSQLServer

- ``$pbLine1``

"@, $utf8NoBom)
  $rq = & $pbRun $q
  Assert-True ($null -ne $rq.json) "Q: stdout deveria ser JSON parseavel"
  Assert-True ($rq.json.'pos-build/registro' -eq 'PENDENTE') "Q: PENDENTE esperado para forma legada sem build; obtido $($rq.json.'pos-build/registro')"
  Assert-True ([string]$rq.json.'pos-build/registro.evidencia' -match 'forma legada') "Q: evidencia deve citar forma legada"
  Assert-True ([string]$rq.json.'pos-build/registro.evidencia' -match 'regravar com Register-\*KbPostBuildEvents\.ps1') "Q: evidencia deve dizer a acao exata"

  # R: campo e espelho de familia coerentes, sem build -> SEM_EVIDENCIA (nunca OK sem build)
  $r = New-SetupAuditFixture -GateText $pbGateText
  [System.IO.File]::WriteAllText((Join-Path $r.Root 'kb-source-metadata.md'), @"
kb_environment_post_build_event_hashes: NETFrameworkSQLServer=$pbFamily1

## Eventos pos-build registrados

### env: NETFrameworkSQLServer

- ``$pbLine1``

"@, $utf8NoBom)
  $rr = & $pbRun $r
  Assert-True ($null -ne $rr.json) "R: stdout deveria ser JSON parseavel"
  Assert-True ($rr.json.'pos-build/registro' -eq 'SEM_EVIDENCIA') "R: SEM_EVIDENCIA esperado para familia coerente sem build; obtido $($rr.json.'pos-build/registro')"
  Assert-True ([string]$rr.json.'pos-build/registro.evidencia' -match 'sem build') "R: evidencia deve dizer que falta build"

  # --- S a X: pos-build/base (o build mais recente serve de base para registrar?) ---
  $pbBase = {
    param([hashtable]$Spec)
    $fx = New-SetupAuditFixture -GateText $pbGateText
    $dir = Join-Path $fx.Root 'Temp\build-base'
    [void](New-Item -ItemType Directory -Path $dir -Force)
    $classification = [ordered]@{ unexpected = @($Spec.Unexpected) }
    if ($Spec.RegistryState) { $classification['registryStatus'] = [ordered]@{ state = $Spec.RegistryState } }
    $doc = [ordered]@{
      exitCode        = $Spec.ExitCode
      status          = $Spec.Status
      observedContext = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
      stdoutSignals   = [ordered]@{
        postBuildEvents              = @('Powershell Write-Output teste-pb-x')
        postBuildEventClassification = $classification
      }
    }
    if ($Spec.ContainsKey('PendingCauses')) { $doc['pendingCauses'] = @($Spec['PendingCauses']) }
    if ($Spec.ContainsKey('PostProcessingFailed')) { $doc['postProcessingFailed'] = [bool]$Spec['PostProcessingFailed'] }
    if ($null -ne $Spec.MsBuildExitCode) {
      $doc['executionEvidence'] = [ordered]@{ msBuildExitCode = $Spec.MsBuildExitCode; msBuildFailed = ($Spec.ContainsKey('MsBuildFailed') -and [bool]$Spec['MsBuildFailed']) }
    }
    [System.IO.File]::WriteAllText((Join-Path $dir 'build.json'), ($doc | ConvertTo-Json -Depth 8), $utf8NoBom)
    return (& $pbRun $fx)
  }
  $pbPending = 'operacao concluida, pendente de confirmacao funcional'
  # Status pendente do SpecifyGenerate (acentuado), montado por codigo para nao depender do encoding deste arquivo.
  $pbPendingSg = 'opera' + [char]0x00E7 + [char]0x00E3 + 'o conclu' + [char]0x00ED + 'da, pendente de confirma' + [char]0x00E7 + [char]0x00E3 + 'o funcional'
  $pbSgRecovery = 'specify e generate conclu' + [char]0x00ED + 'dos com falha no pos-processamento'

  $rs1 = & $pbBase @{ ExitCode = 0; Status = 'compilou limpo'; MsBuildExitCode = 0; RegistryState = $null; Unexpected = @() }
  Assert-True ($null -ne $rs1.json) "S1: stdout deveria ser JSON parseavel"
  Assert-True ($rs1.json.'pos-build/base' -eq 'APTO') "S1: APTO esperado para compilou limpo; obtido $($rs1.json.'pos-build/base') / $($rs1.json.'pos-build/base.evidencia')"

  $rs2 = & $pbBase @{ ExitCode = 0; Status = $pbPending; PendingCauses = @('postBuildEvent'); MsBuildExitCode = 0; RegistryState = 'noEntryForEnvironment'; Unexpected = @() }
  Assert-True ($rs2.json.'pos-build/base' -eq 'APTO') "S2: APTO esperado para pendente so por evento pos-build (environment sem registro); obtido $($rs2.json.'pos-build/base') / $($rs2.json.'pos-build/base.evidencia')"

  # S3: environment ja registrado (available), evento novo ou mudado -> APTO (antes dava impasse com o Register)
  $rs3 = & $pbBase @{ ExitCode = 0; Status = $pbPending; PendingCauses = @('postBuildEvent'); MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @('evento novo') }
  Assert-True ($rs3.json.'pos-build/base' -eq 'APTO') "S3: APTO esperado para pendente so por evento novo com registryStatus available; obtido $($rs3.json.'pos-build/base') / $($rs3.json.'pos-build/base.evidencia')"

  # S4: available, mas a pendencia tem stderr alem do evento -> NAO_APTO
  $rs4 = & $pbBase @{ ExitCode = 0; Status = $pbPending; PendingCauses = @('stderr', 'postBuildEvent'); MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @('evento novo') }
  Assert-True ($rs4.json.'pos-build/base' -eq 'NAO_APTO') "S4: NAO_APTO esperado com causa alem de evento; obtido $($rs4.json.'pos-build/base')"
  Assert-True ([string]$rs4.json.'pos-build/base.evidencia' -match 'causa alem de evento') "S4: evidencia deve citar a causa alem de evento"

  # S5: registro nao consultado (metadataNotProvided) -> NAO_APTO mesmo so com evento
  $rs5 = & $pbBase @{ ExitCode = 0; Status = $pbPending; PendingCauses = @('postBuildEvent'); MsBuildExitCode = 0; RegistryState = 'metadataNotProvided'; Unexpected = @() }
  Assert-True ($rs5.json.'pos-build/base' -eq 'NAO_APTO') "S5: NAO_APTO esperado com registro nao consultado; obtido $($rs5.json.'pos-build/base')"
  Assert-True ([string]$rs5.json.'pos-build/base.evidencia' -match 'nao foi consultado') "S5: evidencia deve citar registro nao consultado"

  # S6: caso conhecido do compressor de estaticos junto com o evento -> NAO_APTO (o compressor e outra causa)
  $rs6 = & $pbBase @{ ExitCode = 0; Status = $pbPending; PendingCauses = @('postBuildEvent', 'staticCompressor'); MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @('evento novo') }
  Assert-True ($rs6.json.'pos-build/base' -eq 'NAO_APTO') "S6: NAO_APTO esperado com o compressor de estaticos; obtido $($rs6.json.'pos-build/base')"
  Assert-True ([string]$rs6.json.'pos-build/base.evidencia' -match 'staticCompressor') "S6: evidencia deve citar staticCompressor"

  # S7: SpecifyGenerate pendente so por evento (status acentuado, summary generico) -> APTO
  $rs7 = & $pbBase @{ ExitCode = 0; Status = $pbPendingSg; PendingCauses = @('postBuildEvent'); MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @('evento novo') }
  Assert-True ($rs7.json.'pos-build/base' -eq 'APTO') "S7: APTO esperado para SpecifyGenerate pendente so por evento; obtido $($rs7.json.'pos-build/base') / $($rs7.json.'pos-build/base.evidencia')"

  # S8: pendente sem o campo pendingCauses (build anterior ao campo) -> NAO_APTO
  $rs8 = & $pbBase @{ ExitCode = 0; Status = $pbPending; MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @('evento novo') }
  Assert-True ($rs8.json.'pos-build/base' -eq 'NAO_APTO') "S8: NAO_APTO esperado sem pendingCauses; obtido $($rs8.json.'pos-build/base')"
  Assert-True ([string]$rs8.json.'pos-build/base.evidencia' -match 'sem pendingCauses') "S8: evidencia deve citar a falta de pendingCauses"

  # S9: status de recuperacao do SpecifyGenerate (falha no pos-processamento) -> NAO_APTO
  $rs9 = & $pbBase @{ ExitCode = 0; Status = $pbSgRecovery; MsBuildExitCode = 0; RegistryState = $null; Unexpected = @() }
  Assert-True ($rs9.json.'pos-build/base' -eq 'NAO_APTO') "S9: NAO_APTO esperado para status de recuperacao; obtido $($rs9.json.'pos-build/base')"
  Assert-True ([string]$rs9.json.'pos-build/base.evidencia' -match 'status nao previsto') "S9: evidencia deve citar status nao previsto"

  # S10 a S12: falha no pos-processamento do wrapper com status limpo (o wrapper mantem o status) -> NAO_APTO
  $rs10 = & $pbBase @{ ExitCode = 0; Status = 'compilou limpo'; PendingCauses = @('postProcessingFailed'); PostProcessingFailed = $true; MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @() }
  Assert-True ($rs10.json.'pos-build/base' -eq 'NAO_APTO') "S10: NAO_APTO esperado para compilou limpo com postProcessingFailed; obtido $($rs10.json.'pos-build/base')"
  Assert-True ([string]$rs10.json.'pos-build/base.evidencia' -match 'postProcessingFailed') "S10: evidencia deve citar postProcessingFailed"
  # S11: so o campo do topo do JSON (sem pendingCauses)
  $rs11 = & $pbBase @{ ExitCode = 0; Status = 'compilou limpo'; PostProcessingFailed = $true; MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @() }
  Assert-True ($rs11.json.'pos-build/base' -eq 'NAO_APTO') "S11: NAO_APTO esperado com postProcessingFailed so no topo; obtido $($rs11.json.'pos-build/base')"
  # S12: SpecifyGenerate limpo, so em pendingCauses
  $pbSgClean = 'specify e generate conclu' + [char]0x00ED + 'dos'
  $rs12 = & $pbBase @{ ExitCode = 0; Status = $pbSgClean; PendingCauses = @('postProcessingFailed'); MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @() }
  Assert-True ($rs12.json.'pos-build/base' -eq 'NAO_APTO') "S12: NAO_APTO esperado para SpecifyGenerate limpo com postProcessingFailed em pendingCauses; obtido $($rs12.json.'pos-build/base')"
  # Controle: compilou limpo com postProcessingFailed=false continua APTO
  $rs13 = & $pbBase @{ ExitCode = 0; Status = 'compilou limpo'; PendingCauses = @(); PostProcessingFailed = $false; MsBuildExitCode = 0; RegistryState = 'available'; Unexpected = @() }
  Assert-True ($rs13.json.'pos-build/base' -eq 'APTO') "S13: APTO esperado com postProcessingFailed falso; obtido $($rs13.json.'pos-build/base') / $($rs13.json.'pos-build/base.evidencia')"

  $rt = & $pbBase @{ ExitCode = 0; Status = $pbPending; MsBuildExitCode = 0; RegistryState = $null; Unexpected = @() }
  Assert-True ($rt.json.'pos-build/base' -eq 'NAO_APTO') "T: NAO_APTO esperado sem registryStatus; obtido $($rt.json.'pos-build/base')"
  Assert-True ([string]$rt.json.'pos-build/base.evidencia' -match 'sem registryStatus') "T: evidencia deve citar a falta de registryStatus"
  Assert-True ([string]$rt.json.'pos-build/base.evidencia' -match 'gerar build novo') "T: evidencia deve mandar gerar build novo"

  $ru = & $pbBase @{ ExitCode = 0; Status = $pbPending; MsBuildExitCode = $null; RegistryState = 'noEntryForEnvironment'; Unexpected = @() }
  Assert-True ($ru.json.'pos-build/base' -eq 'NAO_APTO') "U: NAO_APTO esperado sem msBuildExitCode; obtido $($ru.json.'pos-build/base')"
  Assert-True ([string]$ru.json.'pos-build/base.evidencia' -match 'msBuildExitCode') "U: evidencia deve citar msBuildExitCode"

  $rv = & $pbBase @{ ExitCode = 0; Status = $pbPending; PendingCauses = @('stderr'); MsBuildExitCode = 0; RegistryState = 'noEntryForEnvironment'; Unexpected = @('linha inesperada') }
  Assert-True ($rv.json.'pos-build/base' -eq 'NAO_APTO') "V: NAO_APTO esperado quando a pendencia nao vem de evento; obtido $($rv.json.'pos-build/base')"
  Assert-True ([string]$rv.json.'pos-build/base.evidencia' -match 'causa alem de evento') "V: evidencia deve citar a causa da pendencia"

  $rx = & $pbBase @{ ExitCode = 1; Status = 'compilou limpo'; MsBuildExitCode = 0; RegistryState = $null; Unexpected = @() }
  Assert-True ($rx.json.'pos-build/base' -eq 'NAO_APTO') "X: NAO_APTO esperado com exitCode diferente de 0; obtido $($rx.json.'pos-build/base')"
  Assert-True ([string]$rx.json.'pos-build/base.evidencia' -match 'exitCode') "X: evidencia deve citar exitCode"

  $ry = & $pbBase @{ ExitCode = 0; Status = 'compilou limpo'; MsBuildExitCode = 0; MsBuildFailed = $true; RegistryState = $null; Unexpected = @() }
  Assert-True ($ry.json.'pos-build/base' -eq 'NAO_APTO') "Y: NAO_APTO esperado com msBuildFailed verdadeiro; obtido $($ry.json.'pos-build/base')"
  Assert-True ([string]$ry.json.'pos-build/base.evidencia' -match 'msBuildFailed') "Y: evidencia deve citar msBuildFailed"

  $rz = & $pbBase @{ ExitCode = 0; Status = 'falhou'; MsBuildExitCode = 0; RegistryState = $null; Unexpected = @() }
  Assert-True ($rz.json.'pos-build/base' -eq 'NAO_APTO') "Z: NAO_APTO esperado com status nao previsto; obtido $($rz.json.'pos-build/base')"
  Assert-True ([string]$rz.json.'pos-build/base.evidencia' -match 'status nao previsto') "Z: evidencia deve citar status nao previsto"

  # AA a AE: importacao_msbuild (regra 8.g6.i)
  # AA: artefato nominal de importacao em subpasta de Temp\ -> ADOTADO
  $aa = New-SetupAuditFixture -GateText $pbGateText
  $aaDir = Join-Path $aa.Root 'Temp\armA_import'
  [void](New-Item -ItemType Directory -Path $aaDir -Force)
  [System.IO.File]::WriteAllText((Join-Path $aaDir 'import.log'), "log`n", $utf8NoBom)
  $raa = & $pbRun $aa
  Assert-True ($raa.json.'importacao_msbuild' -eq 'ADOTADO') "AA: ADOTADO esperado com import.log em subpasta de Temp; obtido $($raa.json.'importacao_msbuild')"
  Assert-True ([string]$raa.json.'importacao_msbuild.evidencia' -match 'artefato de importacao') "AA: evidencia deve citar o artefato"

  # AB: wrapper local Invoke-*KbXpzImport.ps1 -> ADOTADO
  $ab = New-SetupAuditFixture -GateText $pbGateText
  $abDir = Join-Path $ab.Root 'scripts'
  [void](New-Item -ItemType Directory -Path $abDir -Force)
  [System.IO.File]::WriteAllText((Join-Path $abDir 'Invoke-DemoKbXpzImport.ps1'), "# wrapper`n", $utf8NoBom)
  $rab = & $pbRun $ab
  Assert-True ($rab.json.'importacao_msbuild' -eq 'ADOTADO') "AB: ADOTADO esperado com wrapper local de importacao; obtido $($rab.json.'importacao_msbuild')"
  Assert-True ([string]$rab.json.'importacao_msbuild.evidencia' -match 'wrapper local') "AB: evidencia deve citar o wrapper"

  # AC: referencia documental a importacao headless -> ADOTADO
  $ac = New-SetupAuditFixture -GateText $pbGateText
  [System.IO.File]::WriteAllText((Join-Path $ac.Root 'AGENTS.md'), "Fluxo: skill xpz-msbuild-import-export.`n", $utf8NoBom)
  $rac = & $pbRun $ac
  Assert-True ($rac.json.'importacao_msbuild' -eq 'ADOTADO') "AC: ADOTADO esperado com referencia documental; obtido $($rac.json.'importacao_msbuild')"
  Assert-True ([string]$rac.json.'importacao_msbuild.evidencia' -match 'referencia documental') "AC: evidencia deve citar a referencia documental"

  # AD: nenhuma evidencia -> NAO_ADOTADO
  $ad = New-SetupAuditFixture -GateText $pbGateText
  $rad = & $pbRun $ad
  Assert-True ($rad.json.'importacao_msbuild' -eq 'NAO_ADOTADO') "AD: NAO_ADOTADO esperado sem evidencia; obtido $($rad.json.'importacao_msbuild')"

  # AE: so a pasta de pacotes populada, sem referencia documental -> NAO_ADOTADO (mera existencia nao basta)
  $ae = New-SetupAuditFixture -GateText $pbGateText
  $aeDir = Join-Path $ae.Root 'PacotesGeradosParaImportacaoNaKbNoGenexus'
  [void](New-Item -ItemType Directory -Path $aeDir -Force)
  [System.IO.File]::WriteAllText((Join-Path $aeDir 'pacote.xpz'), "x`n", $utf8NoBom)
  $rae = & $pbRun $ae
  Assert-True ($rae.json.'importacao_msbuild' -eq 'NAO_ADOTADO') "AE: NAO_ADOTADO esperado so com pasta de pacotes; obtido $($rae.json.'importacao_msbuild')"

  # AF: msbuild.stdout.log de build em subpasta de Temp\, sem artefato de importacao -> NAO_ADOTADO
  # (BuildAll, SpecifyGenerate, exportacao e outros scripts MSBuild tambem gravam esse log)
  $af = New-SetupAuditFixture -GateText $pbGateText
  $afDir = Join-Path $af.Root 'Temp\build-x\gx-build-1'
  [void](New-Item -ItemType Directory -Path $afDir -Force)
  [System.IO.File]::WriteAllText((Join-Path $afDir 'msbuild.stdout.log'), "Build All Task Sucesso`n", $utf8NoBom)
  $raf = & $pbRun $af
  Assert-True ($raf.json.'importacao_msbuild' -eq 'NAO_ADOTADO') "AF: NAO_ADOTADO esperado so com msbuild.stdout.log de build; obtido $($raf.json.'importacao_msbuild') / $($raf.json.'importacao_msbuild.evidencia')"

  # AG: import-real.msbuild (artefato proprio de Invoke-GeneXusXpzImport.ps1) em subpasta de Temp\ -> ADOTADO
  $ag = New-SetupAuditFixture -GateText $pbGateText
  $agDir = Join-Path $ag.Root 'Temp\import-x\gx-import-1'
  [void](New-Item -ItemType Directory -Path $agDir -Force)
  [System.IO.File]::WriteAllText((Join-Path $agDir 'import-real.msbuild'), "<Project />`n", $utf8NoBom)
  [System.IO.File]::WriteAllText((Join-Path $agDir 'msbuild.stdout.log'), "log`n", $utf8NoBom)
  $rag = & $pbRun $ag
  Assert-True ($rag.json.'importacao_msbuild' -eq 'ADOTADO') "AG: ADOTADO esperado com import-real.msbuild em subpasta de Temp; obtido $($rag.json.'importacao_msbuild')"
  Assert-True ([string]$rag.json.'importacao_msbuild.evidencia' -match 'import-real\.msbuild') "AG: evidencia deve citar import-real.msbuild; obtido $($rag.json.'importacao_msbuild.evidencia')"

  # AH/AI: copia de recuperacao (sem stdoutSignals nem ActiveEnvironment) em Temp\xpz-msbuild-build\.
  # AH: mais nova que o build avaliado -> status mantido e as duas dimensoes avisam. AI: mais antiga -> sem aviso.
  $pbRecoveryCopy = {
    param([bool]$Newer)
    $fx = New-SetupAuditFixture -GateText $pbGateText
    $buildDir = Join-Path $fx.Root 'Temp\build-base'
    [void](New-Item -ItemType Directory -Path $buildDir -Force)
    $buildDoc = [ordered]@{
      exitCode          = 0
      status            = 'compilou limpo'
      observedContext   = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
      executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
      stdoutSignals     = [ordered]@{
        postBuildEvents              = @('Powershell Write-Output teste-pb-x')
        postBuildEventClassification = [ordered]@{ unexpected = @() }
      }
    }
    $buildPath = Join-Path $buildDir 'build.json'
    [System.IO.File]::WriteAllText($buildPath, ($buildDoc | ConvertTo-Json -Depth 8), $utf8NoBom)
    $copyDir = Join-Path $fx.Root 'Temp\xpz-msbuild-build'
    [void](New-Item -ItemType Directory -Path $copyDir -Force)
    $copyPath = Join-Path $copyDir 'buildall-20261123-120000-abcdef01.json'
    $recoveryDoc = [ordered]@{ status = 'compilou limpo com falha no pos-processamento'; exitCode = 0; postProcessingFailed = $true; observedContext = [ordered]@{ KbOpen = $true } }
    [System.IO.File]::WriteAllText($copyPath, ($recoveryDoc | ConvertTo-Json -Depth 4), $utf8NoBom)
    $now = Get-Date
    if ($Newer) {
      (Get-Item -LiteralPath $buildPath).LastWriteTime = $now.AddMinutes(-10)
      (Get-Item -LiteralPath $copyPath).LastWriteTime = $now
    } else {
      (Get-Item -LiteralPath $buildPath).LastWriteTime = $now
      (Get-Item -LiteralPath $copyPath).LastWriteTime = $now.AddMinutes(-10)
    }
    return (& $pbRun $fx)
  }
  $rah = & $pbRecoveryCopy $true
  Assert-True ($rah.json.'pos-build/base' -eq 'APTO') "AH: status de pos-build/base deve seguir o build anterior (APTO); obtido $($rah.json.'pos-build/base')"
  Assert-True ([string]$rah.json.'pos-build/base.evidencia' -match 'sem diagnostico utilizavel') "AH: pos-build/base.evidencia deve avisar do build mais novo; obtido $($rah.json.'pos-build/base.evidencia')"
  Assert-True ([string]$rah.json.'pos-build/registro.evidencia' -match 'buildall-20261123-120000-abcdef01\.json sem diagnostico utilizavel') "AH: pos-build/registro.evidencia deve citar o arquivo; obtido $($rah.json.'pos-build/registro.evidencia')"
  $rai = & $pbRecoveryCopy $false
  Assert-True ($rai.json.'pos-build/base' -eq 'APTO') "AI: APTO esperado; obtido $($rai.json.'pos-build/base')"
  Assert-True ([string]$rai.json.'pos-build/base.evidencia' -notmatch 'sem diagnostico utilizavel') "AI: sem aviso quando a copia de recuperacao e mais antiga; obtido $($rai.json.'pos-build/base.evidencia')"
  Assert-True ([string]$rai.json.'pos-build/registro.evidencia' -notmatch 'sem diagnostico utilizavel') "AI: sem aviso em pos-build/registro quando a copia e mais antiga"
  Assert-True ([string]$rah.json.'pos-build/registro.evidencia' -match 'sem environment identificado.*pode ser de NETFrameworkSQLServer') "AH: copia sem environment deve apontar o environment avaliado por build anterior; obtido $($rah.json.'pos-build/registro.evidencia')"

  # AJ-AN: comparacao por environment. Builds avaliados (com eventos) e copias sem diagnostico utilizavel, cada um
  # com environment e idade em minutos; validationEnvironment vazio = environment nao identificado.
  $pbEnvCopyCase = {
    param([object[]]$Builds, [object[]]$Copies)
    $fx = New-SetupAuditFixture -GateText $pbGateText
    $now = Get-Date
    $i = 0
    foreach ($b in $Builds) {
      $i++
      $dir = Join-Path $fx.Root ("Temp\build-{0}" -f $i)
      [void](New-Item -ItemType Directory -Path $dir -Force)
      $events = @()
      if ($b.Events) { $events = @('Powershell Write-Output teste-pb-x') }
      $doc = [ordered]@{
        exitCode          = 0
        status            = 'compilou limpo'
        observedContext   = [ordered]@{ ActiveEnvironment = $b.Env }
        executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
        stdoutSignals     = [ordered]@{ postBuildEvents = $events; postBuildEventClassification = [ordered]@{ unexpected = @() } }
      }
      $path = Join-Path $dir 'build.json'
      [System.IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 8), $utf8NoBom)
      (Get-Item -LiteralPath $path).LastWriteTime = $now.AddMinutes(-1 * $b.Age)
    }
    $copyDir = Join-Path $fx.Root 'Temp\xpz-msbuild-build'
    [void](New-Item -ItemType Directory -Path $copyDir -Force)
    foreach ($c in $Copies) {
      $doc = [ordered]@{ status = 'falha'; exitCode = 1; postProcessingFailed = $true }
      if ($c.Env) { $doc['validationEnvironment'] = $c.Env }
      $path = Join-Path $copyDir $c.Name
      [System.IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 4), $utf8NoBom)
      (Get-Item -LiteralPath $path).LastWriteTime = $now.AddMinutes(-1 * $c.Age)
    }
    return (& $pbRun $fx)
  }
  # AJ: falha de A mais nova que o build avaliado de A, com o build de B mais novo que a falha -> avisa por A.
  $raj = & $pbEnvCopyCase @(@{ Env = 'EnvA'; Age = 30; Events = $true }, @{ Env = 'EnvB'; Age = 0; Events = $true }) @(@{ Name = 'buildall-20261123-110000-0000000a.json'; Env = 'EnvA'; Age = 10 })
  Assert-True ([string]$raj.json.'pos-build/registro.evidencia' -match 'buildall-20261123-110000-0000000a\.json do environment EnvA sem diagnostico utilizavel.*avaliacao pelo build anterior desse environment') "AJ: deve avisar do build mais novo de EnvA mesmo com EnvB mais recente; obtido $($raj.json.'pos-build/registro.evidencia')"
  Assert-True ([string]$raj.json.'pos-build/base.evidencia' -match 'do environment EnvA sem diagnostico utilizavel') "AJ: pos-build/base.evidencia tambem deve avisar; obtido $($raj.json.'pos-build/base.evidencia')"
  # AK: falha de A seguida de build utilizavel de A mais novo (mesmo sem eventos) -> sem aviso.
  $rak = & $pbEnvCopyCase @(@{ Env = 'EnvA'; Age = 30; Events = $true }, @{ Env = 'EnvA'; Age = 5; Events = $false }) @(@{ Name = 'buildall-20261123-110000-0000000b.json'; Env = 'EnvA'; Age = 10 })
  Assert-True ([string]$rak.json.'pos-build/registro.evidencia' -notmatch 'sem diagnostico utilizavel') "AK: build utilizavel mais novo do mesmo environment dispensa o aviso; obtido $($rak.json.'pos-build/registro.evidencia')"
  # AL: falha de um environment sem build avaliado -> avisa que nao ha build anterior desse environment.
  $ral = & $pbEnvCopyCase @(@{ Env = 'EnvA'; Age = 0; Events = $true }) @(@{ Name = 'specifygenerate-20261123-110000-0000000c.json'; Env = 'EnvC'; Age = 10 })
  Assert-True ([string]$ral.json.'pos-build/registro.evidencia' -match 'specifygenerate-20261123-110000-0000000c\.json do environment EnvC sem diagnostico utilizavel.*nenhum build anterior avaliado para esse environment') "AL: deve avisar de EnvC sem build avaliado; obtido $($ral.json.'pos-build/registro.evidencia')"
  # AM: falha sem environment identificado e nenhum build avaliado -> nao fala em build anterior.
  $ram = & $pbEnvCopyCase @() @(@{ Name = 'buildall-20261123-110000-0000000d.json'; Env = ''; Age = 1 })
  Assert-True ([string]$ram.json.'pos-build/registro.evidencia' -match 'sem environment identificado.*nenhum build anterior avaliado' -and [string]$ram.json.'pos-build/registro.evidencia' -notmatch 'avaliacao pelo build anterior') "AM: sem build avaliado, o aviso nao deve citar build anterior; obtido $($ram.json.'pos-build/registro.evidencia')"
  # AN: falha sem environment, mais antiga que todos os builds avaliados -> sem aviso.
  $ran = & $pbEnvCopyCase @(@{ Env = 'EnvA'; Age = 0; Events = $true }, @{ Env = 'EnvB'; Age = 2; Events = $true }) @(@{ Name = 'buildall-20261123-110000-0000000e.json'; Env = ''; Age = 10 })
  Assert-True ([string]$ran.json.'pos-build/registro.evidencia' -notmatch 'sem diagnostico utilizavel') "AN: copia sem environment mais antiga que todos os builds avaliados nao deve avisar; obtido $($ran.json.'pos-build/registro.evidencia')"

  # AO: pos-build/base e status agregado; com dois environments, um apto e outro nao, a linha e NAO_APTO e o
  # veredito de cada environment fica na evidencia.
  $ao = New-SetupAuditFixture -GateText $pbGateText
  $aoBuilds = @(
    @{ Env = 'EnvA'; Status = 'compilou limpo' },
    @{ Env = 'EnvB'; Status = 'falhou' }
  )
  foreach ($aoBuild in $aoBuilds) {
    $aoDir = Join-Path $ao.Root ("Temp\build-{0}" -f $aoBuild.Env)
    [void](New-Item -ItemType Directory -Path $aoDir -Force)
    $aoDoc = [ordered]@{
      exitCode          = 0
      status            = $aoBuild.Status
      observedContext   = [ordered]@{ ActiveEnvironment = $aoBuild.Env }
      executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
      stdoutSignals     = [ordered]@{ postBuildEvents = @('Powershell Write-Output teste-pb-x'); postBuildEventClassification = [ordered]@{ unexpected = @() } }
    }
    [System.IO.File]::WriteAllText((Join-Path $aoDir 'build.json'), ($aoDoc | ConvertTo-Json -Depth 8), $utf8NoBom)
  }
  $rao = & $pbRun $ao
  Assert-True ($rao.json.'pos-build/base' -eq 'NAO_APTO') "AO: status agregado NAO_APTO esperado com um environment nao apto; obtido $($rao.json.'pos-build/base')"
  Assert-True ([string]$rao.json.'pos-build/base.evidencia' -match 'EnvA: apto') "AO: evidencia deve marcar EnvA como apto; obtido $($rao.json.'pos-build/base.evidencia')"
  Assert-True ([string]$rao.json.'pos-build/base.evidencia' -match 'EnvB: nao apto') "AO: evidencia deve marcar EnvB como nao apto; obtido $($rao.json.'pos-build/base.evidencia')"

  # AP: environment ja registrado (available) com evento novo fora do campo -> pos-build/registro PENDENTE
  $ap = New-SetupAuditFixture -GateText $pbGateText
  $apDir1 = Join-Path $ap.Root 'Temp\build-ap1'
  [void](New-Item -ItemType Directory -Path $apDir1 -Force)
  $apBuild1 = Join-Path $apDir1 'build.json'
  $apDoc1 = [ordered]@{
    exitCode          = 0
    status            = 'compilou limpo'
    executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
    observedContext   = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals     = [ordered]@{ postBuildEvents = @('Powershell Write-Output teste-pb-x') }
  }
  [System.IO.File]::WriteAllText($apBuild1, ($apDoc1 | ConvertTo-Json -Depth 6), $utf8NoBom)
  (Get-Item -LiteralPath $apBuild1).LastWriteTime = (Get-Date).AddMinutes(-5)
  $rap0 = Invoke-XpzSelfTestScript -ScriptPath $register -ScriptArgs @(
    '-BuildResultJsonPath', $apBuild1, '-KbParallelRoot', $ap.Root, '-EnvironmentName', 'NETFrameworkSQLServer',
    '-ConfirmRegistration', '-AsJson')
  Assert-True ($rap0.exit -eq 0) "AP: registro deveria sair 0; obtido $($rap0.exit)"
  $apDir2 = Join-Path $ap.Root 'Temp\build-ap2'
  [void](New-Item -ItemType Directory -Path $apDir2 -Force)
  $apDoc2 = [ordered]@{
    observedContext = [ordered]@{ ActiveEnvironment = 'NETFrameworkSQLServer' }
    stdoutSignals   = [ordered]@{ postBuildEvents = @('Powershell Write-Output teste-pb-x', 'Powershell Write-Output evento-novo') }
  }
  [System.IO.File]::WriteAllText((Join-Path $apDir2 'build.json'), ($apDoc2 | ConvertTo-Json -Depth 6), $utf8NoBom)
  $rap = & $pbRun $ap
  Assert-True ($rap.json.'pos-build/registro' -eq 'PENDENTE') "AP: PENDENTE esperado com evento novo num environment ja registrado; obtido $($rap.json.'pos-build/registro') / $($rap.json.'pos-build/registro.evidencia')"
  Assert-True ([string]$rap.json.'pos-build/registro.evidencia' -match 'sem registro=1') "AP: evidencia deve contar o evento novo (sem registro=1); obtido $($rap.json.'pos-build/registro.evidencia')"

  # SG: sucesso do SpecifyGenerate (status "specify e generate concluidos") tambem serve de base
  $pbSpecifyOk = 'specify e generate conclu' + [char]0x00ED + 'dos'
  $rsg = & $pbBase @{ ExitCode = 0; Status = $pbSpecifyOk; MsBuildExitCode = 0; RegistryState = $null; Unexpected = @() }
  Assert-True ($rsg.json.'pos-build/base' -eq 'APTO') "SG: APTO esperado para sucesso do SpecifyGenerate; obtido $($rsg.json.'pos-build/base') / $($rsg.json.'pos-build/base.evidencia')"

  # W: sem build com eventos em Temp\ -> SEM_EVIDENCIA (reaproveita o caso L)
  Assert-True ($rl.json.'pos-build/base' -eq 'SEM_EVIDENCIA') "W: pos-build/base SEM_EVIDENCIA esperado sem build; obtido $($rl.json.'pos-build/base')"

  'XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK'
}
finally {
  foreach ($r in $roots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
