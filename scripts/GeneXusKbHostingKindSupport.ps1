#requires -Version 7.4
<#
.SYNOPSIS
    Registro-fonte unico dos hosting kinds de deploy reconhecidos pelas skills XPZ.

.DESCRIPTION
    Fase 1 da paridade de gerador Java/Tomcat (design congelado em
    java-tomcat-paridade-gerador-design.md). Materializa o contrato do registro: uma
    entrada por deployment_hosting_kind, com os campos que governam o gate de deploy-bin
    (Eixo A), o diagnostico de runtime (Eixo C) e o roteamento por familia.

    Acesso EXCLUSIVO via a API publica Get-GeneXusKbHostingKindSupportRecord. Nenhum
    consumidor le a hashtable interna ($script:GeneXusKbHostingKindSupportRegistry)
    diretamente; o self-test de drift (Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1)
    trava essa invariante por varredura estatica.

    Clausula no-bridge (invariante do congelamento): o campo publicationTargets[] e a
    forma-alvo da Fase 3 e e OPACO as Fases 1/2. Nenhum codigo de Fase 1/2 itera
    publicationTargets para acionar o motor de deploy-bin; a ponte registro<->motor e
    exclusiva da Fase 3. O motor (Get-GeneXusKbDeployBinPaths /
    Test-GeneXusKbDeployBinFreshnessCore) permanece ESCALAR na Fase 1 (a mudanca de
    aridade escalar->lista e da Fase 3). O self-test trava a clausula como checagem
    estatica trivial.

    Java/Tomcat entra como freshnessSupportState='recognized-no-engine': reconhecido pelo
    registro, sem motor de verificacao (skip congelado). Campos cujo valor Java e empirico
    (criterio de aceite da Fase 0) carregam o marcador 'tentative-java' (campos string) ou
    permanecem $null (campos de lista, NAO @()) e estao listados em tentativeFields; a Fase 3
    os preenche a partir do evidence-catalog-java-tomcat e remove o marcador.

    Dot-sourcing este arquivo NAO tem efeito colateral alem de definir as funcoes e montar
    o $script: table. O ArgumentCompleter e opt-in via Register-GeneXusKbHostingKindArgumentCompleter.
#>

Set-StrictMode -Version Latest

# ── Constantes de contrato ──────────────────────────────────────────────────────

# Marcador de valor provisorio: campos cujo valor definitivo Java e empirico (Fase 0/3).
$script:GeneXusKbHostingKindTentativeJavaMarker = 'tentative-java'

# Contrato de saida do skip (design): exit 0 + status='skipped-hosting-unsupported' + unsupportedReason.
# Fonte unica desta string; os emissores nomeados do skip (Fase 2: Resolve-GeneXusKbDeployBinCheckPolicy
# em GeneXusKbDeployBinSupport.ps1, a fachada Test-GeneXusDeployBinFreshness.ps1, as guardas de familia
# dos Eixos C/B) devem derivar dela, nunca redigitar o literal.
$script:GeneXusKbHostingKindSkipStatus = 'skipped-hosting-unsupported'

# Mapa fonte-unica freshnessSupportState -> status de skip ($null quando o motor roda).
# recognized-no-engine e blocked-out-of-scope compartilham a MESMA string de skip; a
# desambiguacao e por freshnessSupportState/unsupportedReason, nao pela string (Fase 4 doc).
$script:GeneXusKbHostingKindFreshnessSkipStatusByState = [ordered]@{
    'supported'            = $null
    'recognized-no-engine' = $script:GeneXusKbHostingKindSkipStatus
    'blocked-out-of-scope' = $script:GeneXusKbHostingKindSkipStatus
}

# ── Construtor interno do registro (NAO faz parte da API publica) ────────────────

function New-GeneXusKbHostingKindSupportRecord {
    param(
        [string]$HostingKind,
        [string]$Family,
        [string]$HumanLabel,
        [string]$FreshnessSupportState,
        [string]$DeployTargetKind,
        [string]$OutputModelSubPath,
        $Sentinel,                    # string|$null (framework-iis: $null E supported)
        $WebDirFreshnessExtensions,   # string[]|$null
        $RuntimeFreshnessExtensions,  # string[]|$null
        $RuntimeExclusionPrefixes,    # string[]|$null ($null, NAO @(), quando desconhecido)
        $PublicationTargets,          # object[] (opaco as Fases 1/2)
        $UnsupportedReason,           # string|$null
        $ErrorMessage,                # string|$null
        [string[]]$TentativeFields
    )

    if (-not $script:GeneXusKbHostingKindFreshnessSkipStatusByState.Contains($FreshnessSupportState)) {
        throw "freshnessSupportState desconhecido ao montar o registro: '$FreshnessSupportState'"
    }
    $skipStatus = $script:GeneXusKbHostingKindFreshnessSkipStatusByState[$FreshnessSupportState]

    return [ordered]@{
        hostingKind                = $HostingKind
        family                     = $Family
        humanLabel                 = $HumanLabel
        freshnessSupportState      = $FreshnessSupportState
        freshnessSkipStatus        = $skipStatus
        runsFreshnessEngine        = ($FreshnessSupportState -eq 'supported')
        deployTargetKind           = $DeployTargetKind
        outputModelSubPath         = $OutputModelSubPath
        sentinel                   = $Sentinel
        webDirFreshnessExtensions  = $WebDirFreshnessExtensions
        runtimeFreshnessExtensions = $RuntimeFreshnessExtensions
        runtimeExclusionPrefixes   = $RuntimeExclusionPrefixes
        publicationTargets         = $PublicationTargets
        unsupportedReason          = $UnsupportedReason
        errorMessage               = $ErrorMessage
        tentativeFields            = @($TentativeFields)
    }
}

