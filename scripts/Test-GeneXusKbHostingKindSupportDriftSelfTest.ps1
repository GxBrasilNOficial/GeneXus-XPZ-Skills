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
# Fase 3: o golden .NET (Test-GeneXusDeployBinDotNetGoldenSelfTest.ps1) NAO embute mais o literal de skip
# — o caso java-tomcat virou config-error 'unknown' (Eixo A supported), nao mais skip. Logo o golden NAO
# precisa de exclusao na §8: o guard passa a cobri-lo como qualquer outro arquivo (furo a menos).

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

# ── 3. Invariantes .NET (os TRES eixos com motor supported) ──────────────────────
# Fase 3 (split per-eixo): .NET tem motor nos 3 eixos (A deploy-bin, B fonte .cs, C runtime).
$core = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'dotnet-core-self-host'
foreach ($eixo in @('deployBin', 'runtime', 'source')) {
    $stateField = "${eixo}SupportState"
    $runsField  = "runs$(($eixo.Substring(0,1).ToUpper() + $eixo.Substring(1)))Engine"
    $skipField  = "${eixo}SkipStatus"
    if ($core.$stateField -ne 'supported' -or -not $core.$runsField) {
        throw "ASSERT_FAILED: dotnet-core-self-host Eixo '$eixo' deveria ser supported/roda-motor (state=[$($core.$stateField)] runs=[$($core.$runsField)])"
    }
    if ($null -ne $core.$skipField) {
        throw "ASSERT_FAILED: core supported nao deveria ter $skipField, atual=[$($core.$skipField)]"
    }
}
if ($core.sentinel -ne 'GxNetCoreStartup.dll') {
    throw "ASSERT_FAILED: sentinel do core divergente: [$($core.sentinel)]"
}
if (@($core.tentativeFields).Count -ne 0) {
    throw "ASSERT_FAILED: core nao deveria ter tentativeFields, atual=[$(@($core.tentativeFields) -join ',')]"
}

# Invariante critico do design: framework-iis tem sentinel=$null E os 3 eixos supported.
$fw = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'dotnet-framework-iis'
foreach ($eixo in @('deployBin', 'runtime', 'source')) {
    $stateField = "${eixo}SupportState"
    $runsField  = "runs$(($eixo.Substring(0,1).ToUpper() + $eixo.Substring(1)))Engine"
    if ($fw.$stateField -ne 'supported' -or -not $fw.$runsField) {
        throw "ASSERT_FAILED: dotnet-framework-iis Eixo '$eixo' deveria ser supported/roda-motor (state=[$($fw.$stateField)] runs=[$($fw.$runsField)])"
    }
}
if ($null -ne $fw.sentinel) {
    throw "ASSERT_FAILED: framework-iis deveria ter sentinel=`$null (invariante do design), atual=[$($fw.sentinel)]"
}

# ── 4. Contrato de skip PER-EIXO + reconhecimento Java (Fase 3, Commit 3) ─────────
# Eixo A (deploy-bin) VIRA supported (motor Java = co-gate por familia); Eixos B/C (source/runtime)
# seguem recognized-no-engine (Pos-v1), cada um com sua razao de skip PER-EIXO.
$java = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'java-tomcat'

# Eixo A: supported, roda o motor, SEM skip status/razao.
if ($java.deployBinSupportState -ne 'supported' -or -not $java.runsDeployBinEngine) {
    throw "ASSERT_FAILED: java-tomcat Eixo A (deploy-bin) deveria ser supported/roda-motor (state=[$($java.deployBinSupportState)] runs=[$($java.runsDeployBinEngine)])"
}
if ($null -ne $java.deployBinSkipStatus) {
    throw "ASSERT_FAILED: java-tomcat Eixo A supported nao deveria ter deployBinSkipStatus, atual=[$($java.deployBinSkipStatus)]"
}
if ($null -ne $java.deployBinUnsupportedReason) {
    throw "ASSERT_FAILED: java-tomcat Eixo A supported nao deveria ter deployBinUnsupportedReason, atual=[$($java.deployBinUnsupportedReason)]"
}

