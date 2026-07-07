#requires -Version 7.4
<#
.SYNOPSIS
    Registro-fonte unico dos hosting kinds de deploy reconhecidos pelas skills XPZ.

.DESCRIPTION
    Fase 3 da paridade de gerador Java/Tomcat (design congelado em
    java-tomcat-paridade-gerador-design.md + replano java-tomcat-fase3-replano.md).
    Materializa o contrato do registro: uma entrada por deployment_hosting_kind, com
    suporte PER-EIXO — deployBinSupportState/runsDeployBinEngine (Eixo A, deploy-bin),
    sourceSupportState/runsSourceEngine (Eixo B, .cs/.java) e runtimeSupportState/
    runsRuntimeEngine (Eixo C, runtime) — mais o roteamento por familia. Aliases legados
    (runsFreshnessEngine/freshnessSupportState/freshnessSkipStatus/unsupportedReason)
    persistem 1 ciclo de release (deprecados, derivados do Eixo A) para consumidores
    externos (wrappers de pasta paralela).

    Acesso EXCLUSIVO via a API publica Get-GeneXusKbHostingKindSupportRecord. Nenhum
    consumidor le a hashtable interna ($script:GeneXusKbHostingKindSupportRegistry)
    diretamente; o self-test de drift (Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1)
    trava essa invariante por varredura estatica.

    Clausula no-bridge INVERTIDA (Fase 3): o campo publicationTargets[] e a forma-alvo do
    motor de deploy-bin e agora e citado LEGITIMAMENTE pelos arquivos-motor (registro +
    self-tests do co-gate) via allowlist; todo outro *.ps1 = zero ocorrencias (fail-closed,
    travado pelo self-test + guarda de drift da propria allowlist). O motor deixou de ser
    escalar: Get-GeneXusKbDeployBinPaths devolve LISTA de alvos (v1: 1 por KB) e
    Test-GeneXusKbDeployBinFreshnessCore e DISPATCHER por familia (dotnet|java).

    java-tomcat: Eixo A 'supported' (co-gate por conjunto de artefatos, alvo externo
    WEB-INF\classes; deployTargetKind='external-webapp'); Eixos B/C 'recognized-no-engine'
    (Pos-v1, skip). A Fase 5 aferiu o Eixo A para os ambientes disponiveis da KB Java externa.
    Campos residuais de Eixos B/C e extensoes ainda nao aterradas carregam o marcador
    'tentative-java' (campos string) ou permanecem $null (campos de lista, NAO @()) e
    seguem listados em tentativeFields.

    Dot-sourcing este arquivo NAO tem efeito colateral alem de definir as funcoes e montar
    o $script: table. O ArgumentCompleter e opt-in via Register-GeneXusKbHostingKindArgumentCompleter.
#>

Set-StrictMode -Version Latest

# ── Constantes de contrato ──────────────────────────────────────────────────────

# Marcador de valor residual: campos Java ainda pos-v1/nao aterrados apos Fase 5.
$script:GeneXusKbHostingKindTentativeJavaMarker = 'tentative-java'

# Contrato de saida do skip (design): exit 0 + status='skipped-hosting-unsupported' + <eixo>UnsupportedReason.
# Fonte unica desta string; os emissores nomeados do skip (Resolve-GeneXusKbDeployBinCheckPolicy em
# GeneXusKbDeployBinSupport.ps1, a fachada Test-GeneXusDeployBinFreshness.ps1, as guardas de familia dos
# Eixos C/B) devem derivar dela, nunca redigitar o literal.
$script:GeneXusKbHostingKindSkipStatus = 'skipped-hosting-unsupported'

# Mapa fonte-unica: valor de support-state (de QUALQUER eixo) -> status de skip ($null quando o motor roda).
# recognized-no-engine e blocked-out-of-scope compartilham a MESMA string de skip; a desambiguacao e pelo
# support-state/UnsupportedReason DO EIXO (deployBinSupportState/sourceSupportState/runtimeSupportState),
# nao pela string.
$script:GeneXusKbHostingKindFreshnessSkipStatusByState = [ordered]@{
    'supported'            = $null
    'recognized-no-engine' = $script:GeneXusKbHostingKindSkipStatus
    'blocked-out-of-scope' = $script:GeneXusKbHostingKindSkipStatus
}

# ── Construtor interno do registro (NAO faz parte da API publica) ────────────────

