#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de drift do registro de hosting kinds (GeneXusKbHostingKindSupport.ps1).

.DESCRIPTION
    Fase 1 da paridade de gerador Java/Tomcat. Trava as invariantes do contrato congelado
    (decisao (a) do design) por verificacao real (dot-source), nao por regex sobre o codigo:

      - dot-source real     : carrega o registro e exercita a API publica de verdade.
      - dispatch por familia: cada kind roteia para a familia correta (dotnet|java).
      - uso da API publica  : nenhum script consome a hashtable interna direto (varredura por arquivo).
      - contrato de skip     : recognized-no-engine -> status 'skipped-hosting-unsupported' + unsupportedReason;
                               a string de skip tem fonte unica (nenhum emissor a redigita — varredura por arquivo).
      - clausula no-bridge  : nenhum codigo de Fase 1/2 referencia publicationTargets (checagem estatica; por arquivo).

    Emissores nomeados do contrato de skip (derivam a string, nunca a redigitam). Hoje ainda
    .NET-only; a fiacao ao registro e da Fase 2 — esta lista guia a auditoria daquela fase:
      * Resolve-GeneXusKbDeployBinCheckPolicy  (GeneXusKbDeployBinSupport.ps1:88)
      * fachada de diagnostico                  (Test-GeneXusDeployBinFreshness.ps1:142)
      * [ValidateSet] -> validacao manual        (Set-XpzKbSourceMetadataDeployment.ps1:93)
      * validacao de presenca                    (GeneXusKbDeploymentEnvironmentSupport.ps1:526)
      * guardas de familia dos Eixos C/B         (Test-GeneXusRuntimeFreshness.ps1 / diagnostico .cs)

    Falha => 'ASSERT_FAILED: ...'; sucesso => 'GENEXUS_HOSTING_KIND_DRIFT_SELFTEST_OK'.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir    = Split-Path -Parent $PSCommandPath
$registryFile = Join-Path $scriptDir 'GeneXusKbHostingKindSupport.ps1'
$selfFile     = $PSCommandPath

if (-not (Test-Path -LiteralPath $registryFile -PathType Leaf)) {
    throw "ASSERT_FAILED: registro ausente em $registryFile"
}

# ── 1. dot-source real + presenca da API ────────────────────────────────────────
. $registryFile