# Eixos B (source) e C (runtime): recognized-no-engine, skip claro com razao PER-EIXO.
$javaSkipEixos = @(
    @{ eixo = 'runtime'; runs = 'runsRuntimeEngine'; state = 'runtimeSupportState'; skip = 'runtimeSkipStatus'; reason = 'runtimeUnsupportedReason' }
    @{ eixo = 'source';  runs = 'runsSourceEngine';  state = 'sourceSupportState';  skip = 'sourceSkipStatus';  reason = 'sourceUnsupportedReason' }
)
foreach ($e in $javaSkipEixos) {
    if ($java.($e.state) -ne 'recognized-no-engine') {
        throw "ASSERT_FAILED: java-tomcat Eixo '$($e.eixo)' deveria ser recognized-no-engine, atual=[$($java.($e.state))]"
    }
    if ($java.($e.runs)) {
        throw "ASSERT_FAILED: java-tomcat NAO deve rodar o motor do Eixo '$($e.eixo)' ($($e.runs)=true)"
    }
    if ($java.($e.skip) -ne 'skipped-hosting-unsupported') {
        throw "ASSERT_FAILED: java-tomcat Eixo '$($e.eixo)' deveria mapear para 'skipped-hosting-unsupported', atual=[$($java.($e.skip))]"
    }
    if ([string]::IsNullOrWhiteSpace($java.($e.reason))) {
        throw "ASSERT_FAILED: java-tomcat Eixo '$($e.eixo)' deveria ter razao de skip nao-vazia ($($e.reason))"
    }
    if ($java.($e.reason) -notmatch [regex]::Escape($java.($e.skip))) {
        throw "ASSERT_FAILED: java Eixo '$($e.eixo)': $($e.reason) deveria conter o skip status renderizado ('$($java.($e.skip))'), atual=[$($java.($e.reason))]"
    }
}

# ── 4b. Migracao-compat (Fase 3, A3): aliases legados == campos do Eixo A ─────────
# Os aliases deprecados (freshnessSupportState/freshnessSkipStatus/runsFreshnessEngine/unsupportedReason)
# DEVEM persistir por um ciclo, derivados do Eixo A (deploy-bin), para consumidores externos. Travar a
# derivacao para todos os records: se alguem remover o alias antes do ciclo, ou o desalinhar do Eixo A, falha.
foreach ($rec in $all) {
    if ($rec.freshnessSupportState -ne $rec.deployBinSupportState) {
        throw "ASSERT_FAILED: alias freshnessSupportState de '$($rec.hostingKind)' deveria == deployBinSupportState. alias=[$($rec.freshnessSupportState)] eixoA=[$($rec.deployBinSupportState)]"
    }
    if ($rec.freshnessSkipStatus -ne $rec.deployBinSkipStatus) {
        throw "ASSERT_FAILED: alias freshnessSkipStatus de '$($rec.hostingKind)' deveria == deployBinSkipStatus"
    }
    if ($rec.runsFreshnessEngine -ne $rec.runsDeployBinEngine) {
        throw "ASSERT_FAILED: alias runsFreshnessEngine de '$($rec.hostingKind)' deveria == runsDeployBinEngine"
    }
    if ($rec.unsupportedReason -ne $rec.deployBinUnsupportedReason) {
        throw "ASSERT_FAILED: alias unsupportedReason de '$($rec.hostingKind)' deveria == deployBinUnsupportedReason"
    }
}

