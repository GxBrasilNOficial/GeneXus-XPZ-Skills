#requires -Version 7.4
<#
.SYNOPSIS
    Checagem pos-build de frescor da publicacao do environment de deploy (Ponto 2), por familia
    de deployment_hosting_kind (.NET e Java/Tomcat).

.DESCRIPTION
    Le deployment_hosting_kind e kb_environment_web_dirs (e, para Java, kb_environment_servlet_dirs/
    _app_package) do metadata. Test-GeneXusKbDeployBinFreshnessCore e DISPATCHER por familia (Fase 3):
      .NET (...CoreDotNet): gate por publicacao em web\bin — object *.dll (exceto runtime GeneXus/
        System/Microsoft) ou *.config; dotnet-core-self-host: GxNetCoreStartup.dll só complementar
        (warning se velho).
      Java/Tomcat (...CoreJava): co-gate por CONJUNTO DE ARTEFATOS do objeto (max mtime dos <obj>*.java
        locais vs <obj>*.class no WEB-INF\classes EXTERNO do Tomcat), janela de skew bidirecional;
        4 quadrantes (fresh/stale/no-evidence/unexpected-publication) + unknown (config-error).
        Ancora superior operativa = Now; Fase 5 confirmou que o marco util e fim da copia/publicacao
        Gradle (copyTomcat*), nao fim de compileJava.

    Propriedade de seguranca: nunca 'fresh' sem publicacao atestada neste build (todo caminho de
    incerteza falha conservativo). Severidade hibrida (decisoes fechadas): status novo quando stale;
    exit 49 só com gate. Recognized-no-engine (Eixos B/C Java) roteia para skip.
#>

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'GeneXusKbDeploymentEnvironmentSupport.ps1')
# Fase 2 (paridade Java/Tomcat): fonte-unica dos hosting kinds. Acesso so via a API publica
# Get-GeneXusKbHostingKindSupportRecord / Get-GeneXusKbHostingKindSupportInvalidValueMessage.
. (Join-Path $PSScriptRoot 'GeneXusKbHostingKindSupport.ps1')

$script:GeneXusKbDeployBinGateExitCode = 49
$script:GeneXusKbDeployBinStaleStatus = 'compilou-mas-dll-destino-desatualizada'

function Get-GeneXusKbDeployBinTimeSlack {
    return [TimeSpan]::FromSeconds(5)
}

# ── Fase 3 (co-gate Java/Tomcat) — constantes ────────────────────────────────────
# Conjunto FECHADO de sufixos-artefato (amostra EBTECH; evidence-catalog). Um objeto GeneXus gera
# <obj> (stub) + <obj>_impl (logica) + auxiliares (__default/__gam). O co-gate agrupa por OBJETO
# (max mtime sobre todos os artefatos). Sufixo FORA deste conjunto -> tratado como objeto proprio
# (fail-safe: gate mais estrito, nunca funde reduzindo Pf). Ampliar exige novo aterramento
# empirico, NAO inferencia aberta. Ordem irrelevante (terminacoes distintas; so uma casa por base).
$script:GeneXusKbDeployBinJavaArtifactSuffixes = @('__default', '__gam', '_impl')
# Sub-caminho do fonte .java LOCAL sob o web dir do env (Gradle): web\src\main\java.
$script:GeneXusKbDeployBinJavaSourceSubPath = 'src\main\java'
# Sentinela Java: presenca (nao frescor) de WEB-INF\lib\GeneXus.jar (irmao de WEB-INF\classes).
$script:GeneXusKbDeployBinJavaSentinelRelPath = 'WEB-INF\lib\GeneXus.jar'

function Get-GeneXusKbDeployBinHostingKindFromMetadata {
    param([string]$MetadataPath)

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        return $null
    }

    $lines = [System.IO.File]::ReadAllLines($MetadataPath)
    return Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'deployment_hosting_kind'
    )
}

function Resolve-GeneXusKbDeployBinCheckPolicy {
    param(
        [switch]$PostImportDeployValidation,
        [switch]$SkipDeployBinCheck,
        [switch]$StrictDeployBinCheck,
        [string]$MetadataPath,
        [string]$DeploymentHostingKind,
        [string]$ValidationEnvironmentName,
        [bool]$BuildOperationallySucceeded
    )

    $policy = [ordered]@{
        shouldRun          = $false
        gateEnabled        = $false
        mode               = 'skipped'
        skipReason         = $null
        deploymentHostingKind = $DeploymentHostingKind
        # Fase 2: campos do skip por familia (recognized-no-engine / blocked-out-of-scope).
        # Inicializados $null na BASE (nao so no ramo Java) para que a leitura a jusante em
        # Invoke-...Classification nao lance sob StrictMode nos skips nao-Java (SkipDeployBinCheck etc.).
        hostingSkipStatus  = $null
        unsupportedReason  = $null
    }

    if ($SkipDeployBinCheck.IsPresent) {
        $policy.skipReason = 'SkipDeployBinCheck informado.'
        return [pscustomobject]$policy
    }

    if (-not $BuildOperationallySucceeded) {
        $policy.skipReason = 'Build nao concluiu com sucesso operacional (MSBuild exit != 0 ou marcador de conclusao ausente); checagem de deploy bin nao se aplica.'
        return [pscustomobject]$policy
    }

    if ([string]::IsNullOrWhiteSpace($ValidationEnvironmentName)) {
        $policy.skipReason = 'Environment de validacao/deploy nao resolvido.'
        return [pscustomobject]$policy
    }

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        $policy.skipReason = 'kb-source-metadata.md ausente para deployment_hosting_kind.'
        return [pscustomobject]$policy
    }

    $hostingKind = $DeploymentHostingKind
    if ([string]::IsNullOrWhiteSpace($hostingKind)) {
        $hostingKind = Get-GeneXusKbDeployBinHostingKindFromMetadata -MetadataPath $MetadataPath
        $policy.deploymentHostingKind = $hostingKind
    }

    if ([string]::IsNullOrWhiteSpace($hostingKind)) {
        $policy.skipReason = 'deployment_hosting_kind ausente no metadata (gravar via xpz-kb-parallel-setup).'
        return [pscustomobject]$policy
    }

    # Fase 3 (split per-eixo): validacao por registro (fonte-unica), nao por lista .NET-only redigitada.
    # Este e o Eixo A (deploy-bin) — discrimina pelo campo DO SEU EIXO ($rec.runsDeployBinEngine), nao pelo
    # alias legado runsFreshnessEngine. Cobre qualquer estado nao-supported (recognized-no-engine e um futuro
    # blocked-out-of-scope) sem enumerar nomes de estado nem criar ramo morto.
    $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $hostingKind
    if ($null -eq $rec) {
        # Presente e fora do registro: invalido genuino (fail-closed = rejeicao, nao skip).
        $policy.skipReason = Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind $hostingKind
        return [pscustomobject]$policy
    }

    if (-not $rec.runsDeployBinEngine) {
        # recognized-no-engine / blocked-out-of-scope no Eixo A: skip congelado. A string de status e a
        # razao sao DERIVADAS do registro (campos do Eixo A; nunca redigitadas); o exit 0 + status e
        # materializado a jusante em Invoke-GeneXusKbDeployBinPostBuildClassification.
        $policy.hostingSkipStatus = $rec.deployBinSkipStatus
        $policy.unsupportedReason = $rec.deployBinUnsupportedReason
        $policy.skipReason = $rec.deployBinUnsupportedReason
        return [pscustomobject]$policy
    }

    # deployBinSupportState=supported: roda o motor de deploy-bin (dispatcher por familia na Fase 3).
    $policy.shouldRun = $true
    $policy.gateEnabled = ($StrictDeployBinCheck.IsPresent -or $PostImportDeployValidation.IsPresent)
    $policy.mode = if ($policy.gateEnabled) { 'gate' } else { 'diagnostic' }
    return [pscustomobject]$policy
}

