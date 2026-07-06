#requires -Version 7.4
<#
.SYNOPSIS
    Checagem pos-build de frescor de web\bin do environment de deploy (Ponto 2).

.DESCRIPTION
    Le deployment_hosting_kind e kb_environment_web_dirs do metadata; gate por publicacao em web\bin:
      object *.dll (exceto runtime GeneXus/System/Microsoft) ou *.config
      dotnet-core-self-host: GxNetCoreStartup.dll só complementar (warning se velho)

    Severidade hibrida (decisoes fechadas): status novo quando stale; exit 49 só com gate.
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
        [string]$MetadataPath
    )

    $rec = $null
    if (-not [string]::IsNullOrWhiteSpace($DeploymentHostingKind)) {
        $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $DeploymentHostingKind
    }
    $family = if ($null -ne $rec) { $rec.family } else { 'dotnet' }

    if ($family -eq 'java') {
        return Test-GeneXusKbDeployBinFreshnessCoreJava `
            -KbPath $KbPath -EnvironmentName $EnvironmentName -DeploymentHostingKind $DeploymentHostingKind `
            -BuildStartedAt $BuildStartedAt -MetadataPath $MetadataPath
    }

    return Test-GeneXusKbDeployBinFreshnessCoreDotNet `
        -KbPath $KbPath -EnvironmentName $EnvironmentName -DeploymentHostingKind $DeploymentHostingKind `
        -BuildStartedAt $BuildStartedAt -MetadataPath $MetadataPath
}

function Test-GeneXusKbDeployBinFreshnessCoreJava {
    # Fase 3, Commit 2: STUB fail-safe. O co-gate Java real (4 quadrantes por conjunto de artefatos,
    # skew bidirecional, validacao de topologia externa, resolucao de com\<kb>) entra no Commit 3, junto
    # com a virada de deployBinSupportState -> supported. Ate la o motor Java e INALCANCAVEL (java-tomcat
    # = recognized-no-engine no Eixo A -> policy/fachada pulam antes daqui). Este stub apenas garante a
    # propriedade de seguranca central (NUNCA emitir 'fresh' sem publicacao atestada) caso algum caminho
    # inesperado o alcance: retorna 'unknown' (config-error, fail-safe).
    param(
        [string]$KbPath,
        [string]$EnvironmentName,
        [string]$DeploymentHostingKind,
        [DateTimeOffset]$BuildStartedAt,
        [string]$MetadataPath
    )

    $slack = Get-GeneXusKbDeployBinTimeSlack
    $threshold = $BuildStartedAt.Subtract($slack)

    return [pscustomobject][ordered]@{
        status                    = 'unknown'
        deploymentHostingKind     = $DeploymentHostingKind
        validationEnvironmentName = $EnvironmentName
        buildStartedAt            = $BuildStartedAt.ToString('o')
        thresholdAt               = $threshold.ToString('o')
        paths                     = [ordered]@{
            environmentWebPath   = $null
            environmentBinPath   = $null
            pathResolutionStatus = 'blocked'
            pathResolutionSource = 'java-cogate-nao-implementado'
            pathResolutionReason = 'Motor de deploy-bin Java (co-gate) sera implementado no Commit 3 da Fase 3.'
        }
        binCheck                  = [ordered]@{}
        diagnosticLayer           = [ordered]@{}
        interpretation            = 'Motor Java de deploy-bin nao implementado (Commit 2 stub); fail-safe unknown.'
    }
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
        # Fase 2: hosting kind reconhecido-sem-motor (recognized-no-engine / blocked-out-of-scope) →
        # materializa o contrato de skip DERIVANDO a string do registro (via $policy). exit 0 sem gate:
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
            $output.newSummary = ("{0} concluiu sem erro de MSBuild, mas a checagem de web\bin do environment de deploy foi inconclusiva ({1}). Nao declarar validacao deploy OK." -f $OperationLabel, $freshness.interpretation)
            $output.newExitCode = $script:GeneXusKbDeployBinGateExitCode
            $output.blockingReasons = @(
                'deploy-bin-cheque-inconclusivo: deployment_hosting_kind ou artefatos em web\bin ausentes/ilegiveis.'
            )
        }
        return [pscustomobject]$output
    }

    $output.statusReclassified = $true
    $output.newStatus = $script:GeneXusKbDeployBinStaleStatus
    $output.newSummary = ("{0} concluiu sem erro de MSBuild, mas web\bin do environment de deploy ({1}) nao reflete o build. {2}" -f $OperationLabel, $ValidationEnvironmentName, $freshness.interpretation)
    $output.warnings = @($freshness.interpretation)

    if ($policy.gateEnabled) {
        $output.newExitCode = $script:GeneXusKbDeployBinGateExitCode
        $output.blockingReasons = @(
            ("deploy-bin-desatualizado: sem evidencia de publicacao em web\bin do environment '{0}' apos o build (hosting={1})." -f $ValidationEnvironmentName, $policy.deploymentHostingKind)
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