foreach ($fn in @('Get-GeneXusKbHostingKindSupportRecord',
                  'Get-GeneXusKbHostingKindSupportInvalidValueMessage',
                  'Get-GeneXusKbHostingKindArgumentCompleterScriptBlock',
                  'Register-GeneXusKbHostingKindArgumentCompleter')) {
    if (-not (Get-Command -Name $fn -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "ASSERT_FAILED: funcao publica ausente apos dot-source: $fn"
    }
}

$all = @(Get-GeneXusKbHostingKindSupportRecord)
if ($all.Count -ne 3) {
    throw "ASSERT_FAILED: esperado 3 registros, atual=$($all.Count)"
}

$expectedKinds = @('dotnet-core-self-host', 'dotnet-framework-iis', 'java-tomcat')
foreach ($kind in $expectedKinds) {
    $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $kind
    if ($null -eq $rec) {
        throw "ASSERT_FAILED: registro ausente para kind conhecido '$kind'"
    }
    if ($rec.hostingKind -ne $kind) {
        throw "ASSERT_FAILED: hostingKind divergente para '$kind': $($rec.hostingKind)"
    }
}

if ($null -ne (Get-GeneXusKbHostingKindSupportRecord -HostingKind 'kind-inexistente')) {
    throw "ASSERT_FAILED: kind desconhecido deveria retornar `$null"
}

# ── 2. dispatch por familia ─────────────────────────────────────────────────────
$expectedFamily = @{
    'dotnet-core-self-host' = 'dotnet'
    'dotnet-framework-iis'  = 'dotnet'
    'java-tomcat'           = 'java'
}
foreach ($kind in $expectedFamily.Keys) {
    $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $kind
    if ($rec.family -ne $expectedFamily[$kind]) {
        throw "ASSERT_FAILED: familia divergente para '$kind': esperada=$($expectedFamily[$kind]) atual=$($rec.family)"
    }
}
$familias = @($all | ForEach-Object { $_.family } | Sort-Object -Unique)
if (($familias -join ',') -ne 'dotnet,java') {
    throw "ASSERT_FAILED: conjunto de familias esperado 'dotnet,java', atual='$($familias -join ',')'"
}

# ── 3. Invariantes .NET (motor supported) ───────────────────────────────────────
$core = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'dotnet-core-self-host'
if ($core.freshnessSupportState -ne 'supported' -or -not $core.runsFreshnessEngine) {
    throw "ASSERT_FAILED: dotnet-core-self-host deveria ser supported/roda-motor"
}
if ($core.sentinel -ne 'GxNetCoreStartup.dll') {
    throw "ASSERT_FAILED: sentinel do core divergente: [$($core.sentinel)]"
}
if ($core.freshnessSkipStatus -ne $null) {
    throw "ASSERT_FAILED: core supported nao deveria ter freshnessSkipStatus, atual=[$($core.freshnessSkipStatus)]"
}
if (@($core.tentativeFields).Count -ne 0) {
    throw "ASSERT_FAILED: core nao deveria ter tentativeFields, atual=[$(@($core.tentativeFields) -join ',')]"
}

# Invariante critico do design: framework-iis tem sentinel=$null E e supported.
$fw = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'dotnet-framework-iis'
if ($fw.freshnessSupportState -ne 'supported' -or -not $fw.runsFreshnessEngine) {
    throw "ASSERT_FAILED: dotnet-framework-iis deveria ser supported/roda-motor"
}
if ($null -ne $fw.sentinel) {
    throw "ASSERT_FAILED: framework-iis deveria ter sentinel=`$null (invariante do design), atual=[$($fw.sentinel)]"
}

# ── 4. Contrato de skip + reconhecimento Java ───────────────────────────────────
$java = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'java-tomcat'
if ($java.freshnessSupportState -ne 'recognized-no-engine') {
    throw "ASSERT_FAILED: java-tomcat deveria ser recognized-no-engine, atual=$($java.freshnessSupportState)"
}
if ($java.runsFreshnessEngine) {
    throw "ASSERT_FAILED: java-tomcat NAO deve rodar o motor (runsFreshnessEngine=true)"
}
if ($java.freshnessSkipStatus -ne 'skipped-hosting-unsupported') {
    throw "ASSERT_FAILED: java-tomcat deveria mapear para 'skipped-hosting-unsupported', atual=[$($java.freshnessSkipStatus)]"
}
if ([string]::IsNullOrWhiteSpace($java.unsupportedReason)) {
    throw "ASSERT_FAILED: java-tomcat deveria ter unsupportedReason nao-vazio"
}

# ── 5. tentative-java (campos provisorios exatamente como o design manda) ────────
if ($java.sentinel -ne 'tentative-java') {
    throw "ASSERT_FAILED: java.sentinel deveria ser 'tentative-java', atual=[$($java.sentinel)]"
}
if ($java.outputModelSubPath -ne 'tentative-java') {
    throw "ASSERT_FAILED: java.outputModelSubPath deveria ser 'tentative-java', atual=[$($java.outputModelSubPath)]"
}
# runtimeExclusionPrefixes DEVE ser $null (NAO @()) — "desconhecido", nunca "sem exclusoes".
if ($null -ne $java.runtimeExclusionPrefixes) {
    throw "ASSERT_FAILED: java.runtimeExclusionPrefixes deveria ser `$null (nao @()), atual=[$(@($java.runtimeExclusionPrefixes) -join ',')]"
}
foreach ($f in @('sentinel', 'outputModelSubPath', 'runtimeExclusionPrefixes')) {
    if ($f -notin @($java.tentativeFields)) {
        throw "ASSERT_FAILED: campo '$f' deveria constar em java.tentativeFields=[$(@($java.tentativeFields) -join ',')]"
    }
}

# ── 6. uso da API publica: hashtable interna nao vaza para consumidores ──────────
$internalToken = 'GeneXusKbHostingKindSupportRegistry'
$apiOffenders = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-ChildItem -LiteralPath $scriptDir -Filter '*.ps1' -File) {
    if ($file.FullName -eq $registryFile -or $file.FullName -eq $selfFile) {
        continue
    }
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match [regex]::Escape($internalToken)) {
        $apiOffenders.Add($file.Name)
    }
}
if ($apiOffenders.Count -gt 0) {
    foreach ($name in $apiOffenders) {
        Write-Host "ASSERT_FAILED[api-publica]: $name referencia a hashtable interna '$internalToken' — use Get-GeneXusKbHostingKindSupportRecord."
    }
    throw "ASSERT_FAILED: $($apiOffenders.Count) arquivo(s) tocam a hashtable interna diretamente: $($apiOffenders -join ', ')."
}