function Get-GeneXusKbDirectoryMaxWriteTime {
    param(
        [string]$RootPath,
        [string[]]$IncludeExtensions,
        [string[]]$ExcludeDirectoryNames = @('bin')
    )

    if ([string]::IsNullOrWhiteSpace($RootPath) -or -not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }

    $excludeSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $ExcludeDirectoryNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$excludeSet.Add($name.Trim('\', '/'))
        }
    }

    $maxWrite = $null
    $rootFull = [System.IO.Path]::GetFullPath($RootPath)

    foreach ($file in Get-ChildItem -LiteralPath $rootFull -Recurse -File -ErrorAction SilentlyContinue) {
        $relative = $file.FullName.Substring($rootFull.Length).TrimStart('\', '/')
        $segments = @($relative -split '[\\/]')
        $skip = $false
        foreach ($segment in $segments) {
            if ($excludeSet.Contains($segment)) {
                $skip = $true
                break
            }
        }
        if ($skip) {
            continue
        }

        if ($IncludeExtensions -and $IncludeExtensions.Count -gt 0) {
            $matched = $false
            foreach ($ext in $IncludeExtensions) {
                if ($file.Name.EndsWith($ext, [StringComparison]::OrdinalIgnoreCase)) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) {
                continue
            }
        }

        $candidate = [DateTimeOffset]::new($file.LastWriteTime)
        if ($null -eq $maxWrite -or $candidate -gt $maxWrite) {
            $maxWrite = $candidate
        }
    }

    return $maxWrite
}

function Test-GeneXusKbDeployBinRuntimeDllExcluded {
    param([string]$FileName)

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return $true
    }

    if ($FileName -ieq 'GxNetCoreStartup.dll') {
        return $true
    }

    if ($FileName.StartsWith('GeneXus.', [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($FileName.StartsWith('System.', [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($FileName.StartsWith('Microsoft.', [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $false
}

function Get-GeneXusKbDeployBinPublicationEvidence {
    param(
        [string]$BinPath,
        [DateTimeOffset]$Threshold
    )

    $evidence = [ordered]@{
        binDirectoryFound          = $false
        objectDllCount           = 0
        objectDllMaxWriteTime      = $null
        newestObjectDllName        = $null
        objectDllFreshSinceBuild   = $false
        configMaxWriteTime         = $null
        newestConfigName           = $null
        configFreshSinceBuild      = $false
        publicationFreshSinceBuild = $false
    }

    if ([string]::IsNullOrWhiteSpace($BinPath) -or -not (Test-Path -LiteralPath $BinPath -PathType Container)) {
        return [pscustomobject]$evidence
    }

    $evidence.binDirectoryFound = $true

    $objectDllFiles = @(Get-ChildItem -LiteralPath $BinPath -Filter '*.dll' -File -ErrorAction SilentlyContinue | Where-Object {
            -not (Test-GeneXusKbDeployBinRuntimeDllExcluded -FileName $_.Name)
        })
    $evidence.objectDllCount = $objectDllFiles.Count

    $objectMaxWrite = $null
    $newestObjectDll = $null
    foreach ($dll in $objectDllFiles) {
        $candidate = [DateTimeOffset]::new($dll.LastWriteTime)
        if ($null -eq $objectMaxWrite -or $candidate -gt $objectMaxWrite) {
            $objectMaxWrite = $candidate
            $newestObjectDll = $dll.Name
        }
    }

    if ($null -ne $objectMaxWrite) {
        $evidence.objectDllMaxWriteTime = $objectMaxWrite.ToString('o')
        $evidence.newestObjectDllName = $newestObjectDll
        $evidence.objectDllFreshSinceBuild = ($objectMaxWrite -ge $Threshold)
    }

    $configFiles = @(Get-ChildItem -LiteralPath $BinPath -Filter '*.config' -File -ErrorAction SilentlyContinue)
    $configMaxWrite = $null
    $newestConfig = $null
    foreach ($configFile in $configFiles) {
        $candidate = [DateTimeOffset]::new($configFile.LastWriteTime)
        if ($null -eq $configMaxWrite -or $candidate -gt $configMaxWrite) {
            $configMaxWrite = $candidate
            $newestConfig = $configFile.Name
        }
    }

    if ($null -ne $configMaxWrite) {
        $evidence.configMaxWriteTime = $configMaxWrite.ToString('o')
        $evidence.newestConfigName = $newestConfig
        $evidence.configFreshSinceBuild = ($configMaxWrite -ge $Threshold)
    }

    $evidence.publicationFreshSinceBuild = ($evidence.objectDllFreshSinceBuild -or $evidence.configFreshSinceBuild)
    return [pscustomobject]$evidence
}

function Add-GeneXusKbDeployBinPublicationFieldsToBinCheck {
    param(
        [System.Collections.IDictionary]$BinCheck,
        [pscustomobject]$Publication
    )

    $BinCheck['rule'] = 'publication-object-dll-or-config'
    $BinCheck['binDirectoryFound'] = $Publication.binDirectoryFound
    $BinCheck['objectDllCount'] = $Publication.objectDllCount
    $BinCheck['objectDllMaxWriteTime'] = $Publication.objectDllMaxWriteTime
    $BinCheck['newestObjectDllName'] = $Publication.newestObjectDllName
    $BinCheck['objectDllFreshSinceBuild'] = $Publication.objectDllFreshSinceBuild
    $BinCheck['configMaxWriteTime'] = $Publication.configMaxWriteTime
    $BinCheck['newestConfigName'] = $Publication.newestConfigName
    $BinCheck['configFreshSinceBuild'] = $Publication.configFreshSinceBuild
    $BinCheck['publicationFreshSinceBuild'] = $Publication.publicationFreshSinceBuild
    $BinCheck['binFreshSinceBuild'] = $Publication.publicationFreshSinceBuild
}

function Get-GeneXusKbDeployBinPaths {
    # Fase 3 (ii) — aridade escalar -> LISTA de alvos de deploy. v1: 1 alvo por KB (decisao (e)).
    # Este resolvedor e do alvo .NET in-kb-web (web\bin); o alvo Java external-webapp tem resolvedor
    # proprio no Commit 3 (design iii: ...CoreJava nao reusa este). Consumidor unico: ...CoreDotNet.
    param(
        [string]$KbPath,
        [string]$EnvironmentName,
        [string]$MetadataPath
    )

    $pathStatus = 'blocked'
    $pathReason = 'kb-source-metadata.md ausente para resolver kb_environment_web_dirs; nao inferir diretorio pelo nome do environment.'
    $pathSource = 'kb-source-metadata.kb_environment_web_dirs'
    $envWebPath = $null

    if (-not [string]::IsNullOrWhiteSpace($MetadataPath) -and (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $MetadataPath
        if ($fields.kb_environment_web_dirs.Count -eq 0) {
            $pathStatus = 'blocked'
            $pathReason = 'kb_environment_web_dirs ausente em kb-source-metadata.md; nao inferir diretorio pelo nome do environment.'
        } elseif (-not $fields.kb_environment_web_dirs.Contains($EnvironmentName)) {
            $pathStatus = 'blocked'
            $pathReason = ("kb_environment_web_dirs nao contem mapeamento para environment '{0}'." -f $EnvironmentName)
        } elseif ([string]::IsNullOrWhiteSpace($fields.kb_environment_web_dirs[$EnvironmentName])) {
            $pathStatus = 'blocked'
            $pathReason = ("kb_environment_web_dirs contem caminho vazio para environment '{0}'." -f $EnvironmentName)
        } else {
            $envWebPath = $fields.kb_environment_web_dirs[$EnvironmentName]
            $pathStatus = 'resolved'
            $pathReason = $null
            $pathSource = 'kb-source-metadata.kb_environment_web_dirs'
        }
    }

    $envBinPath = if ($null -ne $envWebPath) { Join-Path $envWebPath 'bin' } else { $null }

    # Lista de 1 alvo (in-kb-web). Tags family/targetKind explicitas; campos .NET preservados para o
    # consumidor ...CoreDotNet montar a saida `paths` identica (golden byte-a-byte).
    return @(
        [pscustomobject][ordered]@{
            family               = 'dotnet'
            targetKind           = 'in-kb-web'
            environmentWebPath   = $envWebPath
            environmentBinPath   = $envBinPath
            sentinelPath         = if ($null -ne $envBinPath) { Join-Path $envBinPath 'GxNetCoreStartup.dll' } else { $null }
            pathResolutionStatus = $pathStatus
            pathResolutionSource = $pathSource
            pathResolutionReason = $pathReason
        }
    )
}

function Test-GeneXusKbDeployBinFreshnessCore {
    # Fase 3 (iii) — DISPATCHER por familia. Extraido o corpo .NET para ...CoreDotNet (comportamento
    # preservado, ancora de regressao) e adicionado ...CoreJava (co-gate; stub no Commit 2, real no
    # Commit 3). Roteia por $rec.family; kind ausente/invalido nao chega aqui (rejeitado a montante pela
    # policy/fachada). Default conservador = .NET.
    param(
        [string]$KbPath,
        [string]$EnvironmentName,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [string]$MetadataPath,
        $BuildEndedAt = $null   # DateTimeOffset opcional; so o co-gate Java usa (ancora superior do skew)
    )

    $rec = $null
    if (-not [string]::IsNullOrWhiteSpace($DeploymentHostingKind)) {
        $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $DeploymentHostingKind
    }
    $family = if ($null -ne $rec) { $rec.family } else { 'dotnet' }

    if ($family -eq 'java') {
        return Test-GeneXusKbDeployBinFreshnessCoreJava `
            -KbPath $KbPath -EnvironmentName $EnvironmentName -DeploymentHostingKind $DeploymentHostingKind `
            -BuildStartedAt $BuildStartedAt -MetadataPath $MetadataPath -BuildEndedAt $BuildEndedAt
    }

    return Test-GeneXusKbDeployBinFreshnessCoreDotNet `
        -KbPath $KbPath -EnvironmentName $EnvironmentName -DeploymentHostingKind $DeploymentHostingKind `
        -BuildStartedAt $BuildStartedAt -MetadataPath $MetadataPath
}

function Get-GeneXusKbDeployBinJavaTarget {
    # Fase 3 (ii-bis) — resolve o alvo Java externo por metadata + VALIDA a topologia. Fail-closed:
    # qualquer falha -> pathResolutionStatus != 'resolved' -> co-gate devolve 'unknown' (nunca 'fresh').
    param(
        [string]$EnvironmentName,
        [string]$MetadataPath
    )

    $target = [ordered]@{
        classesRoot          = $null   # WEB-INF\classes externo (raiz de evidencia de Pf)
        webappRoot           = $null   # pai de WEB-INF
        localSourceRoot      = $null   # <web>\src\main\java (raiz de Lf)
        appPackage           = $null   # com\<kb> (de kb_environment_app_package)
        servletFlavor        = $null   # jakarta|javax (informativo)
        servletFlavorAudit   = 'not-audited'  # fail-closed: so o env aferido (EBTECH/jakarta) seria 'certified'
        sentinelPath         = $null   # WEB-INF\lib\GeneXus.jar
        pathResolutionStatus = 'blocked'
        pathResolutionSource = 'kb-source-metadata.kb_environment_servlet_dirs'
        pathResolutionReason = $null
    }

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        $target.pathResolutionReason = 'kb-source-metadata.md ausente para resolver kb_environment_servlet_dirs (alvo Java externo).'
        return [pscustomobject]$target
    }

    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $MetadataPath

    if ($fields.kb_environment_servlet_dirs.Count -eq 0 -or -not $fields.kb_environment_servlet_dirs.Contains($EnvironmentName) -or
        [string]::IsNullOrWhiteSpace($fields.kb_environment_servlet_dirs[$EnvironmentName])) {
        $target.pathResolutionReason = ("kb_environment_servlet_dirs ausente/vazio para environment '{0}' (resolver/validar alvo Java via xpz-kb-parallel-setup; nao copiar SERVLET_DIR sem confrontar environment, gradle.properties e sentinelas)." -f $EnvironmentName)
        return [pscustomobject]$target
    }
    $classesRoot = $fields.kb_environment_servlet_dirs[$EnvironmentName]

    if ($fields.kb_environment_app_package.Count -eq 0 -or -not $fields.kb_environment_app_package.Contains($EnvironmentName) -or
        [string]::IsNullOrWhiteSpace($fields.kb_environment_app_package[$EnvironmentName])) {
        $target.pathResolutionReason = ("kb_environment_app_package ausente/vazio para environment '{0}' (pacote da app, ex.: com\\<kb>; nao varrer com\\ inteiro)." -f $EnvironmentName)
        return [pscustomobject]$target
    }
    $target.appPackage = $fields.kb_environment_app_package[$EnvironmentName].Trim().TrimStart('\', '/').TrimEnd('\', '/')

    if ($fields.kb_environment_servlet_flavor.Count -gt 0 -and $fields.kb_environment_servlet_flavor.Contains($EnvironmentName)) {
        $flavorRaw = $fields.kb_environment_servlet_flavor[$EnvironmentName]
        if (-not [string]::IsNullOrWhiteSpace($flavorRaw)) {
            $target.servletFlavor = $flavorRaw.Trim().ToLowerInvariant()
        }
    }

    # ── Validacao de topologia (ii-bis) ──────────────────────────────────────────
    # (a) termina em WEB-INF\classes (nao build\classes local).
    $classesNorm = $classesRoot.TrimEnd('\', '/')
    $leaf = Split-Path -Leaf $classesNorm
    $parentDir = Split-Path -Parent $classesNorm
    $parentLeaf = if ($parentDir) { Split-Path -Leaf $parentDir } else { '' }
    if (($leaf -ine 'classes') -or ($parentLeaf -ine 'WEB-INF')) {
        $target.pathResolutionReason = ("kb_environment_servlet_dirs para '{0}' nao termina em WEB-INF\\classes (topologia Java externa invalida): '{1}'." -f $EnvironmentName, $classesRoot)
        return [pscustomobject]$target
    }
    # (c) raiz existe/e diretorio.
    if (-not (Test-Path -LiteralPath $classesNorm -PathType Container)) {
        $target.pathResolutionReason = ("kb_environment_servlet_dirs para '{0}' nao existe ou nao e diretorio: '{1}'." -f $EnvironmentName, $classesRoot)
        return [pscustomobject]$target
    }
    # (d) raiz do webapp = pai de WEB-INF.
    $webappRoot = Split-Path -Parent $parentDir
    # (b) sentinela irma WEB-INF\lib\GeneXus.jar existe (presenca, nao frescor).
    $sentinelPath = Join-Path $webappRoot $script:GeneXusKbDeployBinJavaSentinelRelPath
    if (-not (Test-Path -LiteralPath $sentinelPath -PathType Leaf)) {
        $target.pathResolutionReason = ("Sentinela {0} ausente sob a raiz do webapp '{1}' — nao parece um webapp GeneXus Java." -f $script:GeneXusKbDeployBinJavaSentinelRelPath, $webappRoot)
        return [pscustomobject]$target
    }

    # localSourceRoot = <web>\src\main\java, derivado de kb_environment_web_dirs (fonte .java local, Lf).
    if ($fields.kb_environment_web_dirs.Count -gt 0 -and $fields.kb_environment_web_dirs.Contains($EnvironmentName) -and
        -not [string]::IsNullOrWhiteSpace($fields.kb_environment_web_dirs[$EnvironmentName])) {
        $target.localSourceRoot = Join-Path $fields.kb_environment_web_dirs[$EnvironmentName] $script:GeneXusKbDeployBinJavaSourceSubPath
    }
    # Ausencia de localSourceRoot NAO e config-error do alvo: apenas leva Lf=vazio (o co-gate trata como
    # no-evidence/unexpected-publication conforme Pf) — direcao conservativa.

    $target.classesRoot = $classesNorm
    $target.webappRoot = $webappRoot
    $target.sentinelPath = $sentinelPath
    $target.pathResolutionStatus = 'resolved'
    return [pscustomobject]$target
}

function Get-GeneXusKbDeployBinJavaObjectMtimeMap {
    # Fase 3 (v-bis) — agrupa artefatos por OBJETO sob <Root>\<AppPackageSubPath>, com STRIP CONDICIONAL
    # dos sufixos conhecidos (so stripa se o stub-base existe no MESMO subpacote). Chave = caminho relativo
    # do subpacote + nome-base do objeto (evita colisao de homonimos em subpacotes distintos). Valor = max
    # mtime ([DateTimeOffset]) sobre todos os artefatos do objeto. Sufixo desconhecido -> objeto proprio.
    param(
        [string]$Root,               # ex.: WEB-INF\classes (externo) | <web>\src\main\java (local)
        [string]$AppPackageSubPath,  # ex.: com\ebtech
        [string]$Extension           # '.class' | '.java'
    )

    $map = @{}
    if ([string]::IsNullOrWhiteSpace($Root) -or [string]::IsNullOrWhiteSpace($AppPackageSubPath)) {
        return $map
    }
    $pkgRoot = Join-Path $Root $AppPackageSubPath
    if (-not (Test-Path -LiteralPath $pkgRoot -PathType Container)) {
        return $map
    }
    $pkgRootFull = [System.IO.Path]::GetFullPath($pkgRoot)

    $files = @(Get-ChildItem -LiteralPath $pkgRootFull -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.EndsWith($Extension, [System.StringComparison]::OrdinalIgnoreCase) })

    # Bases por subpacote (para o strip condicional: so stripa se o stub-base existe no mesmo subpacote).
    $basesBySubpkg = @{}
    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($pkgRootFull.Length).TrimStart('\', '/')
        $subpkg = [System.IO.Path]::GetDirectoryName($rel)
        if ($null -eq $subpkg) { $subpkg = '' }
        $base = $f.Name.Substring(0, $f.Name.Length - $Extension.Length)
        if (-not $basesBySubpkg.ContainsKey($subpkg)) {
            $basesBySubpkg[$subpkg] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }
        [void]$basesBySubpkg[$subpkg].Add($base)
        $entries.Add([pscustomobject]@{ subpkg = $subpkg; base = $base; mtime = [DateTimeOffset]::new($f.LastWriteTime) })
    }

    foreach ($e in $entries) {
        $objBase = $e.base
        foreach ($suffix in $script:GeneXusKbDeployBinJavaArtifactSuffixes) {
            if (($e.base.Length -gt $suffix.Length) -and
                $e.base.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $candidate = $e.base.Substring(0, $e.base.Length - $suffix.Length)
                if ($basesBySubpkg[$e.subpkg].Contains($candidate)) {
                    $objBase = $candidate
                }
                break
            }
        }
        $key = "$($e.subpkg)|$objBase"
        if ((-not $map.ContainsKey($key)) -or ($e.mtime -gt $map[$key])) {
            $map[$key] = $e.mtime
        }
    }
    return $map
}

function Test-GeneXusKbDeployBinFreshnessCoreJava {
    # Fase 3 (v-bis/v-ter) — co-gate de deploy-bin Java/Tomcat (Eixo A) por CONJUNTO DE ARTEFATOS do
    # objeto, com janela de skew BIDIRECIONAL. Propriedade de seguranca central: NUNCA emitir 'fresh'
    # sem publicacao atestada neste build; todo caminho de incerteza falha conservativo.
    #   Lf = objetos com max(mtime .java local) >= threshold_inf   (fonte local, mesmo relogio da KB)
    #   Pf = objetos com threshold_inf <= max(mtime .class externo) <= threshold_sup  (externo, skew)
    #   Lf!=0 & Lf⊆Pf -> fresh | Lf!=0 & Lf⊄Pf -> stale | 0,0 -> no-evidence | 0,!=0 -> unexpected-publication
    param(
        [string]$KbPath,
        [string]$EnvironmentName,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [string]$MetadataPath,
        $BuildEndedAt = $null   # DateTimeOffset opcional (ancora superior preferida = fim da publicacao)
    )

    $rec = $null
    if (-not [string]::IsNullOrWhiteSpace($DeploymentHostingKind)) {
        $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $DeploymentHostingKind
    }
    $slackSeconds = 5
    if ($null -ne $rec -and $null -ne $rec.deployBinTimeSlackSeconds) {
        $slackSeconds = [int]$rec.deployBinTimeSlackSeconds
    }
    $slack = [TimeSpan]::FromSeconds($slackSeconds)

    $thresholdInf = $BuildStartedAt.Subtract($slack)
    # Ancora superior (v-ter): preferida-por-design = fim da publicacao/copia (Fase 5 confirmou
    # copyTomcat* como marco util; BuildEndedAt = fallback explicito). NOTA (Fase 3): a fachada publica Invoke-...PostBuildClassification
    # NAO cabeia BuildEndedAt, entao na PRODUCAO a ancora e SEMPRE Now (BuildEndedAt so e exercitado por
    # self-test). Ancora tarde demais (Now) so alarga a janela superior -> pode gerar falso-stale, NUNCA
    # falso-fresh; a exclusao do .class do futuro (skew) permanece. Limite operacional: com topologia
    # externa, Now (relogio KB) e os mtimes dos .class (relogio do servidor de deploy) podem divergir por
    # skew de NTP -> falso-stale sistemico; so um marco real de fim de copia/publicacao elimina.
    $upperAnchor = if ($null -ne $BuildEndedAt -and $BuildEndedAt -is [System.DateTimeOffset]) { $BuildEndedAt } else { [System.DateTimeOffset]::Now }
    $thresholdSup = $upperAnchor.Add($slack)

    $target = Get-GeneXusKbDeployBinJavaTarget -EnvironmentName $EnvironmentName -MetadataPath $MetadataPath

    $result = [ordered]@{
        status                    = 'unknown'
        deploymentHostingKind     = $DeploymentHostingKind
        validationEnvironmentName = $EnvironmentName
        buildStartedAt            = $BuildStartedAt.ToString('o')
        thresholdAt               = $thresholdInf.ToString('o')
        thresholdSupAt            = $thresholdSup.ToString('o')
        paths                     = [ordered]@{
            classesRoot          = $target.classesRoot
            webappRoot           = $target.webappRoot
            localSourceRoot      = $target.localSourceRoot
            appPackage           = $target.appPackage
            servletFlavor        = $target.servletFlavor
            servletFlavorAudit   = $target.servletFlavorAudit
            sentinelPath         = $target.sentinelPath
            pathResolutionStatus = $target.pathResolutionStatus
            pathResolutionSource = $target.pathResolutionSource
            pathResolutionReason = $target.pathResolutionReason
        }
        binCheck                  = [ordered]@{}
        diagnosticLayer           = [ordered]@{}
        interpretation            = $null
    }

    if ($target.pathResolutionStatus -ne 'resolved') {
        $result.status = 'unknown'
        $result.interpretation = $target.pathResolutionReason
        return [pscustomobject]$result
    }

    # Lf (fonte .java local; so limiar inferior — mesmo relogio) e Pf (.class externo; janela bidirecional).
    $lfMap = Get-GeneXusKbDeployBinJavaObjectMtimeMap -Root $target.localSourceRoot -AppPackageSubPath $target.appPackage -Extension '.java'
    $pfMap = Get-GeneXusKbDeployBinJavaObjectMtimeMap -Root $target.classesRoot -AppPackageSubPath $target.appPackage -Extension '.class'

    $lf = New-Object System.Collections.Generic.List[string]
    foreach ($k in $lfMap.Keys) {
        if ($lfMap[$k] -ge $thresholdInf) { $lf.Add($k) }
    }
    $pfSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($k in $pfMap.Keys) {
        if (($pfMap[$k] -ge $thresholdInf) -and ($pfMap[$k] -le $thresholdSup)) { [void]$pfSet.Add($k) }
    }
    $lfSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($k in $lf) { [void]$lfSet.Add($k) }

    # .class publicados FORA da janela superior (suspeita de skew Tomcat-adiantado): diagnostico.
    $aboveWindow = New-Object System.Collections.Generic.List[string]
    foreach ($k in $pfMap.Keys) {
        if ($pfMap[$k] -gt $thresholdSup) { $aboveWindow.Add($k) }
    }

    $result.binCheck = [ordered]@{
        rule               = 'java-cogate-object-artifact-mtime'
        localObjectsFresh  = $lf.Count
        publishedObjectsFresh = $pfSet.Count
        publishedAboveUpperWindow = $aboveWindow.Count
    }

    $capDump = {
        param($items)
        $arr = @($items)
        if ($arr.Count -le 20) { return ($arr -join '; ') }
        return (($arr[0..19] -join '; ') + (' … e mais {0}' -f ($arr.Count - 20)))
    }

    if ($lf.Count -gt 0) {
        $missing = New-Object System.Collections.Generic.List[string]
        foreach ($obj in $lf) {
            if (-not $pfSet.Contains($obj)) { $missing.Add($obj) }
        }
        if ($missing.Count -eq 0) {
            $result.status = 'fresh'
            $result.interpretation = ("Publicacao Java atestada: todos os {0} objetos gerados neste build tem .class fresco no WEB-INF\\classes." -f $lf.Count)
            # Pf \ Lf (informativo, NAO bloqueia): possivel recompilacao transitiva do Gradle.
            $extra = New-Object System.Collections.Generic.List[string]
            foreach ($obj in $pfSet) {
                if (-not $lfSet.Contains($obj)) { $extra.Add($obj) }
            }
            if ($extra.Count -gt 0) {
                $result.diagnosticLayer['publishedWithoutLocalGeneration'] = (& $capDump $extra)
                $result.diagnosticLayer['publishedWithoutLocalGenerationNote'] = 'Objetos publicados-frescos sem geracao local correspondente (possivel recompilacao transitiva do Gradle; informativo, nao bloqueia).'
            }
        }
        else {
            $result.status = 'stale'
            # Distinguir "ausente" de "presente mas fora da janela superior" (suspeita de skew).
            $detail = New-Object System.Collections.Generic.List[string]
            foreach ($obj in $missing) {
                if ($pfMap.ContainsKey($obj)) {
                    if ($pfMap[$obj] -gt $thresholdSup) {
                        $detail.Add("$obj (.class presente mas mtime > janela superior — suspeita de skew Tomcat-adiantado)")
                    }
                    else {
                        $detail.Add("$obj (.class presente mas mtime < inicio do build — nao publicado neste build)")
                    }
                }
                else {
                    $detail.Add("$obj (.class ausente no WEB-INF\\classes)")
                }
            }
            $result.interpretation = ("Publicacao Java PARCIAL: {0} de {1} objetos gerados sem .class fresco publicado. Faltantes: {2}" -f $missing.Count, $lf.Count, (& $capDump $detail))
        }
    }
    else {
        if ($pfSet.Count -eq 0) {
            $result.status = 'no-evidence'
            $result.interpretation = 'Nenhum objeto gerado localmente neste build e nenhuma publicacao fresca (build sem mudanca; nada a verificar).'
            # Mascaramento sob skew (R6): ha .class externo acima da janela? Sinalizar suspeita (nao muda status).
            if ($aboveWindow.Count -gt 0) {
                $result.diagnosticLayer['skewSuspectAboveWindow'] = (& $capDump $aboveWindow)
                $result.diagnosticLayer['skewSuspectNote'] = 'Ha .class no WEB-INF\classes com mtime > janela superior (possivel skew Tomcat-adiantado); conferir deployBinTimeSlackSeconds/relogios.'
            }
        }
        else {
            $result.status = 'unexpected-publication'
            $result.interpretation = ('Publicacao sem geracao local atestavel: {0} objeto(s) com .class fresco no WEB-INF\classes, mas NENHUM objeto gerado neste build. Pode ser normal apos Rebuild All/clean-build; o gate falha por origem nao atestavel. Rode geracao antes do deploy, ou marque como diagnostico.' -f $pfSet.Count)
        }
    }

    return [pscustomobject]$result
}

function Test-GeneXusKbDeployBinFreshnessCoreDotNet {
    param(
        [string]$KbPath,
        [string]$EnvironmentName,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [string]$MetadataPath
    )

    $targets = Get-GeneXusKbDeployBinPaths -KbPath $KbPath -EnvironmentName $EnvironmentName -MetadataPath $MetadataPath
    $paths = $targets[0]  # v1: 1 alvo por KB (in-kb-web)
    $slack = Get-GeneXusKbDeployBinTimeSlack
    $threshold = $BuildStartedAt.Subtract($slack)

    $result = [ordered]@{
        status                     = 'unknown'
        deploymentHostingKind      = $DeploymentHostingKind
        validationEnvironmentName  = $EnvironmentName
        buildStartedAt             = $BuildStartedAt.ToString('o')
        thresholdAt                = $threshold.ToString('o')
        paths                      = [ordered]@{
            environmentWebPath = $paths.environmentWebPath
            environmentBinPath = $paths.environmentBinPath
            pathResolutionStatus = $paths.pathResolutionStatus
            pathResolutionSource = $paths.pathResolutionSource
            pathResolutionReason = $paths.pathResolutionReason
        }
        binCheck                   = [ordered]@{}
        diagnosticLayer            = [ordered]@{}
        interpretation             = $null
    }

    if ($paths.pathResolutionStatus -ne 'resolved') {
        $result.status = 'unknown'
        $result.interpretation = $paths.pathResolutionReason
        return [pscustomobject]$result
    }

    $envWebMax = Get-GeneXusKbDirectoryMaxWriteTime -RootPath $paths.environmentWebPath -IncludeExtensions @('.cs', '.js', '.aspx', '.dll') -ExcludeDirectoryNames @('bin')
    $envWebFresh = ($null -ne $envWebMax) -and ($envWebMax -ge $threshold)

    $result.diagnosticLayer = [ordered]@{
        environmentWebMaxWriteTime = if ($null -ne $envWebMax) { $envWebMax.ToString('o') } else { $null }
        environmentWebFreshSinceBuild = $envWebFresh
    }

    $binPath = $paths.environmentBinPath
    $publication = Get-GeneXusKbDeployBinPublicationEvidence -BinPath $binPath -Threshold $threshold
    Add-GeneXusKbDeployBinPublicationFieldsToBinCheck -BinCheck $result.binCheck -Publication $publication

    if (-not $publication.binDirectoryFound) {
        $result.status = 'unknown'
        $result.interpretation = 'Pasta web\bin ausente no environment de deploy.'
        return [pscustomobject]$result
    }

    if (($publication.objectDllCount -eq 0) -and ($null -eq $publication.configMaxWriteTime)) {
        $result.status = 'unknown'
        $result.interpretation = 'Nenhuma DLL de objeto nem config encontrada em web\bin para avaliar publicacao.'
        return [pscustomobject]$result
    }

    if ($DeploymentHostingKind -eq 'dotnet-core-self-host') {
        $sentinelPath = $paths.sentinelPath
        $result.binCheck['sentinelPath'] = $sentinelPath

        if (-not (Test-Path -LiteralPath $sentinelPath -PathType Leaf)) {
            $result.status = 'unknown'
            $result.binCheck['sentinelFound'] = $false
            $result.interpretation = 'GxNetCoreStartup.dll ausente em web\bin — environment Core possivelmente nao inicializado.'
            return [pscustomobject]$result
        }

        $sentinelFile = Get-Item -LiteralPath $sentinelPath
        $sentinelWrite = [DateTimeOffset]::new($sentinelFile.LastWriteTime)
        $sentinelFresh = ($sentinelWrite -ge $threshold)

        $result.binCheck['sentinelFound'] = $true
        $result.binCheck['sentinelLastWriteTime'] = $sentinelWrite.ToString('o')
        $result.binCheck['sentinelFreshSinceBuild'] = $sentinelFresh
    }

    if ($publication.publicationFreshSinceBuild) {
        $result.status = 'fresh'
        $result.interpretation = 'Publicacao em web\bin confirmada (DLL de objeto ou config com timestamp >= inicio do build).'
        if ($DeploymentHostingKind -eq 'dotnet-core-self-host' -and
            $result.binCheck['sentinelFound'] -and
            -not $result.binCheck['sentinelFreshSinceBuild']) {
            $result.interpretation = '{0} GxNetCoreStartup.dll nao regravado neste build incremental (esperado para runtime GeneXus).' -f $result.interpretation
        }
    }
    elseif ($envWebFresh) {
        $result.status = 'stale'
        $result.interpretation = 'Artefatos em <Env>\web\ atualizados, mas nenhuma DLL de objeto nem config em web\bin reflete o build — suspeita de falha de publicacao/copia para bin.'
    }
    else {
        $result.status = 'stale'
        $result.interpretation = 'web\bin e <Env>\web\ sem evidencia de publicacao apos o build — build pode nao ter recompilado/publicado o necessario neste environment.'
    }

    return [pscustomobject]$result
}

function Invoke-GeneXusKbDeployBinPostBuildClassification {
    param(
        [string]$KbPath,
        [string]$ValidationEnvironmentName,
        [string]$MetadataPath,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [bool]$BuildOperationallySucceeded,
        [switch]$PostImportDeployValidation,
        [switch]$SkipDeployBinCheck,
        [switch]$StrictDeployBinCheck,
        [string]$OperationLabel = 'Build'
    )

    $policy = Resolve-GeneXusKbDeployBinCheckPolicy `
        -PostImportDeployValidation:$PostImportDeployValidation `
        -SkipDeployBinCheck:$SkipDeployBinCheck `
        -StrictDeployBinCheck:$StrictDeployBinCheck `
        -MetadataPath $MetadataPath `
        -DeploymentHostingKind $DeploymentHostingKind `
        -ValidationEnvironmentName $ValidationEnvironmentName `
        -BuildOperationallySucceeded $BuildOperationallySucceeded

    $output = [ordered]@{
        deployBinFreshness = 'skipped'
        deployBinCheck     = [ordered]@{
            mode          = $policy.mode
            gateEnabled   = $policy.gateEnabled
            shouldRun     = $policy.shouldRun
            skipReason    = $policy.skipReason
            hostingKind   = $policy.deploymentHostingKind
        }
        statusReclassified = $false
        newStatus          = $null
        newSummary         = $null
        newExitCode        = $null
        warnings           = @()
        blockingReasons    = @()
    }

    if (-not $policy.shouldRun) {
        if ($policy.skipReason) {
            $output.deployBinCheck.skipReason = $policy.skipReason
        }
        # Eixo A recognized-no-engine / blocked-out-of-scope: skip de deploy-bin POR EIXO, nao por kind
        # (pos-Fase 3 nenhum kind reconhecido cai aqui — java-tomcat Eixo A e 'supported' e roda o co-gate).
        # Materializa o contrato de skip DERIVANDO a string do registro (via $policy). exit 0 sem gate:
        # nao reclassifica, nao seta newExitCode (o ramo ja retorna cedo). Demais skips mantem 'skipped'.
        if ($policy.hostingSkipStatus) {
            $output.deployBinFreshness = $policy.hostingSkipStatus
            $output.deployBinCheck.hostingSkipStatus = $policy.hostingSkipStatus
            $output.deployBinCheck.unsupportedReason = $policy.unsupportedReason
        }
        return [pscustomobject]$output
    }

    $freshness = Test-GeneXusKbDeployBinFreshnessCore `
        -KbPath $KbPath `
        -EnvironmentName $ValidationEnvironmentName `
        -DeploymentHostingKind $policy.deploymentHostingKind `
        -BuildStartedAt $BuildStartedAt `
        -MetadataPath $MetadataPath

    $output.deployBinFreshness = $freshness.status
    $output.deployBinCheck = [ordered]@{
        mode                      = $policy.mode
        gateEnabled               = $policy.gateEnabled
        shouldRun                 = $true
        hostingKind               = $policy.deploymentHostingKind
        validationEnvironmentName = $ValidationEnvironmentName
        buildStartedAt            = $freshness.buildStartedAt
        thresholdAt               = $freshness.thresholdAt
        paths                     = $freshness.paths
        binCheck                  = $freshness.binCheck
        diagnosticLayer           = $freshness.diagnosticLayer
        interpretation            = $freshness.interpretation
    }

    # Observabilidade (Fase 3): expor a ancora superior efetiva (thresholdSupAt) quando o core a
    # materializa (co-gate Java). Guard StrictMode-safe OBRIGATORIO: o CoreDotNet NAO produz
    # thresholdSupAt (janela so-inferior), e ler $freshness.thresholdSupAt do caminho .NET lancaria
    # "property does not exist" sob Set-StrictMode -Version Latest. $freshness.PSObject.Properties[...]
    # nao lanca (devolve $null se ausente). A ancora superior OPERATIVA na fachada ainda e
    # [DateTimeOffset]::Now (nao cabeia BuildEndedAt nem marco real de fim de copia/publicacao); o
    # valor e volatil e sensivel a skew de relogio KB-vs-servidor de deploy externo (ver 02/CHANGELOG).
    if ($freshness.PSObject.Properties['thresholdSupAt']) {
        $output.deployBinCheck.thresholdSupAt = $freshness.thresholdSupAt
    }

    if ($freshness.status -eq 'fresh') {
        if ($freshness.binCheck.Contains('sentinelFreshSinceBuild') -and
            $freshness.binCheck['sentinelFound'] -eq $true -and
            $freshness.binCheck['sentinelFreshSinceBuild'] -eq $false) {
            $output.warnings = @(
                'GxNetCoreStartup.dll nao foi regravado neste build incremental (esperado); publicacao em web\bin confirmada por DLL de objeto ou config.'
            )
        }
        return [pscustomobject]$output
    }

    if ($freshness.status -eq 'unknown') {
        $output.warnings = @(
            ("Checagem deploy bin inconclusiva ({0}): {1}" -f $OperationLabel, $freshness.interpretation)
        )
        if ($policy.gateEnabled) {
            $output.statusReclassified = $true
            $output.newStatus = $script:GeneXusKbDeployBinStaleStatus
            $output.newSummary = ("{0} concluiu sem erro de MSBuild, mas a checagem de publicacao do environment de deploy foi inconclusiva ({1}). Nao declarar validacao deploy OK." -f $OperationLabel, $freshness.interpretation)
            $output.newExitCode = $script:GeneXusKbDeployBinGateExitCode
            $output.blockingReasons = @(
                'deploy-bin-cheque-inconclusivo: deployment_hosting_kind ou artefatos de publicacao (web\bin no .NET, WEB-INF\classes no Java) ausentes/ilegiveis.'
            )
        }
        return [pscustomobject]$output
    }

    if ($freshness.status -eq 'no-evidence') {
        # Fase 3 (co-gate Java): build sem mudanca -> nada a publicar. NAO falha o gate (nada a
        # verificar); warning informativo, exitCode MSBuild preservado. Simetrico ao skip benigno.
        $output.warnings = @(
            ("Checagem deploy bin ({0}): {1}" -f $OperationLabel, $freshness.interpretation)
        )
        return [pscustomobject]$output
    }

    # stale, unexpected-publication (Java) e demais nao-fresh/nao-unknown/nao-no-evidence: falha (gate).
    $output.statusReclassified = $true
    $output.newStatus = $script:GeneXusKbDeployBinStaleStatus
    $output.newSummary = ("{0} concluiu sem erro de MSBuild, mas a publicacao do environment de deploy ({1}) nao reflete o build. {2}" -f $OperationLabel, $ValidationEnvironmentName, $freshness.interpretation)
    $output.warnings = @($freshness.interpretation)

    if ($policy.gateEnabled) {
        $output.newExitCode = $script:GeneXusKbDeployBinGateExitCode
        $output.blockingReasons = @(
            ("deploy-bin-desatualizado: sem evidencia de publicacao no destino do environment '{0}' apos o build (hosting={1}; web\bin no .NET, WEB-INF\classes no Java)." -f $ValidationEnvironmentName, $policy.deploymentHostingKind)
        )
    }
    else {
        $output.newExitCode = 0
        $output.warnings = @(
            $freshness.interpretation
            'Modo diagnostico: exitCode MSBuild preservado; nao declarar validacao deploy OK.'
        )
    }

    return [pscustomobject]$output
}