function New-GeneXusKbHostingKindSupportRecord {
    # Convencao de tipagem (deliberada): campos SEMPRE preenchidos (strings nao-nulas) sao
    # tipados [string]; campos que podem ser $null (sentinel, listas, prosa opcional) ficam
    # SEM tipo DE PROPOSITO. Tipar [string]$Sentinel = $null coage $null -> '' sob StrictMode e
    # quebraria a invariante framework-iis (sentinel=$null) e os campos de lista residuais
    # ($null, nao @()). Contrato dos nao-tipados: passar string|array|$null conforme o comentario.
    #
    # Fase 3 (sub-passo viii): o estado unico de suporte foi QUEBRADO em tres estados PER-EIXO
    # (Eixo A = deploy-bin freshness; Eixo B = fonte gerado .cs/.java; Eixo C = runtime-freshness).
    # Cada eixo tem seu proprio supportState, skipStatus, runs<Eixo>Engine e razao de skip. Java/Tomcat
    # passa a ter Eixo A = supported (motor por familia) mantendo B/C = recognized-no-engine (Pos-v1).
    param(
        [string]$HostingKind,
        [string]$Family,
        [string]$HumanLabel,
        [string]$DeployBinSupportState,   # Eixo A
        [string]$RuntimeSupportState,     # Eixo C
        [string]$SourceSupportState,      # Eixo B
        [string]$DeployTargetKind,
        [string]$OutputModelSubPath,
        [int]$DeployBinTimeSlackSeconds = 5,  # (v-ter)/(vi): Fase 5 confirmou 5s para a janela de copia; nao para compileJava
        $Sentinel,                    # string|$null (framework-iis: $null E supported)
        $WebDirFreshnessExtensions,   # string[]|$null
        $RuntimeFreshnessExtensions,  # string[]|$null
        $RuntimeExclusionPrefixes,    # string[]|$null ($null, NAO @(), quando desconhecido)
        $PublicationTargets,          # object[]|$null (forma-alvo do motor de deploy-bin; citado via allowlist no-bridge invertida; $null quando desconhecido)
        $SupportedServletFlavors,     # string[]|$null (vi-bis): SO a enumeracao de sabores da familia
        $DeployBinUnsupportedReason,  # string|$null (Eixo A)
        $RuntimeUnsupportedReason,    # string|$null (Eixo C)
        $SourceUnsupportedReason,     # string|$null (Eixo B)
        $ErrorMessage,                # string|$null
        [string[]]$TentativeFields
    )

    foreach ($pair in @(
            @{ eixo = 'deployBin(A)'; state = $DeployBinSupportState },
            @{ eixo = 'runtime(C)';   state = $RuntimeSupportState },
            @{ eixo = 'source(B)';    state = $SourceSupportState })) {
        if (-not $script:GeneXusKbHostingKindFreshnessSkipStatusByState.Contains($pair.state)) {
            throw "supportState desconhecido ao montar o registro (eixo=$($pair.eixo)): '$($pair.state)'"
        }
    }

    $deployBinSkipStatus = $script:GeneXusKbHostingKindFreshnessSkipStatusByState[$DeployBinSupportState]
    $runtimeSkipStatus   = $script:GeneXusKbHostingKindFreshnessSkipStatusByState[$RuntimeSupportState]
    $sourceSkipStatus    = $script:GeneXusKbHostingKindFreshnessSkipStatusByState[$SourceSupportState]
    $runsDeployBinEngine = ($DeployBinSupportState -eq 'supported')

    return [ordered]@{
        hostingKind                = $HostingKind
        family                     = $Family
        humanLabel                 = $HumanLabel

        # ── Estado PER-EIXO (Fase 3, sub-passo viii) ─────────────────────────────
        deployBinSupportState      = $DeployBinSupportState
        runtimeSupportState        = $RuntimeSupportState
        sourceSupportState         = $SourceSupportState
        runsDeployBinEngine        = $runsDeployBinEngine
        runsRuntimeEngine          = ($RuntimeSupportState -eq 'supported')
        runsSourceEngine           = ($SourceSupportState -eq 'supported')
        deployBinSkipStatus        = $deployBinSkipStatus
        runtimeSkipStatus          = $runtimeSkipStatus
        sourceSkipStatus           = $sourceSkipStatus
        deployBinUnsupportedReason = $DeployBinUnsupportedReason
        runtimeUnsupportedReason   = $RuntimeUnsupportedReason
        sourceUnsupportedReason    = $SourceUnsupportedReason

        # ── Migracao-compat (Fase 3, A3): aliases DEPRECADOS do Eixo A ────────────
        # Mantidos por UM ciclo de release para consumidores EXTERNOS (wrappers em pastas
        # paralelas de KB, fora do alcance da varredura semantica do doc 13). Todos os
        # consumidores INTERNOS ja migraram aos campos per-eixo acima. Derivados do Eixo A
        # (deploy-bin) — o unico eixo que o campo unico legado governava de fato. REMOVER no
        # proximo ciclo (a guarda de drift interna cobre os internos; o alias cobre os externos).
        freshnessSupportState      = $DeployBinSupportState
        freshnessSkipStatus        = $deployBinSkipStatus
        runsFreshnessEngine        = $runsDeployBinEngine
        unsupportedReason          = $DeployBinUnsupportedReason

        deployTargetKind           = $DeployTargetKind
        outputModelSubPath         = $OutputModelSubPath
        deployBinTimeSlackSeconds  = $DeployBinTimeSlackSeconds
        sentinel                   = $Sentinel
        webDirFreshnessExtensions  = $WebDirFreshnessExtensions
        runtimeFreshnessExtensions = $RuntimeFreshnessExtensions
        runtimeExclusionPrefixes   = $RuntimeExclusionPrefixes
        publicationTargets         = $PublicationTargets
        supportedServletFlavors    = $SupportedServletFlavors
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

# ALIASING PROPOSITAL (ver design, Fase 3 item (x)): os arrays $dotnet* compartilhados sao a MESMA
# referencia nos dois records .NET (a copia [pscustomobject] e rasa; os campos de lista continuam
# compartilhados): $dotnetExclusionPrefixes, $dotnetWebDirExtensions, $dotnetRuntimeExtensions e o
# proprio $dotnetPublicationTargets. Este ultimo vaza em DOIS niveis: o array em si (compartilhado
# entre os records) e $dotnetExclusionPrefixes aninhado em publicationTargets[0].exclusionPrefixes.
# Listas por familia sao clonadas antes de mutar para nao vazar entre records (clonar so o aninhado
# nao basta se $dotnetPublicationTargets for mutado por familia); o self-test do co-gate (cenario de
# aliasing) trava que as arrays Java != .NET (referencias distintas).

# publicationTargets .NET na forma-alvo (subPath 'bin'). Clausula no-bridge INVERTIDA (Fase 3): o campo
# e citado LEGITIMAMENTE pelos arquivos-motor via allowlist (o co-gate itera a forma-alvo); todo outro
# *.ps1 = zero ocorrencias (fail-closed, travado pelo self-test de drift + guarda de drift da allowlist).
$dotnetPublicationTargets = @(
    [ordered]@{
        subPath           = 'bin'
        evidenceStrategy  = 'object-dll-or-config'
        exclusionPrefixes = $dotnetExclusionPrefixes
    }
)

# .NET: os TRES eixos tem motor (A deploy-bin, B .cs, C runtime) -> supported em todos.
$dotnetCoreRecord = @{
    HostingKind                = 'dotnet-core-self-host'
    Family                     = 'dotnet'
    HumanLabel                 = '.NET Core (self-host)'
    DeployBinSupportState      = 'supported'
    RuntimeSupportState        = 'supported'
    SourceSupportState         = 'supported'
    DeployTargetKind           = 'in-kb-web'
    OutputModelSubPath         = 'CSharpModel\web'
    Sentinel                   = 'GxNetCoreStartup.dll'
    WebDirFreshnessExtensions  = $dotnetWebDirExtensions
    RuntimeFreshnessExtensions = $dotnetRuntimeExtensions
    RuntimeExclusionPrefixes   = $dotnetExclusionPrefixes
    PublicationTargets         = $dotnetPublicationTargets
    SupportedServletFlavors    = $null
    DeployBinUnsupportedReason = $null
    RuntimeUnsupportedReason   = $null
    SourceUnsupportedReason    = $null
    ErrorMessage               = $null
    TentativeFields            = @()
}
$script:GeneXusKbHostingKindSupportRegistry['dotnet-core-self-host'] =
    New-GeneXusKbHostingKindSupportRecord @dotnetCoreRecord

# framework-iis: invariante do design — sentinel=$null E deployBinSupportState='supported'.
$dotnetFrameworkRecord = @{
    HostingKind                = 'dotnet-framework-iis'
    Family                     = 'dotnet'
    HumanLabel                 = '.NET Framework (IIS)'
    DeployBinSupportState      = 'supported'
    RuntimeSupportState        = 'supported'
    SourceSupportState         = 'supported'
    DeployTargetKind           = 'in-kb-web'
    OutputModelSubPath         = 'CSharpModel\web'
    Sentinel                   = $null
    WebDirFreshnessExtensions  = $dotnetWebDirExtensions
    RuntimeFreshnessExtensions = $dotnetRuntimeExtensions
    RuntimeExclusionPrefixes   = $dotnetExclusionPrefixes
    PublicationTargets         = $dotnetPublicationTargets
    SupportedServletFlavors    = $null
    DeployBinUnsupportedReason = $null
    RuntimeUnsupportedReason   = $null
    SourceUnsupportedReason    = $null
    ErrorMessage               = $null
    TentativeFields            = @()
}
$script:GeneXusKbHostingKindSupportRegistry['dotnet-framework-iis'] =
    New-GeneXusKbHostingKindSupportRecord @dotnetFrameworkRecord

# java-tomcat: Eixo A (deploy-bin) SUPPORTED a partir da Fase 3 (motor Java = co-gate por familia).
# Eixos B/C seguem recognized-no-engine (Pos-v1). Campos do Eixo A aterrados do evidence-catalog
# (sentinela WEB-INF\lib\GeneXus.jar; publicationTargets external-servlet-dir; sabores jakarta/javax).
# Campos de Eixo B/C (outputModelSubPath, extensoes .cs/.rsp) seguem tentativos ($null/marcador).
# deployTargetKind='external-webapp' — Plano B aferido na Fase 0 (topologia externa, webapp no Tomcat).

# publicationTargets Java construidos DO ZERO (literais proprios) — cuidado de aliasing (x): NUNCA
# mutar/copiar os $dotnet*. Forma-alvo da Fase 3 (iv): alvo external-servlet-dir; a resolucao de
# com\<kb> vem de metadata dedicado (kb_environment_app_package) em runtime, nunca literal aqui.
$javaPublicationTargets = @(
    [ordered]@{
        targetResolution             = 'external-servlet-dir'
        subPath                      = $null
        externalTargetKey            = 'kb_environment_servlet_dirs'
        appPackageKey                = 'kb_environment_app_package'
        evidenceStrategy             = 'app-object-artifact-mtime'
        exclusionPrefixes            = $null
        exclusionPackages            = [ordered]@{
            allowRootMetadataKey = 'kb_environment_app_package'
            denySanity           = @('com\genexus', 'qviewer', 'dummy')
        }
        sentinelRelativeToWebappRoot = 'WEB-INF\lib\GeneXus.jar'
    }
)

$javaTomcatRecord = @{
    HostingKind                = 'java-tomcat'
    Family                     = 'java'
    HumanLabel                 = 'Java / Tomcat'
    DeployBinSupportState      = 'supported'
    RuntimeSupportState        = 'recognized-no-engine'
    SourceSupportState         = 'recognized-no-engine'
    DeployTargetKind           = 'external-webapp'
    OutputModelSubPath         = $script:GeneXusKbHostingKindTentativeJavaMarker
    Sentinel                   = 'WEB-INF\lib\GeneXus.jar'
    WebDirFreshnessExtensions  = $null
    RuntimeFreshnessExtensions = $null
    RuntimeExclusionPrefixes   = $null
    PublicationTargets         = $javaPublicationTargets
    SupportedServletFlavors    = @('jakarta', 'javax')
    DeployBinUnsupportedReason = $null
    RuntimeUnsupportedReason   = "Diagnostico de runtime-freshness (Eixo C) para Java/Tomcat e Pos-v1: guarda de familia ativa, motor Java nao. Checagem pulada ($($script:GeneXusKbHostingKindSkipStatus))."
    SourceUnsupportedReason    = "Diagnostico de fonte gerado .java (Eixo B) para Java/Tomcat e Pos-v1: guarda de familia ativa, motor Java nao. Checagem pulada ($($script:GeneXusKbHostingKindSkipStatus))."
    ErrorMessage               = $null
    # Eixo A aterrado (sentinel/publicationTargets saem de tentativos); Eixo B/C seguem tentativos (Pos-v1).
    TentativeFields            = @(
        'outputModelSubPath'
        'webDirFreshnessExtensions'
        'runtimeFreshnessExtensions'
        'runtimeExclusionPrefixes'
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
        desconhecido OU vazio/espaco. Sem -HostingKind (parametro nao informado): retorna
        todos os registros (array), na ordem de declaracao. Unica porta de leitura do
        registro; nenhum consumidor toca o $script: table diretamente.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$HostingKind
    )

    if ($PSBoundParameters.ContainsKey('HostingKind')) {
        # -HostingKind informado: lookup singular. Vazio/espaco -> $null (nao cai na enumeracao).
        if ([string]::IsNullOrWhiteSpace($HostingKind)) {
            return $null
        }
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

    # Enumera pela propria API publica (porta unica), nao pela hashtable interna: a mensagem
    # e sourced pelo mesmo caminho de leitura que todo o resto (dogfood do single-door).
    $supported = @((Get-GeneXusKbHostingKindSupportRecord).hostingKind) -join ', '
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
        (guarda de drift). O scriptblock resolve Get-...Record por NOME em runtime (resolucao
        dinamica), nao por captura de closure — e isso que permite ao self-test sombrear a
        funcao para exercitar o ramo fail-soft.
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
