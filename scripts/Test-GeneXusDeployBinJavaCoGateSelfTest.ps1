#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do co-gate de deploy-bin Java/Tomcat (Eixo A) — Fase 3 (v-bis/v-ter). Ancorado no
    evidence-catalog EBTECH/Jakarta (topologia externa; frescor por conjunto de artefatos; mtime).

.DESCRIPTION
    Prova a propriedade de seguranca central: NUNCA emitir 'fresh' sem publicacao atestada neste build.
    Fixtures por LastWriteTime FORJADO (mesmo metodo dos self-tests .NET). RODAR EM NTFS/ReFS (resolucao
    sub-segundo); em FAT/exFAT a resolucao de 2s mascararia os deltas — o slack de teste usa 20s+ para
    ser robusto, mas os deltas de skew sao de minutos/hora.

    Cobre: validacao de topologia externa; resolucao de com\<kb>; 4 quadrantes (fresh/stale/no-evidence/
    unexpected-publication); stub-only (mudanca de assinatura); skew BIDIRECIONAL (Tomcat-adiantado ->
    .class do futuro excluido de Pf, NUNCA falso-fresh; Tomcat-atrasado -> distinguir "abaixo da janela"
    de "ausente"); Pf\Lf informativo; strip condicional a/b/c/d; servletFlavor per-env not-audited;
    aliasing (arrays Java != .NET); validacao cruzada do contrato publicationTargets.

    Falha => 'ASSERT_FAILED: ...'; sucesso => 'GENEXUS_DEPLOY_BIN_JAVA_COGATE_SELFTEST_OK'.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'GeneXusKbDeployBinSupport.ps1')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function New-FileWithMtime {
    param([string]$Path, [DateTimeOffset]$Mtime)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, 'x', (Get-Utf8NoBomEncoding))
    (Get-Item -LiteralPath $Path).LastWriteTime = $Mtime.LocalDateTime
}

