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
# -HostingKind vazio/espaco e lookup singular (parametro informado) -> `$null, NAO a enumeracao.
if ($null -ne (Get-GeneXusKbHostingKindSupportRecord -HostingKind '')) {
    throw "ASSERT_FAILED: -HostingKind '' (vazio) deveria retornar `$null, nao todos os registros"
}
if ($null -ne (Get-GeneXusKbHostingKindSupportRecord -HostingKind '   ')) {
    throw "ASSERT_FAILED: -HostingKind '   ' (espacos) deveria retornar `$null, nao todos os registros"
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
if ($null -ne $core.freshnessSkipStatus) {
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
# Conjunto EXATO de tentativeFields (trava a decisao de quais campos Java sao provisorios;
# um editor futuro nao pode adicionar/remover sem o teste reclamar).
$expectedTentative = @(
    'outputModelSubPath'
    'sentinel'
    'webDirFreshnessExtensions'
    'runtimeFreshnessExtensions'
    'runtimeExclusionPrefixes'
    'publicationTargets'
)
$actualTentative = @($java.tentativeFields | Sort-Object)
$expectedSorted = @($expectedTentative | Sort-Object)
if (($actualTentative -join ',') -ne ($expectedSorted -join ',')) {
    throw "ASSERT_FAILED: java.tentativeFields divergente. esperado=[$($expectedSorted -join ',')] atual=[$($actualTentative -join ',')]"
}
# deployTargetKind e recomendacao v1 CONGELADA (nao empirica) -> NAO deve constar em tentativeFields.
if ('deployTargetKind' -in @($java.tentativeFields)) {
    throw "ASSERT_FAILED: deployTargetKind e decisao v1 congelada, nao deve estar em java.tentativeFields"
}
# Campos de lista provisorios Java = `$null (NAO @()) -> "desconhecido", nunca "vazio conhecido".
foreach ($listField in @('webDirFreshnessExtensions', 'runtimeFreshnessExtensions', 'runtimeExclusionPrefixes', 'publicationTargets')) {
    if ($null -ne $java.$listField) {
        throw "ASSERT_FAILED: java.$listField deveria ser `$null (campo de lista provisorio, nao @()), atual=[$(@($java.$listField) -join ',')]"
    }
}

# ── 5b. Mensagem canonica de valor invalido (fonte-unica das chaves + ramo vazio) ─
# Trava o comportamento (nao so a existencia) de Get-...InvalidValueMessage antes de a
# Fase 2 consumi-la: a mensagem deve enumerar TODAS as chaves do registro (fonte unica) e
# ecoar o valor recebido; o ramo vazio deve render '(vazio)'.
$invalidMsg = Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind 'kind-bogus'
foreach ($kind in $expectedKinds) {
    if ($invalidMsg -notmatch [regex]::Escape($kind)) {
        throw "ASSERT_FAILED: mensagem de valor invalido deveria listar o kind '$kind' (fonte-unica das chaves), atual=[$invalidMsg]"
    }
}
if ($invalidMsg -notmatch [regex]::Escape('kind-bogus')) {
    throw "ASSERT_FAILED: mensagem de valor invalido deveria ecoar o valor recebido, atual=[$invalidMsg]"
}
$emptyValueMsg = Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind ''
if ($emptyValueMsg -notmatch [regex]::Escape('(vazio)')) {
    throw "ASSERT_FAILED: mensagem de valor invalido para vazio deveria conter '(vazio)', atual=[$emptyValueMsg]"
}
# Exatidao (nao so presenca): a lista 'Valores reconhecidos: ...' deve ser EXATAMENTE as chaves
# do registro — um valor extra/stale na mensagem nao pode passar.
if ($invalidMsg -notmatch 'Valores reconhecidos:\s*(.+?)\.\s*$') {
    throw "ASSERT_FAILED: mensagem de valor invalido nao casou o formato 'Valores reconhecidos: <lista>.', atual=[$invalidMsg]"
}
$listedKinds = @($matches[1] -split ',\s*' | ForEach-Object { $_.Trim() } | Sort-Object)
$expectedKindsSorted = @($expectedKinds | Sort-Object)
if (($listedKinds -join '|') -ne ($expectedKindsSorted -join '|')) {
    throw "ASSERT_FAILED: mensagem lista [$($listedKinds -join ', ')] != chaves exatas do registro [$($expectedKindsSorted -join ', ')]"
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
# try/finally garante a restauracao da API real mesmo se o completer lancar (robustez do teste).
$failsoft = $null
try {
    function Get-GeneXusKbHostingKindSupportRecord { throw 'drift-selftest: registro indisponivel' }
    $failsoft = @(& $sb $null 'DeploymentHostingKind' '' $null $null | ForEach-Object { $_.CompletionText } | Sort-Object)
}
finally {
    Remove-Item -Path 'Function:\Get-GeneXusKbHostingKindSupportRecord' -ErrorAction SilentlyContinue
    . $registryFile  # restaura a API real para checagens seguintes
}

# Guarda de drift: a lista estatica de fallback deve espelhar as chaves do registro.
if (($failsoft -join ',') -ne ($normal -join ',')) {
    throw "ASSERT_FAILED: lista fail-soft do completer divergente do registro. viva=[$($normal -join ',')] fallback=[$($failsoft -join ',')]"
}

# Prova de que o caminho VIVO usa a API (nao coincide com o fallback por acaso): sombreia a API
# para retornar um kind SENTINELA (ausente da lista estatica); o completer deve refleti-lo e NAO
# devolver os kinds do fallback. Sem isto, uma regressao que fizesse o completer cair SEMPRE no
# fallback passaria enquanto a lista fixa coincidisse com o registro (Codex hardening).
$liveProof = $null
try {
    function Get-GeneXusKbHostingKindSupportRecord { [pscustomobject]@{ hostingKind = 'sentinel-kind-vivo' } }
    $liveProof = @(& $sb $null 'DeploymentHostingKind' '' $null $null | ForEach-Object { $_.CompletionText })
}
finally {
    Remove-Item -Path 'Function:\Get-GeneXusKbHostingKindSupportRecord' -ErrorAction SilentlyContinue
    . $registryFile  # restaura a API real
}
if ('sentinel-kind-vivo' -notin $liveProof) {
    throw "ASSERT_FAILED: completer nao usou a API no caminho vivo (kind sentinela ausente): [$($liveProof -join ',')]"
}
if ('dotnet-core-self-host' -in $liveProof) {
    throw "ASSERT_FAILED: completer caiu no fallback estatico mesmo com a API respondendo: [$($liveProof -join ',')]"
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
