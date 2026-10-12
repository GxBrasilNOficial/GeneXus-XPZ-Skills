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

  'XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK'
}
finally {
  foreach ($r in $roots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