# ── Montagem do registro ────────────────────────────────────────────────────────

$script:GeneXusKbHostingKindSupportRegistry = [ordered]@{}

# Prefixos/extensoes .NET, espelhados do motor atual (evidencia por leitura direta):
#   GeneXusKbDeployBinSupport.ps1:347 (webDir), :167-175 (exclusao), Test-GeneXusRuntimeFreshness.ps1:148 (runtime).
$dotnetExclusionPrefixes = @('GeneXus.', 'System.', 'Microsoft.')
$dotnetWebDirExtensions  = @('.cs', '.js', '.aspx', '.dll')
$dotnetRuntimeExtensions = @('.cs', '.js', '.aspx', '.rsp')

# publicationTargets .NET ja na forma-alvo da Fase 3 (subPath 'bin'), porem OPACO as Fases 1/2:
# nenhum consumidor de Fase 1/2 itera este campo (clausula no-bridge). evidenceStrategy e string
# livre na Fase 1 (vira enum fechado so na Fase 3).
$dotnetPublicationTargets = @(
    [ordered]@{
        subPath           = 'bin'
        evidenceStrategy  = 'object-dll-or-config'
        exclusionPrefixes = $dotnetExclusionPrefixes
    }
)

$dotnetCoreRecord = @{
    HostingKind                = 'dotnet-core-self-host'
    Family                     = 'dotnet'
    HumanLabel                 = '.NET Core (self-host)'
    FreshnessSupportState      = 'supported'
    DeployTargetKind           = 'in-kb-web'
    OutputModelSubPath         = 'CSharpModel\web'
    Sentinel                   = 'GxNetCoreStartup.dll'
    WebDirFreshnessExtensions  = $dotnetWebDirExtensions
    RuntimeFreshnessExtensions = $dotnetRuntimeExtensions
    RuntimeExclusionPrefixes   = $dotnetExclusionPrefixes
    PublicationTargets         = $dotnetPublicationTargets
    UnsupportedReason          = $null
    ErrorMessage               = $null
    TentativeFields            = @()
}
$script:GeneXusKbHostingKindSupportRegistry['dotnet-core-self-host'] =
    New-GeneXusKbHostingKindSupportRecord @dotnetCoreRecord

# framework-iis: invariante do design — sentinel=$null E freshnessSupportState='supported'.
$dotnetFrameworkRecord = @{
    HostingKind                = 'dotnet-framework-iis'
    Family                     = 'dotnet'
    HumanLabel                 = '.NET Framework (IIS)'
    FreshnessSupportState      = 'supported'
    DeployTargetKind           = 'in-kb-web'
    OutputModelSubPath         = 'CSharpModel\web'
    Sentinel                   = $null
    WebDirFreshnessExtensions  = $dotnetWebDirExtensions
    RuntimeFreshnessExtensions = $dotnetRuntimeExtensions
    RuntimeExclusionPrefixes   = $dotnetExclusionPrefixes
    PublicationTargets         = $dotnetPublicationTargets
    UnsupportedReason          = $null
    ErrorMessage               = $null
    TentativeFields            = @()
}
$script:GeneXusKbHostingKindSupportRegistry['dotnet-framework-iis'] =
    New-GeneXusKbHostingKindSupportRecord @dotnetFrameworkRecord

# java-tomcat: reconhecido-sem-motor. Familia e estado sao definitivos; os campos de motor
# sao provisorios (tentativeFields) ate a Fase 0/3 aterrar a evidencia. Marcador 'tentative-java'
# nos campos string; $null (NAO @()) nos campos de lista para significar "desconhecido", nunca
# "sem exclusoes/sem alvos". deployTargetKind='in-kb-web' e a recomendacao v1 (in-place), sujeita
# ao Plano B se a Fase 0 revelar topologia externa (.war/webapp fora de web).
$javaTomcatRecord = @{
    HostingKind                = 'java-tomcat'
    Family                     = 'java'
    HumanLabel                 = 'Java / Tomcat'
    FreshnessSupportState      = 'recognized-no-engine'
    DeployTargetKind           = 'in-kb-web'
    OutputModelSubPath         = $script:GeneXusKbHostingKindTentativeJavaMarker
    Sentinel                   = $script:GeneXusKbHostingKindTentativeJavaMarker
    WebDirFreshnessExtensions  = $null
    RuntimeFreshnessExtensions = $null
    RuntimeExclusionPrefixes   = $null
    PublicationTargets         = @()
    UnsupportedReason          = 'Gerador Java/Tomcat reconhecido, mas o motor de verificacao de deploy-bin ainda e .NET (Eixo A). Checagem pulada (skipped-hosting-unsupported) ate a Fase 3 dar motor por familia.'
    ErrorMessage               = $null
    TentativeFields            = @(
        'deployTargetKind'
        'outputModelSubPath'
        'sentinel'
        'webDirFreshnessExtensions'
        'runtimeFreshnessExtensions'
        'runtimeExclusionPrefixes'
        'publicationTargets'
    )
}
$script:GeneXusKbHostingKindSupportRegistry['java-tomcat'] =
    New-GeneXusKbHostingKindSupportRecord @javaTomcatRecord