# ── 7. ArgumentCompleter fail-soft ──────────────────────────────────────────────
$sb = Get-GeneXusKbHostingKindArgumentCompleterScriptBlock

$normal = @(& $sb $null 'DeploymentHostingKind' '' $null $null | ForEach-Object { $_.CompletionText } | Sort-Object)
if (($normal -join ',') -ne 'dotnet-core-self-host,dotnet-framework-iis,java-tomcat') {
    throw "ASSERT_FAILED: completer normal deveria listar os 3 kinds, atual=[$($normal -join ',')]"
}

$prefixJava = @(& $sb $null 'DeploymentHostingKind' 'java' $null $null | ForEach-Object { $_.CompletionText })
if (($prefixJava -join ',') -ne 'java-tomcat') {
    throw "ASSERT_FAILED: completer prefixo 'java' deveria filtrar para java-tomcat, atual=[$($prefixJava -join ',')]"
}

# Fail-soft: sombrear a API para lancar; o completer deve cair na lista estatica, sem excecao.
function Get-GeneXusKbHostingKindSupportRecord { throw 'drift-selftest: registro indisponivel' }
$failsoft = @(& $sb $null 'DeploymentHostingKind' '' $null $null | ForEach-Object { $_.CompletionText } | Sort-Object)
Remove-Item -Path 'Function:\Get-GeneXusKbHostingKindSupportRecord' -ErrorAction SilentlyContinue
. $registryFile  # restaura a API real para checagens seguintes

# Guarda de drift: a lista estatica de fallback deve espelhar as chaves do registro.
if (($failsoft -join ',') -ne ($normal -join ',')) {
    throw "ASSERT_FAILED: lista fail-soft do completer divergente do registro. viva=[$($normal -join ',')] fallback=[$($failsoft -join ',')]"
}

# ── 8. Contrato de skip: string com fonte unica (nenhum emissor a redigita) ──────
$skipLiteral = 'skipped-hosting-unsupported'
$skipOffenders = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-ChildItem -LiteralPath $scriptDir -Filter '*.ps1' -File) {
    if ($file.FullName -eq $registryFile -or $file.FullName -eq $selfFile) {
        continue
    }
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match [regex]::Escape($skipLiteral)) {
        $skipOffenders.Add($file.Name)
    }
}
if ($skipOffenders.Count -gt 0) {
    foreach ($name in $skipOffenders) {
        Write-Host "ASSERT_FAILED[skip-fonte-unica]: $name redigita o literal '$skipLiteral' — derive de Get-GeneXusKbHostingKindSupportRecord."
    }
    throw "ASSERT_FAILED: $($skipOffenders.Count) arquivo(s) redigitam a string de skip fora do registro (Fase 1 espera zero): $($skipOffenders -join ', ')."
}

# ── 9. Clausula no-bridge: publicationTargets opaco as Fases 1/2 ─────────────────
$bridgeToken = 'publicationTargets'
$bridgeOffenders = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-ChildItem -LiteralPath $scriptDir -Filter '*.ps1' -File) {
    if ($file.FullName -eq $registryFile -or $file.FullName -eq $selfFile) {
        continue
    }
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match [regex]::Escape($bridgeToken)) {
        $bridgeOffenders.Add($file.Name)
    }
}
if ($bridgeOffenders.Count -gt 0) {
    foreach ($name in $bridgeOffenders) {
        Write-Host "ASSERT_FAILED[no-bridge]: $name referencia '$bridgeToken' — a ponte registro<->motor e exclusiva da Fase 3."
    }
    throw "ASSERT_FAILED: $($bridgeOffenders.Count) arquivo(s) violam a clausula no-bridge (Fase 1/2 nao itera publicationTargets): $($bridgeOffenders -join ', ')."
}

'GENEXUS_HOSTING_KIND_DRIFT_SELFTEST_OK'