# ── 5. Campos Java aterrados (Eixo A) vs provisorios (Eixo B/C) — Fase 3 Commit 3 ─
# Eixo A aterrado: sentinela real (WEB-INF\lib\GeneXus.jar), publicationTargets external-servlet-dir,
# sabores enumerados, deployTargetKind external-webapp (Plano B).
if ($java.sentinel -ne 'WEB-INF\lib\GeneXus.jar') {
    throw "ASSERT_FAILED: java.sentinel deveria ser 'WEB-INF\lib\GeneXus.jar' (aterrado), atual=[$($java.sentinel)]"
}
if ($null -eq $java.publicationTargets -or @($java.publicationTargets).Count -ne 1) {
    throw "ASSERT_FAILED: java.publicationTargets deveria ter 1 alvo aterrado, atual=[$(@($java.publicationTargets).Count)]"
}
if ($java.publicationTargets[0].targetResolution -ne 'external-servlet-dir') {
    throw "ASSERT_FAILED: java.publicationTargets[0].targetResolution deveria ser 'external-servlet-dir', atual=[$($java.publicationTargets[0].targetResolution)]"
}
if (($java.supportedServletFlavors -join ',') -ne 'jakarta,javax') {
    throw "ASSERT_FAILED: java.supportedServletFlavors deveria ser 'jakarta,javax', atual=[$($java.supportedServletFlavors -join ',')]"
}
if ($java.deployTargetKind -ne 'external-webapp') {
    throw "ASSERT_FAILED: java.deployTargetKind deveria ser 'external-webapp' (Plano B), atual=[$($java.deployTargetKind)]"
}