# ── API publica ─────────────────────────────────────────────────────────────────

function Get-GeneXusKbHostingKindSupportRecord {
    <#
    .SYNOPSIS
        Acessor unico do registro de hosting kinds.
    .DESCRIPTION
        Com -HostingKind: retorna o registro (pscustomobject) do kind, ou $null se
        desconhecido. Sem -HostingKind: retorna todos os registros (array), na ordem
        de declaracao. Unica porta de leitura do registro; nenhum consumidor toca o
        $script: table diretamente.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$HostingKind
    )

    if ($PSBoundParameters.ContainsKey('HostingKind') -and -not [string]::IsNullOrWhiteSpace($HostingKind)) {
        $key = $HostingKind.Trim()
        if ($script:GeneXusKbHostingKindSupportRegistry.Contains($key)) {
            return [pscustomobject]$script:GeneXusKbHostingKindSupportRegistry[$key]
        }
        return $null
    }

    $all = foreach ($key in $script:GeneXusKbHostingKindSupportRegistry.Keys) {
        [pscustomobject]$script:GeneXusKbHostingKindSupportRegistry[$key]
    }
    return @($all)
}

function Get-GeneXusKbHostingKindSupportInvalidValueMessage {
    <#
    .SYNOPSIS
        Mensagem canonica (fonte-unica) para deployment_hosting_kind invalido.
    .DESCRIPTION
        Deriva a lista de valores reconhecidos do proprio registro, evitando listas
        .NET-only redigitadas nos emissores. Consumida na Fase 2 (validacao manual que
        substitui o [ValidateSet]).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$HostingKind
    )

    $supported = @($script:GeneXusKbHostingKindSupportRegistry.Keys) -join ', '
    $shown = if ([string]::IsNullOrWhiteSpace($HostingKind)) { '(vazio)' } else { $HostingKind }
    return ("deployment_hosting_kind invalido: '{0}'. Valores reconhecidos: {1}." -f $shown, $supported)
}

# ── ArgumentCompleter fail-soft (opt-in) ────────────────────────────────────────

function Get-GeneXusKbHostingKindArgumentCompleterScriptBlock {
    <#
    .SYNOPSIS
        Scriptblock de completamento fail-soft para o parametro de hosting kind.
    .DESCRIPTION
        Enumera os kinds via a API publica. Se a enumeracao falhar (registro indisponivel
        no momento do completamento), cai para uma lista estatica minima embutida — nunca
        lanca durante o TAB. O self-test trava a equivalencia lista-viva == lista-fallback
        (guarda de drift).
    #>
    return {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $candidates = $null
        try {
            $records = Get-GeneXusKbHostingKindSupportRecord
            if ($null -ne $records) {
                $candidates = @($records | ForEach-Object { $_.hostingKind })
            }
        }
        catch {
            $candidates = $null
        }

        if ($null -eq $candidates -or @($candidates).Count -eq 0) {
            # Fail-soft: lista estatica minima (deve espelhar as chaves do registro; guarda no self-test).
            $candidates = @('dotnet-core-self-host', 'dotnet-framework-iis', 'java-tomcat')
        }

        $prefix = [string]$wordToComplete
        foreach ($candidate in $candidates) {
            if ([string]::IsNullOrEmpty($prefix) -or
                $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                [System.Management.Automation.CompletionResult]::new(
                    $candidate, $candidate, 'ParameterValue', $candidate)
            }
        }
    }
}

function Register-GeneXusKbHostingKindArgumentCompleter {
    <#
    .SYNOPSIS
        Registra o completer fail-soft no(s) comando(s)/parametro informados.
    .DESCRIPTION
        Helper opt-in. A fiacao efetiva aos scripts consumidores (apos remover o
        [ValidateSet]) e da Fase 2; a Fase 1 apenas entrega o mecanismo, testado.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CommandName,

        [string]$ParameterName = 'DeploymentHostingKind'
    )

    $scriptBlock = Get-GeneXusKbHostingKindArgumentCompleterScriptBlock
    Register-ArgumentCompleter -CommandName $CommandName -ParameterName $ParameterName -ScriptBlock $scriptBlock
}