# Constroi um webapp Java externo + fonte local + metadata; devolve os caminhos p/ chamar o co-gate.
function Build-JavaScenario {
    param(
        [string]$Root,
        $JavaFiles,           # array de @{ rel='foo.java'; time=[DateTimeOffset] } sob com\ebtech
        $ClassFiles,          # array de @{ rel='foo.class'; time=[DateTimeOffset] } sob com\ebtech
        [bool]$IncludeServletDirs = $true,
        [bool]$IncludeAppPackage = $true,
        [bool]$IncludeSentinel = $true,
        [string]$ServletFlavor = 'jakarta',
        [string]$ClassesLeaf = 'classes'   # override p/ testar topologia invalida
    )
    $webappRoot = Join-Path $Root 'Tomcat\webapps\App'
    $webInf = Join-Path $webappRoot 'WEB-INF'
    $classesRoot = Join-Path $webInf $ClassesLeaf
    $libDir = Join-Path $webInf 'lib'
    New-Item -ItemType Directory -Path $classesRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    if ($IncludeSentinel) {
        [System.IO.File]::WriteAllText((Join-Path $libDir 'GeneXus.jar'), 'jar', (Get-Utf8NoBomEncoding))
    }

    $webDir = Join-Path $Root 'kb\web'
    $srcRoot = Join-Path $webDir 'src\main\java'
    $pkgSrc = Join-Path $srcRoot 'com\ebtech'
    $pkgClasses = Join-Path $classesRoot 'com\ebtech'
    New-Item -ItemType Directory -Path $pkgSrc -Force | Out-Null
    New-Item -ItemType Directory -Path $pkgClasses -Force | Out-Null
    foreach ($jf in @($JavaFiles)) { New-FileWithMtime -Path (Join-Path $pkgSrc $jf.rel) -Mtime $jf.time }
    foreach ($cf in @($ClassFiles)) { New-FileWithMtime -Path (Join-Path $pkgClasses $cf.rel) -Mtime $cf.time }

    $parallel = Join-Path $Root 'parallel'
    New-Item -ItemType Directory -Path $parallel -Force | Out-Null
    $meta = New-Object System.Collections.Generic.List[string]
    $meta.Add('---')
    $meta.Add('deployment_environment_name: JavaEnv')
    $meta.Add('deployment_hosting_kind: java-tomcat')
    $meta.Add('kb_environment_count: 1')
    $meta.Add('kb_environment_names: JavaEnv')
    $meta.Add("kb_environment_web_dirs: JavaEnv=$webDir")
    if ($IncludeServletDirs) { $meta.Add("kb_environment_servlet_dirs: JavaEnv=$classesRoot") }
    if ($IncludeAppPackage) { $meta.Add('kb_environment_app_package: JavaEnv=com\ebtech') }
    if (-not [string]::IsNullOrWhiteSpace($ServletFlavor)) { $meta.Add("kb_environment_servlet_flavor: JavaEnv=$ServletFlavor") }
    $meta.Add('---')
    $meta.Add('')
    $metaPath = Join-Path $parallel 'kb-source-metadata.md'
    [System.IO.File]::WriteAllText($metaPath, ($meta -join "`n") + "`n", (Get-Utf8NoBomEncoding))

    return [pscustomobject]@{
        metadataPath = $metaPath
        envName      = 'JavaEnv'
        kbPath       = (Join-Path $Root 'kb')
        classesRoot  = $classesRoot
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-java-cogate-selftest-" + [guid]::NewGuid().ToString('N'))
$scenarioNo = 0
function Get-ScenarioRoot {
    param([string]$Root)
    $script:scenarioNo++
    $p = Join-Path $Root ("s{0}" -f $script:scenarioNo)
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

try {
    # Janela temporal forjada. T bem no passado p/ que "futuro" (T+1h) ainda seja passado real (mtimes validos).
    $T = [DateTimeOffset]::Now.AddHours(-3)
    $ended = $T.AddSeconds(30)          # build durou 30s
    $tFresh = $T.AddSeconds(10)         # gerado/publicado durante o build
    $tPub = $T.AddSeconds(20)
    $tOld = $T.AddHours(-1)             # build anterior / nao tocado neste build
    $tFuture = $T.AddHours(1)           # Tomcat-adiantado: mtime "no futuro" frente a janela superior

    function Invoke-Cogate {
        param($Scn, $BuildEnded = $ended)
        return Test-GeneXusKbDeployBinFreshnessCoreJava `
            -KbPath $Scn.kbPath -EnvironmentName $Scn.envName -DeploymentHostingKind 'java-tomcat' `
            -BuildStartedAt $T -MetadataPath $Scn.metadataPath -BuildEndedAt $BuildEnded
    }

    # ── 1. fresh (Lf != 0 e Lf ⊆ Pf) ─────────────────────────────────────────────
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tPub })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'fresh') { throw "ASSERT_FAILED: [1 fresh] status esperado 'fresh', atual=[$($r.status)] ($($r.interpretation))" }

    # ── 2. stale (publicacao parcial: bar gerado sem .class) ──────────────────────
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }, @{ rel = 'bar.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tPub })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'stale') { throw "ASSERT_FAILED: [2 stale] status esperado 'stale', atual=[$($r.status)]" }
    if ($r.interpretation -notmatch 'ausente') { throw "ASSERT_FAILED: [2 stale] interpretacao deveria distinguir '.class ausente', atual=[$($r.interpretation)]" }

    # ── 3. no-evidence (0,0: build sem mudanca) ───────────────────────────────────
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tOld }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tOld })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'no-evidence') { throw "ASSERT_FAILED: [3 no-evidence] esperado 'no-evidence', atual=[$($r.status)]" }

    # ── 4. unexpected-publication (0, !=0: publicado sem geracao local) ───────────
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tOld }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tPub })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'unexpected-publication') { throw "ASSERT_FAILED: [4 unexpected] esperado 'unexpected-publication', atual=[$($r.status)]" }

    # ── 5. stub-only (mudanca de assinatura: so o stub avanca; _impl intacto) ─────
    # foo.java/.class frescos (stub), foo_impl.java/.class antigos. Agrupa em 'foo' (max mtime = fresco).
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }, @{ rel = 'foo_impl.java'; time = $tOld }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tPub }, @{ rel = 'foo_impl.class'; time = $tOld })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'fresh') { throw "ASSERT_FAILED: [5 stub-only] esperado 'fresh' (stub agrupa com _impl), atual=[$($r.status)]" }
    if ($r.binCheck.localObjectsFresh -ne 1) { throw "ASSERT_FAILED: [5 stub-only] deveria haver 1 objeto local fresco (foo), atual=[$($r.binCheck.localObjectsFresh)]" }

    # ── 6. skew Tomcat-ADIANTADO: .class do futuro NAO vira falso-fresh ───────────
    # foo gerado (fresh), mas foo.class publicado por build ANTERIOR com mtime no FUTURO (> janela sup).
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tFuture })
    $r = Invoke-Cogate $s
    if ($r.status -eq 'fresh') { throw "ASSERT_FAILED: [6 skew-adiantado] .class do futuro NAO pode virar 'fresh' (falso-negativo de seguranca!)" }
    if ($r.status -ne 'stale') { throw "ASSERT_FAILED: [6 skew-adiantado] esperado 'stale', atual=[$($r.status)]" }
    if ($r.interpretation -notmatch 'skew') { throw "ASSERT_FAILED: [6 skew-adiantado] deveria sinalizar suspeita de skew, atual=[$($r.interpretation)]" }

    # ── 7. skew Tomcat-ATRASADO: .class abaixo da janela inferior != ausente ──────
    # foo gerado (fresh); foo.class publicado legitimo mas com mtime bem antes do build (relogio atrasado).
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $T.AddMinutes(-10) })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'stale') { throw "ASSERT_FAILED: [7 skew-atrasado] esperado 'stale', atual=[$($r.status)]" }
    if ($r.interpretation -notmatch 'mtime < inicio do build') { throw "ASSERT_FAILED: [7 skew-atrasado] deveria distinguir 'abaixo da janela' de 'ausente', atual=[$($r.interpretation)]" }

    # ── 7b. slack TOLERA atraso pequeno (.class levemente antes do threshold_inf-slack) ──
    # foo.class @ T-3s: dentro do slack (5s) -> incluido em Pf -> fresh (o slack cobre lateness pequena).
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $T.AddSeconds(-3) })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'fresh') { throw "ASSERT_FAILED: [7b slack-tolera] .class dentro do slack deveria ser 'fresh', atual=[$($r.status)]" }

    # ── 8. topologia invalida / config-error -> unknown (fail-safe) ───────────────
    # (a) SERVLET_DIR nao termina em WEB-INF\classes.
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) -JavaFiles @() -ClassFiles @() -ClassesLeaf 'wrongclasses'
    $r = Invoke-Cogate $s
    if ($r.status -ne 'unknown') { throw "ASSERT_FAILED: [8a topologia] leaf!=classes deveria dar 'unknown', atual=[$($r.status)]" }
    # (b) sentinela WEB-INF\lib\GeneXus.jar ausente.
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) -JavaFiles @() -ClassFiles @() -IncludeSentinel $false
    $r = Invoke-Cogate $s
    if ($r.status -ne 'unknown') { throw "ASSERT_FAILED: [8b sentinela] ausente deveria dar 'unknown', atual=[$($r.status)]" }
    # (c) kb_environment_servlet_dirs ausente.
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) -JavaFiles @() -ClassFiles @() -IncludeServletDirs $false
    $r = Invoke-Cogate $s
    if ($r.status -ne 'unknown') { throw "ASSERT_FAILED: [8c servlet_dirs] ausente deveria dar 'unknown', atual=[$($r.status)]" }
    # (d) kb_environment_app_package ausente (nunca varrer com\ inteiro).
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) -JavaFiles @() -ClassFiles @() -IncludeAppPackage $false
    $r = Invoke-Cogate $s
    if ($r.status -ne 'unknown') { throw "ASSERT_FAILED: [8d app_package] ausente deveria dar 'unknown', atual=[$($r.status)]" }

    # ── 9. Pf\Lf informativo (fresh com objeto publicado extra) ───────────────────
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = $tPub }, @{ rel = 'extra.class'; time = $tPub })
    $r = Invoke-Cogate $s
    if ($r.status -ne 'fresh') { throw "ASSERT_FAILED: [9 Pf\Lf] esperado 'fresh', atual=[$($r.status)]" }
    if (-not $r.diagnosticLayer.Contains('publishedWithoutLocalGeneration')) {
        throw "ASSERT_FAILED: [9 Pf\Lf] deveria reportar objetos publicados sem geracao local (informativo)"
    }

    # ── 10. strip condicional a/b/c/d (unidade: Get-...ObjectMtimeMap) ────────────
    $stripRoot = Get-ScenarioRoot $tempRoot
    $pkg = Join-Path $stripRoot 'com\ebtech'
    # (a) foo + foo_impl + foo__default no mesmo subpacote -> agrupa em 'foo' (1 objeto).
    New-FileWithMtime -Path (Join-Path $pkg 'grpa\foo.class') -Mtime $tPub
    New-FileWithMtime -Path (Join-Path $pkg 'grpa\foo_impl.class') -Mtime $tPub
    New-FileWithMtime -Path (Join-Path $pkg 'grpa\foo__default.class') -Mtime $tPub
    # (b) bar_impl SEM bar -> objeto proprio 'bar_impl'.
    New-FileWithMtime -Path (Join-Path $pkg 'grpb\bar_impl.class') -Mtime $tPub
    # (c) homonimos em subpacotes distintos -> nao fundidos.
    New-FileWithMtime -Path (Join-Path $pkg 'x\baz.class') -Mtime $tPub
    New-FileWithMtime -Path (Join-Path $pkg 'y\baz.class') -Mtime $tPub
    # (d) sufixo FORA do conjunto fechado -> objeto proprio.
    New-FileWithMtime -Path (Join-Path $pkg 'grpd\qux_novo.class') -Mtime $tPub
    New-FileWithMtime -Path (Join-Path $pkg 'grpd\qux.class') -Mtime $tPub

    $map = Get-GeneXusKbDeployBinJavaObjectMtimeMap -Root $stripRoot -AppPackageSubPath 'com\ebtech' -Extension '.class'
    $keys = @($map.Keys)
    if (-not ($keys -contains 'grpa|foo')) { throw "ASSERT_FAILED: [10a] deveria agrupar em 'grpa|foo', chaves=[$($keys -join ', ')]" }
    if (@($keys | Where-Object { $_ -like 'grpa|*' }).Count -ne 1) { throw "ASSERT_FAILED: [10a] grpa deveria ter 1 objeto (foo), atual=[$(@($keys | Where-Object { $_ -like 'grpa|*' }) -join ', ')]" }
    if (-not ($keys -contains 'grpb|bar_impl')) { throw "ASSERT_FAILED: [10b] bar_impl sem stub deveria ser objeto proprio, chaves=[$($keys -join ', ')]" }
    if (-not (($keys -contains 'x|baz') -and ($keys -contains 'y|baz'))) { throw "ASSERT_FAILED: [10c] homonimos x/y|baz nao deveriam fundir, chaves=[$($keys -join ', ')]" }
    if (-not ($keys -contains 'grpd|qux_novo')) { throw "ASSERT_FAILED: [10d] sufixo desconhecido _novo deveria virar objeto proprio 'qux_novo', chaves=[$($keys -join ', ')]" }

    # ── 11. servletFlavor per-env (jakarta e javax) + audit not-audited ───────────
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) -ClassFiles @(@{ rel = 'foo.class'; time = $tPub }) -ServletFlavor 'jakarta'
    $r = Invoke-Cogate $s
    if ($r.paths.servletFlavor -ne 'jakarta') { throw "ASSERT_FAILED: [11 flavor] esperado 'jakarta', atual=[$($r.paths.servletFlavor)]" }
    if ($r.paths.servletFlavorAudit -ne 'not-audited') { throw "ASSERT_FAILED: [11 flavor] audit deveria ser 'not-audited' (fail-closed), atual=[$($r.paths.servletFlavorAudit)]" }
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) -ClassFiles @(@{ rel = 'foo.class'; time = $tPub }) -ServletFlavor 'javax'
    $r = Invoke-Cogate $s
    if ($r.paths.servletFlavor -ne 'javax') { throw "ASSERT_FAILED: [11 flavor] esperado 'javax', atual=[$($r.paths.servletFlavor)]" }

    # ── 12. aliasing (x): arrays Java != .NET (referencias distintas) ─────────────
    $javaRec = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'java-tomcat'
    $dotnetRec = Get-GeneXusKbHostingKindSupportRecord -HostingKind 'dotnet-core-self-host'
    if ([object]::ReferenceEquals($javaRec.publicationTargets, $dotnetRec.publicationTargets)) {
        throw "ASSERT_FAILED: [12 aliasing] publicationTargets Java NAO deve ser a mesma referencia dos .NET"
    }

    # ── 13. validacao cruzada do contrato publicationTargets (iv) ─────────────────
    $jt = $javaRec.publicationTargets[0]
    if ($jt.targetResolution -ne 'external-servlet-dir') { throw "ASSERT_FAILED: [13] java targetResolution deveria ser 'external-servlet-dir'" }
    if ($null -ne $jt.subPath) { throw "ASSERT_FAILED: [13] java subPath deveria ser `$null (external), atual=[$($jt.subPath)]" }
    foreach ($req in @('externalTargetKey', 'appPackageKey', 'sentinelRelativeToWebappRoot')) {
        if ([string]::IsNullOrWhiteSpace($jt.$req)) { throw "ASSERT_FAILED: [13] java $req obrigatorio (external), atual=[$($jt.$req)]" }
    }
    $dt = $dotnetRec.publicationTargets[0]
    if ($dt.subPath -ne 'bin') { throw "ASSERT_FAILED: [13] dotnet subPath deveria ser 'bin' (env-subpath), atual=[$($dt.subPath)]" }

    # ── 14. Ramo Now (PRODUCAO): BuildEndedAt=$null exercita o else{[DateTimeOffset]::Now} ───────
    # A fachada publica NAO cabeia BuildEndedAt, entao a producao SEMPRE roda este ramo. Os cenarios
    # 1-13 acima passam -BuildEndedAt explicito (ramo nao-producao). Este fecha o gap de cobertura.
    #
    # 14.1 — safety-lock: .class no FUTURO real (Now+1h) NAO pode virar 'fresh' com Now (falso-fresh).
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'foo.java'; time = $tFresh }) `
        -ClassFiles @(@{ rel = 'foo.class'; time = [DateTimeOffset]::Now.AddHours(1) })
    $rNow = Invoke-Cogate $s -BuildEnded $null
    if ($rNow.status -eq 'fresh') { throw "ASSERT_FAILED: [14.1 Now-safety] .class do futuro NAO pode virar 'fresh' com ancora Now (falso-fresh de seguranca!)" }
    if ($rNow.status -ne 'stale') { throw "ASSERT_FAILED: [14.1 Now-safety] esperado 'stale' (.class acima da janela), atual=[$($rNow.status)]" }

    # 14.2 — sanity de thresholdSupAt no ramo Now: existe, >= thresholdAt, e ~ Now (nao uma ancora fixa do passado).
    $tSup = [DateTimeOffset]::Parse($rNow.thresholdSupAt)
    $tInf = [DateTimeOffset]::Parse($rNow.thresholdAt)
    if ($tSup -lt $tInf) { throw "ASSERT_FAILED: [14.2 Now-sanity] thresholdSupAt < thresholdAt (janela invertida): sup=[$($tSup.ToString('o'))] inf=[$($tInf.ToString('o'))]" }
    $ageSup = ([DateTimeOffset]::Now - $tSup).TotalSeconds
    if ($ageSup -lt -60 -or $ageSup -gt 60) { throw "ASSERT_FAILED: [14.2 Now-sanity] thresholdSupAt a $([math]::Round($ageSup,1))s de Now (fora de [-60,60]s -> ramo Now nao foi tomado?)" }

    # 14.3 — caminho feliz do ramo Now: .class recente (Now-3s), build recente -> 'fresh'.
    $nowRef = [DateTimeOffset]::Now
    $s = Build-JavaScenario -Root (Get-ScenarioRoot $tempRoot) `
        -JavaFiles @(@{ rel = 'bar.java'; time = $nowRef.AddSeconds(-5) }) `
        -ClassFiles @(@{ rel = 'bar.class'; time = $nowRef.AddSeconds(-3) })
    $rNowFresh = Test-GeneXusKbDeployBinFreshnessCoreJava `
        -KbPath $s.kbPath -EnvironmentName $s.envName -DeploymentHostingKind 'java-tomcat' `
        -BuildStartedAt ($nowRef.AddMinutes(-1)) -MetadataPath $s.metadataPath -BuildEndedAt $null
    if ($rNowFresh.status -ne 'fresh') { throw "ASSERT_FAILED: [14.3 Now-fresh] .class recente deveria ser 'fresh' via ancora Now, atual=[$($rNowFresh.status)] ($($rNowFresh.interpretation))" }

    'GENEXUS_DEPLOY_BIN_JAVA_COGATE_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