# Eixo B/C provisorios (Pos-v1): outputModelSubPath marcador; extensoes/exclusoes $null (NAO @()).
if ($java.outputModelSubPath -ne 'tentative-java') {
    throw "ASSERT_FAILED: java.outputModelSubPath deveria ser 'tentative-java' (Eixo B/C Pos-v1), atual=[$($java.outputModelSubPath)]"
}
if ($null -ne $java.runtimeExclusionPrefixes) {
    throw "ASSERT_FAILED: java.runtimeExclusionPrefixes deveria ser `$null (Eixo C Pos-v1, nao @()), atual=[$(@($java.runtimeExclusionPrefixes) -join ',')]"
}
# Conjunto EXATO de tentativeFields APOS aterramento do Eixo A (sentinel/publicationTargets saem).
$expectedTentative = @(
    'outputModelSubPath'
    'webDirFreshnessExtensions'
    'runtimeFreshnessExtensions'
    'runtimeExclusionPrefixes'
)
$actualTentative = @($java.tentativeFields | Sort-Object)
$expectedSorted = @($expectedTentative | Sort-Object)
if (($actualTentative -join ',') -ne ($expectedSorted -join ',')) {
    throw "ASSERT_FAILED: java.tentativeFields divergente. esperado=[$($expectedSorted -join ',')] atual=[$($actualTentative -join ',')]"
}
# sentinel/publicationTargets/deployTargetKind aterrados/congelados -> NAO devem constar em tentativeFields.
foreach ($grounded in @('sentinel', 'publicationTargets', 'deployTargetKind')) {
    if ($grounded -in @($java.tentativeFields)) {
        throw "ASSERT_FAILED: '$grounded' foi aterrado/congelado e nao deve estar em java.tentativeFields"
    }
}
# Campos de lista provisorios Java (Eixo B/C) = `$null (NAO @()) -> "desconhecido", nunca "vazio conhecido".
foreach ($listField in @('webDirFreshnessExtensions', 'runtimeFreshnessExtensions', 'runtimeExclusionPrefixes')) {
    if ($null -ne $java.$listField) {
        throw "ASSERT_FAILED: java.$listField deveria ser `$null (Eixo B/C provisorio, nao @()), atual=[$(@($java.$listField) -join ',')]"
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
# O caminho vivo deve refletir EXATAMENTE a API (1 kind sentinela) — trava tambem uma regressao
# que devolvesse o sentinela MAIS algum valor nao-fallback (fusao parcial nao coberta pela negativa).
if ($liveProof.Count -ne 1) {
    throw "ASSERT_FAILED: caminho vivo deve refletir exatamente a API (1 kind), retornou $($liveProof.Count): [$($liveProof -join ',')]"
}
# NENHUM kind do fallback estatico pode aparecer com a API respondendo (aderencia literal ao
# comentario; pega tambem uma hipotetica fusao vivo+fallback, nao so o ramo 'sempre fallback').
# NOTA (sync): esta lista espelha manualmente o fallback estatico embutido no ArgumentCompleter
# (GeneXusKbHostingKindSupport.ps1). A guarda 'failsoft == normal' acima ja trava fallback vs registro;
# este $fallbackKinds e apenas o conjunto proibido no caminho vivo.
$fallbackKinds = @('dotnet-core-self-host', 'dotnet-framework-iis', 'java-tomcat')
$fallbackLeak = @($liveProof | Where-Object { $_ -in $fallbackKinds })
if ($fallbackLeak.Count -gt 0) {
    throw "ASSERT_FAILED: completer devolveu kind(s) do fallback estatico com a API respondendo: [$($fallbackLeak -join ',')]"
}

# ── 8. Contrato de skip: string com fonte unica (nenhum emissor a redigita) ──────
$skipLiteral = 'skipped-hosting-unsupported'
$skipOffenders = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-ChildItem -LiteralPath $scriptDir -Filter '*.ps1' -File) {
    # Exclusao cirurgica: registro (fonte) e este self-test. Cada exclusao e um furo no guard; manter
    # minima. (O golden .NET deixou de embutir o literal na Fase 3 — nao precisa mais ser excluido.)
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

# ── 9. no-bridge INVERTIDA (Fase 3, ix): ALLOWLIST de arquivos-motor + guarda de drift ──
# A ponte registro<->motor (iterar publicationTargets) e LEGITIMA na Fase 3. Inverte-se a denylist: em
# vez de "todo mundo menos registro+self", declara-se a ALLOWLIST dos arquivos-motor que PODEM citar o
# token; todo OUTRO *.ps1 deve ter ZERO ocorrencias (fail-closed — um arquivo de Fase 1/2 novo que cite o
# token vira falso-ofensor no CI, visivel no PR, nunca fail-open). Criterio = ocorrencia TEXTUAL
# (comentario/string contam; o AST fica p/ 999 se algum dia um arquivo de Fase 1/2 precisar citar).
$bridgeToken = 'publicationTargets'
$engineAllowlist = @(
    'GeneXusKbHostingKindSupport.ps1'                     # registro: fonte do contrato (declara publicationTargets)
    'Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1'   # este self-test: cita o token na propria allowlist/asserts
    'Test-GeneXusDeployBinJavaCoGateSelfTest.ps1'         # self-test do co-gate Java: valida o contrato do alvo (iv)
)
$allowSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($n in $engineAllowlist) { [void]$allowSet.Add($n) }

$bridgeOffenders = New-Object System.Collections.Generic.List[string]
$actualCiters = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in Get-ChildItem -LiteralPath $scriptDir -Filter '*.ps1' -File) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match [regex]::Escape($bridgeToken)) {
        [void]$actualCiters.Add($file.Name)
        if (-not $allowSet.Contains($file.Name)) {
            $bridgeOffenders.Add($file.Name)
        }
    }
}
if ($bridgeOffenders.Count -gt 0) {
    foreach ($name in $bridgeOffenders) {
        Write-Host "ASSERT_FAILED[no-bridge]: $name cita '$bridgeToken' e NAO esta na allowlist de arquivos-motor — se for motor legitimo da Fase 3, adicione-o conscientemente; senao remova a referencia."
    }
    throw "ASSERT_FAILED: $($bridgeOffenders.Count) arquivo(s) fora da allowlist citam publicationTargets: $($bridgeOffenders -join ', ')."
}

# Guarda de drift da PROPRIA allowlist (R4): allowlist == arquivos-motor ATIVOS (citers reais). Uma
# entrada obsoleta (arquivo renomeado/removido, ou que deixou de citar o token) fica orfa e deve falhar,
# senao a allowlist "permite" um arquivo inexistente e desatualiza em silencio.
$staleAllow = New-Object System.Collections.Generic.List[string]
foreach ($n in $engineAllowlist) {
    if (-not $actualCiters.Contains($n)) { $staleAllow.Add($n) }
}
if ($staleAllow.Count -gt 0) {
    throw "ASSERT_FAILED: allowlist §9 desatualizada — entrada(s) que nao existe(m) ou nao cita(m) mais '$bridgeToken': $($staleAllow -join ', '). Sincronizar a allowlist com os arquivos-motor ativos."
}

'GENEXUS_HOSTING_KIND_DRIFT_SELFTEST_OK'
