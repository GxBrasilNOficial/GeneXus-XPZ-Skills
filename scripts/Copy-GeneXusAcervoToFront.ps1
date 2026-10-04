#requires -Version 7.4

<#
.SYNOPSIS
    Copia XMLs do acervo para a frente, com bump de lastUpdate.

.DESCRIPTION
    Para cada XML de objeto na pasta da frente com contraparte única por GUID no acervo
    e lastUpdate elegível, copia o arquivo do acervo sobre o da frente e bumpa lastUpdate para
    garantir que o novo arquivo fique estritamente mais novo que o acervo. Quando alvo
    explicito e informado (-ObjectList/-ObjectNames/-ObjectGuids), tambem permite
    reconstruir a copia a partir do acervo mesmo se a frente ja estiver mais nova; isso
    cobre a remediacao de front-textual-fidelity-trim-removal-churn. Excecao: quando o
    mesmo guid tem Object/@type divergente, a copia automatica e bloqueada.

    Resolve o anti-padrao "editar acervo esperando que o pacote pegue": em vez de editar
    o acervo, o agente copia a versão mais recente do acervo para a frente e depois edita
    a copia. O gate 9-FD (Test-GeneXusFrontAcervoDrift.ps1) detecta o drift; este script
    resolve drift temporal e reconstrução textual explicita copiando e bumpando; drift
    de Object/@type por mesmo guid exige decisao humana antes de qualquer autocopia.

    Comportamento por finding do gate 9-FD:
      - front-older-than-acervo: copia do acervo e bumpa lastUpdate (ação primaria)
      - front-equals-acervo: copia do acervo e bumpa lastUpdate (conservative; o agente
        pode querer preservar, mas copiar e bumpar e o caminho seguro para edicoes futuras)
      - front-only-new-object: ignorado (objeto novo, sem homonimo no acervo)
      - front-newer-than-acervo: ignorado na varredura sem alvo explicito; com alvo
        explicito, copia do acervo e bumpa lastUpdate para reconstruir a frente
      - lastupdate-unparseable: ignorado (requer resolucao manual)
      - front-object-type-drift: ignorado (requer decisao humana; nao autocopiar)
      - front-textual-fidelity-trim-removal-churn: usar alvo explicito para reconstruir
        do acervo, bumpar lastUpdate e reaplicar apenas o delta funcional
      - front-textual-fidelity-info: informativo restrito a falha de leitura/decodificação
        UTF-8 comparável após baseline único por GUID; sem ação automatica

    Quando -ObjectList, -ObjectNames ou -ObjectGuids e fornecido, só os objetos listados
    são considerados para copia. Quando omitido, todos os objetos com drift são copiados.
    Se um objeto listado explicitamente ainda não existir na frente, o script faz seed
    inicial desse objeto a partir do acervo. Se o objeto já existir na frente e estiver
    mais novo que o acervo, alvo explicito autoriza reconstruir/sobrescrever a copia
    local para remediar bloqueio textual; use -DryRun quando houver dúvida. Seed nunca
    ocorre sem alvo explicito.

.PARAMETER FrontFolder
    Caminho da pasta da frente (ObjetosGeradosParaImportacaoNaKbNoGenexus/<NomeCurto_GUID_YYYYMMDD>).
    Pre-condicao: a frente deve ter sido aberta por New-GeneXusXpzFront.ps1 (wrapper local
    New-*KbFront.ps1, com -ReuseIfExists para retomar); este script apenas popula uma frente
    existente, nao a cria.

.PARAMETER AcervoFolder
    Caminho da pasta do acervo oficial (ObjetosDaKbEmXml).

.PARAMETER ObjectList
    Nome canonico do contrato de selecao de objeto por nome. Aceita nomes simples
    ou entradas `Tipo:Nome`; o tipo é resolvido no catálogo efetivo e conferido
    por Object/@type, sem rótulos Export ou interpretação FQN. Quando omitido
    (junto com -ObjectNames/-ObjectGuids), copia todos com
    drift. Para seed inicial, deve identificar um único XML no acervo. Quando o
    objeto já existe na frente, alvo explicito pode sobrescrever a copia mais nova
    para reconstrução textual deliberada.

.PARAMETER ObjectNames
    Seleção literal por nome simples, sem interpretar Tipo:Nome; mantida
    por retrocompatibilidade. Itens informados por -ObjectNames e -ObjectList são
    combinados.

.PARAMETER ObjectGuids
    GUIDs de objetos a copiar (opcional). Quando omitido, copia todos com drift.
    Entrada fornecida mas vazia após normalização gera selector-invalid e mantém
    o filtro ativo; não equivale à omissão.
    Para seed inicial, deve identificar um único XML no acervo. Quando o objeto já
    existe na frente, alvo explicito pode sobrescrever a copia mais nova para
    reconstrução textual deliberada.

.PARAMETER FreshnessMarginSeconds
    Margem em segundos aplicada sobre o lastUpdate do acervo ao bumpar. Default: 60.

.PARAMETER ParallelKbRoot
    Raiz para derivar scripts/gx-object-type-catalog.override.json em pedidos tipados.
    Sem raiz/override explícito, somente o catálogo-base é usado.

.PARAMETER CatalogOverridePath
    Override explícito, com precedência sobre ParallelKbRoot. Nomes/GUIDs puros não
    carregam catálogo. Override bloqueado gera finding; falha da base é infraestrutura.

.PARAMETER DryRun
    Mostra o que seria copiado sem gravar. Útil para preview.

.EXAMPLE
    # Refresh por drift: copia do acervo todos os objetos da frente que estiverem mais antigos.
    .\Copy-GeneXusAcervoToFront.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml

.EXAMPLE
    # Seed inicial: copia objetos específicos do acervo para uma frente em que eles ainda
    # não existem. Seed só ocorre com alvo explicito (-ObjectList/-ObjectNames/-ObjectGuids);
    # sem alvo, nada e semeado e o status pode vir 'not-applicable'/objectsScanned:0 — esperado, não erro.
    # Se um alvo explicito já existir e estiver mais novo na frente, o script pode
    # reconstruir/sobrescrever essa copia; use -DryRun para preview.
    .\Copy-GeneXusAcervoToFront.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml -ObjectList 'Procedure:PReabastecerEstoque','SDT_Item'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true)]
    [string]$AcervoFolder,

    [string[]]$ObjectNames,

    [string[]]$ObjectList,

    [string[]]$ObjectGuids,

    [string]$ParallelKbRoot,

    [string]$CatalogOverridePath,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$objectTypeDriftSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusObjectTypeDriftSupport.ps1'
if (-not (Test-Path -LiteralPath $objectTypeDriftSupportPath -PathType Leaf)) {
    throw "Object type drift support script not found: $objectTypeDriftSupportPath"
}
. $objectTypeDriftSupportPath

function Format-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][DateTime]$Value)
    return $Value.ToUniversalTime().ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Read-ObjectLastUpdateSafe {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root
    )
    $raw = $Root.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $raw,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        return $null
    }
    return $parsed.UtcDateTime
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ObjectName,
        [string]$ObjectGuid,
        [string]$ObjectFile,
        [string]$AcervoFile,
        [string]$Action,
        [string]$FrontLastUpdateBefore,
        [string]$AcervoLastUpdate,
        [string]$FrontLastUpdateAfter
    )
    return [pscustomobject]@{
        severity             = $Severity
        code                 = $Code
        message              = $Message
        objectName           = $ObjectName
        objectGuid           = $ObjectGuid
        objectFile           = $ObjectFile
        acervoFile           = $AcervoFile
        action               = $Action
        frontLastUpdateBefore = $FrontLastUpdateBefore
        acervoLastUpdate     = $AcervoLastUpdate
        frontLastUpdateAfter = $FrontLastUpdateAfter
    }
}

function Get-ObjectMetadata {
    param([string]$XmlPath)
    try {
        [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    } catch {
        return $null
    }
    $root = $doc.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'Object') { return $null }
    $objType = $root.GetAttribute('type')
    $objName = $root.GetAttribute('name')
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'Name') { $objName = $prop.Value; break }
    }
    $objGuid = $root.GetAttribute('guid')
    $objFqn = $root.GetAttribute('fullyQualifiedName')
    $lastUpdate = Read-ObjectLastUpdateSafe $root
    return [pscustomobject]@{
        Path       = $XmlPath
        Name       = $objName
        AttributeName = $root.GetAttribute('name')
        TypeGuid   = $objType
        Guid       = $objGuid
        Fqn        = $objFqn
        LastUpdate = $lastUpdate
    }
}

# Cache local por execução; nomes explícitos conservam o critério de arquivo-folha.
function Find-AcervoObjectXmlByExplicitTarget {
    param([string]$ObjectName, [string]$ObjectGuid, [string]$TypeGuid)
    $matches = @($acervoMetas | Where-Object {
        if (-not [string]::IsNullOrWhiteSpace($ObjectGuid)) {
            (Normalize-GeneXusObjectTypeDriftValue $_.Guid) -eq $ObjectGuid
        } else {
            [System.IO.Path]::GetFileName($_.Path) -like "$ObjectName.xml" -and
                $_.Name -eq $ObjectName -and
                ([string]::IsNullOrEmpty($TypeGuid) -or (Normalize-GeneXusObjectTypeDriftValue $_.TypeGuid) -eq $TypeGuid)
        }
    })
    $state = 'not-found'
    $meta = $null
    if ($matches.Count -eq 1) { $state = 'found'; $meta = $matches[0] }
    if ($matches.Count -gt 1) { $state = 'ambiguous' }
    [pscustomobject]@{ Status = $state; Meta = $meta; Candidates = $matches }
}

# Contrato próprio do Copy mantido; migração dos campos comuns do 9-FD continua no 999.
function Add-CopyBlock {
    param([string]$Code, [string]$Message, [object]$Meta, [string]$Name = '', [string]$Guid = '', [object]$AcervoMeta)
    $file = ''
    if ($null -ne $Meta) { $Name = $Meta.Name; $Guid = $Meta.Guid; $file = [System.IO.Path]::GetFileName($Meta.Path) }
    $acervoFile = ''
    $frontDate = ''
    $acervoDate = ''
    if ($null -ne $Meta -and $null -ne $Meta.LastUpdate) { $frontDate = Format-GeneXusLastUpdate $Meta.LastUpdate }
    if ($null -ne $AcervoMeta) {
        $acervoFile = [IO.Path]::GetRelativePath($AcervoFolder, $AcervoMeta.Path)
        if ($null -ne $AcervoMeta.LastUpdate) { $acervoDate = Format-GeneXusLastUpdate $AcervoMeta.LastUpdate }
    }
    $script:findings += New-Finding -Severity 'fail' -Code $Code -Message $Message -ObjectName $Name -ObjectGuid $Guid -ObjectFile $file -AcervoFile $acervoFile -Action 'skip' -FrontLastUpdateBefore $frontDate -AcervoLastUpdate $acervoDate
}

function Test-CopyIdentity {
    param([object]$Meta)
    return (-not [string]::IsNullOrWhiteSpace($Meta.Guid) -and -not [string]::IsNullOrWhiteSpace($Meta.TypeGuid))
}

function Test-NameRequest {
    param([object]$Request, [object]$Meta, [switch]$IncludeType)
    return ($Request.Name -eq $Meta.Name -and
        (-not $IncludeType -or [string]::IsNullOrEmpty($Request.TypeGuid) -or
            $Request.TypeGuid -eq (Normalize-GeneXusObjectTypeDriftValue $Meta.TypeGuid)))
}

function Copy-AcervoMetaToFront {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$AcervoMeta,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$ActionCode,
        [Parameter(Mandatory = $true)][string]$DryRunCode,
        [Parameter(Mandatory = $true)][string]$MessagePrefix,
        [string]$FrontLastUpdateBefore = ''
    )

    if ($null -eq $AcervoMeta.LastUpdate) {
        $script:findings += New-Finding -Severity 'warn' -Code 'lastupdate-unparseable-skip' `
            -Message "Objeto '$($AcervoMeta.Name)' com lastUpdate do acervo nao parseavel; copia manual necessaria." `
            -ObjectName $AcervoMeta.Name -ObjectGuid $AcervoMeta.Guid `
            -ObjectFile ([System.IO.Path]::GetFileName($DestinationPath)) `
            -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $AcervoMeta.Path)) `
            -Action 'skip' `
            -FrontLastUpdateBefore $FrontLastUpdateBefore `
            -AcervoLastUpdate '' `
            -FrontLastUpdateAfter ''
        return
    }

    $aLastStr = Format-GeneXusLastUpdate $AcervoMeta.LastUpdate
    $aRel = [System.IO.Path]::GetRelativePath($AcervoFolder, $AcervoMeta.Path)
    $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $DestinationPath)

    $utcNow = [DateTime]::UtcNow
    $baseCandidate = $utcNow.AddSeconds($FreshnessMarginSeconds)
    $baselineCandidate = $AcervoMeta.LastUpdate.AddSeconds($FreshnessMarginSeconds)
    if ($baselineCandidate -gt $baseCandidate) {
        $baseCandidate = $baselineCandidate
    }
    $newLastUpdate = Format-GeneXusLastUpdate -Value $baseCandidate

    if ($DryRun) {
        $script:findings += New-Finding -Severity 'info' -Code $DryRunCode `
            -Message "DRY RUN: $MessagePrefix '$($AcervoMeta.Path)' -> '$DestinationPath' e bump lastUpdate de $aLastStr para $newLastUpdate." `
            -ObjectName $AcervoMeta.Name -ObjectGuid $AcervoMeta.Guid `
            -ObjectFile $fRel -AcervoFile $aRel `
            -Action $DryRunCode `
            -FrontLastUpdateBefore $FrontLastUpdateBefore -AcervoLastUpdate $aLastStr -FrontLastUpdateAfter $newLastUpdate
        return
    }

    Copy-Item -LiteralPath $AcervoMeta.Path -Destination $DestinationPath -Force

    $rawText = [System.IO.File]::ReadAllText($DestinationPath)
    $pattern = [regex]::new('lastUpdate="[^"]*"')
    $newText = $pattern.Replace($rawText, "lastUpdate=""$newLastUpdate""", 1)

    $utf8NoBom = (Get-Utf8NoBomEncoding)
    [System.IO.File]::WriteAllText($DestinationPath, $newText, $utf8NoBom)

    $script:findings += New-Finding -Severity 'info' -Code $ActionCode `
        -Message "Objeto '$($AcervoMeta.Name)' $MessagePrefix e bumpado: lastUpdate $aLastStr -> $newLastUpdate." `
        -ObjectName $AcervoMeta.Name -ObjectGuid $AcervoMeta.Guid `
        -ObjectFile $fRel -AcervoFile $aRel `
        -Action $ActionCode `
        -FrontLastUpdateBefore $FrontLastUpdateBefore -AcervoLastUpdate $aLastStr -FrontLastUpdateAfter $newLastUpdate
}

# Validar parâmetros sem criar uma frente.
if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
    throw "FRENTE_NAO_ABERTA: FrontFolder nao encontrado ou nao e diretorio: $FrontFolder. A frente deve ser aberta/retomada por New-GeneXusXpzFront.ps1 (wrapper local New-*KbFront.ps1) com -ReuseIfExists antes de popular; nao crie a pasta manualmente."
}
if (-not (Test-Path -LiteralPath $AcervoFolder -PathType Container)) {
    throw "AcervoFolder nao encontrado ou nao e diretorio: $AcervoFolder"
}
$FrontFolder = (Resolve-Path -LiteralPath $FrontFolder).Path
$AcervoFolder = (Resolve-Path -LiteralPath $AcervoFolder).Path
$findings = @()
$nameRequestsProvided = ($null -ne $ObjectNames -and $ObjectNames.Count -gt 0) -or ($null -ne $ObjectList -and $ObjectList.Count -gt 0)
# Presença do filtro é independente da existência de pedidos normalizados válidos.
$guidRequestsProvided = ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0)
$guidRequests = @()
foreach ($item in $ObjectGuids) {
    $guid = Normalize-GeneXusObjectTypeDriftValue $item
    if (-not $guid) {
        Add-CopyBlock 'selector-invalid' 'Entrada de ObjectGuids vazia após normalização.'
        continue
    }
    $guidRequests += $guid
}
$explicitTargetsProvided = $nameRequestsProvided -or $guidRequestsProvided
$requests = @()
$catalog = $null
$catalogAttempted = $false
$catalogBlocked = $false
foreach ($source in @('ObjectNames', 'ObjectList')) {
    $items = $ObjectNames
    if ($source -eq 'ObjectList') { $items = $ObjectList }
    foreach ($item in $items) {
        $name = [string]$item
        $typeGuid = ''
        if ($source -eq 'ObjectList' -and $name.Contains(':')) {
            $parts = $name.Split(':', 2)
            $typeName = $parts[0]
            $name = $parts[1]
            if ([string]::IsNullOrWhiteSpace($typeName) -or [string]::IsNullOrWhiteSpace($name)) {
                Add-CopyBlock 'selector-invalid' "Entrada tipada inválida: '$item'." -Name $name
                continue
            }
            if (-not $catalogAttempted) {
                $catalogAttempted = $true
                . (Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1')
                # Falha da base é infraestrutura: não a mascarar como falha de override.
                $base = Read-GeneXusObjectTypeCatalogFile (Get-GeneXusObjectTypeCatalogDefaultBasePath)
                if ($base -isnot [pscustomobject] -or
                    $null -eq $base.PSObject.Properties['types'] -or
                    $base.types -isnot [pscustomobject]) {
                    throw 'CATALOGO_BASE_INVALIDO: a base e types devem ser objetos JSON.'
                }
                try {
                    $catalog = (Resolve-GeneXusObjectTypeCatalogPaths -ParallelKbRoot $ParallelKbRoot -CatalogOverridePath $CatalogOverridePath).MergedCatalog
                } catch {
                    if ($_.Exception.Message -notlike 'OVERRIDE_RESOLUTION_BLOCKED:*') { throw }
                    $catalogBlocked = $true
                    Add-CopyBlock 'selector-catalog-override-blocked' $_.Exception.Message
                }
            }
            if ($catalogBlocked) { continue }
            $entries = @($catalog.types.PSObject.Properties | Where-Object { $_.Name -eq $typeName })
            if ($entries.Count -eq 0) {
                $entries = @($catalog.types.PSObject.Properties | Where-Object {
                    (Get-GeneXusCatalogEntryValue $_.Value 'folderName') -eq $typeName
                })
            }
            if ($entries.Count -ne 1) {
                Add-CopyBlock 'selector-type-unknown' "Tipo desconhecido ou alias de pasta ambíguo: '$typeName'." -Name $name
                continue
            }
            $entry = $entries[0].Value
            $typeGuid = Normalize-GeneXusObjectTypeDriftValue (Get-GeneXusCatalogEntryValue $entry 'objectTypeGuid')
            if (-not $typeGuid -or (Get-GeneXusCatalogEntryValue $entry 'rootKind') -ne 'Object') {
                Add-CopyBlock 'selector-type-unsupported' "Tipo não suportado pelo Copy: '$typeName'." -Name $name
                continue
            }
        }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $requests += [pscustomobject]@{ Name = $name; TypeGuid = $typeGuid }
    }
}

$frontXmls = @(Get-ChildItem -LiteralPath $FrontFolder -File -Filter '*.xml')
$frontMetas = @($frontXmls | ForEach-Object { Get-ObjectMetadata $_.FullName } | Where-Object { $null -ne $_ })
# Ocupação física independe da leitura XML. Reserva em DryRun e execução é a mesma.
$reservedDestinations = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $frontXmls) { $reservedDestinations[$file.FullName] = 'physical' }
$existingFrontGuids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($meta in $frontMetas) {
    $key = Normalize-GeneXusObjectTypeDriftValue $meta.Guid
    if ($key) { [void]$existingFrontGuids.Add($key) }
}
$acervoMetas = @()
if (($frontMetas.Count -gt 0 -and -not $explicitTargetsProvided) -or $requests.Count -gt 0 -or $guidRequests.Count -gt 0) {
    $acervoMetas = @(Get-ChildItem -LiteralPath $AcervoFolder -Recurse -File -Filter '*.xml' |
        Sort-Object FullName | ForEach-Object { Get-ObjectMetadata $_.FullName } | Where-Object { $null -ne $_ })
}

foreach ($fMeta in $frontMetas) {
    if ($nameRequestsProvided -and @($requests | Where-Object { Test-NameRequest $_ $fMeta }).Count -eq 0) { continue }
    $key = Normalize-GeneXusObjectTypeDriftValue $fMeta.Guid
    if ($guidRequestsProvided -and $key -notin $guidRequests) { continue }
    $matches = @()
    if ($key) { $matches = @($acervoMetas | Where-Object { (Normalize-GeneXusObjectTypeDriftValue $_.Guid) -eq $key }) }
    if ($matches.Count -gt 1) {
        Add-CopyBlock 'front-acervo-guid-ambiguous-skip' "GUID duplicado no acervo; nenhuma contraparte escolhida: '$key'." $fMeta
        continue
    }
    $aMeta = $null
    if ($matches.Count -eq 1) {
        $aMeta = $matches[0]
        if (-not (Test-CopyIdentity $fMeta) -or -not (Test-CopyIdentity $aMeta)) {
            Add-CopyBlock 'copy-identity-incomplete-skip' 'Identidade incompleta impede sobrescrita.' $fMeta
            continue
        }
        if ((Normalize-GeneXusObjectTypeDriftValue $fMeta.TypeGuid) -ne (Normalize-GeneXusObjectTypeDriftValue $aMeta.TypeGuid)) {
            Add-CopyBlock 'front-object-type-drift-skip' "Mesmo GUID com Object/@type divergente (frente='$($fMeta.TypeGuid)', acervo='$($aMeta.TypeGuid)'); decisão humana requerida." $fMeta -AcervoMeta $aMeta
            continue
        }
    }
    # Tipo restringe TODOS os existentes, mas nunca apaga um bloqueio por identidade.
    if ($nameRequestsProvided -and @($requests | Where-Object { Test-NameRequest $_ $fMeta -IncludeType }).Count -eq 0) { continue }
    if ($null -eq $aMeta) {
        # Classificação legada: arquivo-folha + atributo name/FQN, não nome efetivo do seed.
        $homonyms = @($acervoMetas | Where-Object {
            ([System.IO.Path]::GetFileName($_.Path) -like "$($fMeta.Name).xml" -or
                ($fMeta.Fqn -and [System.IO.Path]::GetFileName($_.Path) -like "$($fMeta.Fqn).xml")) -and
            ($_.AttributeName -eq $fMeta.Name -or ($fMeta.Fqn -and $_.Fqn -eq $fMeta.Fqn))
        })
        if (-not (Test-CopyIdentity $fMeta)) {
            if ($explicitTargetsProvided -or $homonyms.Count -gt 0) { Add-CopyBlock 'copy-identity-incomplete-skip' 'Identidade da frente incompleta; preservar.' $fMeta }
            continue
        }
        $sameType = @($homonyms | Where-Object { (Normalize-GeneXusObjectTypeDriftValue $_.TypeGuid) -eq (Normalize-GeneXusObjectTypeDriftValue $fMeta.TypeGuid) })
        if ($sameType.Count -gt 0) {
            Add-CopyBlock 'front-object-identity-conflict-skip' 'Homônimo do mesmo tipo com outro GUID; preservar.' $fMeta
        } elseif (@($homonyms | Where-Object { -not (Test-CopyIdentity $_) }).Count -gt 0) {
            Add-CopyBlock 'copy-identity-incomplete-skip' 'Homônimo com identidade incompleta; preservar.' $fMeta
        }
        continue
    }
    if ($null -eq $fMeta.LastUpdate -or $null -eq $aMeta.LastUpdate) {
        $findings += New-Finding -Severity 'warn' -Code 'lastupdate-unparseable-skip' -Message 'lastUpdate não parseável; cópia manual necessária.' -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid -Action 'skip'
        continue
    }
    if ($fMeta.LastUpdate -gt $aMeta.LastUpdate -and -not $explicitTargetsProvided) { continue }
    Copy-AcervoMetaToFront -AcervoMeta $aMeta -DestinationPath $fMeta.Path -ActionCode 'copied-and-bumped' -DryRunCode 'dry-run-copy' -MessagePrefix 'copiado do acervo' -FrontLastUpdateBefore (Format-GeneXusLastUpdate $fMeta.LastUpdate)
}

# Pedido simples atendido por nome efetivo; tipado atendido só por nome E tipo.
# Atendimento precede interseção por GUID. Presença por GUID é independente do nome.
$seedRequests = @()
foreach ($request in $requests) {
    if (@($frontMetas | Where-Object { Test-NameRequest $request $_ -IncludeType }).Count -gt 0) { continue }
    $seedRequests += [pscustomobject]@{ Name = $request.Name; Guid = ''; TypeGuid = $request.TypeGuid }
}
foreach ($guid in $guidRequests) {
    if ($existingFrontGuids.Contains($guid)) { continue }
    $seedRequests += [pscustomobject]@{ Name = ''; Guid = $guid; TypeGuid = '' }
}
$seededKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($request in $seedRequests) {
    $lookup = Find-AcervoObjectXmlByExplicitTarget -ObjectName $request.Name -ObjectGuid $request.Guid -TypeGuid $request.TypeGuid
    if ($lookup.Status -ne 'found') {
        $code = 'seed-target-not-found'
        if ($lookup.Status -eq 'ambiguous') { $code = 'seed-target-ambiguous' }
        $paths = @($lookup.Candidates | ForEach-Object { [System.IO.Path]::GetRelativePath($AcervoFolder, $_.Path) })
        Add-CopyBlock $code "Alvo '$($request.Name)$($request.Guid)': $($lookup.Status). $($paths -join ', ')" -Name $request.Name -Guid $request.Guid
        continue
    }
    $seedMeta = $lookup.Meta
    $key = Normalize-GeneXusObjectTypeDriftValue $seedMeta.Guid
    if ($key -and $existingFrontGuids.Contains($key)) { continue }
    if (-not (Test-CopyIdentity $seedMeta)) {
        Add-CopyBlock 'copy-identity-incomplete-skip' 'Identidade do acervo incompleta; seed bloqueado.' $seedMeta
        continue
    }
    if (@($acervoMetas | Where-Object { (Normalize-GeneXusObjectTypeDriftValue $_.Guid) -eq $key }).Count -gt 1) {
        Add-CopyBlock 'seed-target-ambiguous' "GUID do alvo duplicado no acervo: '$key'." $seedMeta
        continue
    }
    # Diagnósticos de cada pedido precedem deduplicação de ações.
    if ($seededKeys.Contains($key)) { continue }
    $destination = [System.IO.Path]::GetFullPath((Join-Path $FrontFolder ([System.IO.Path]::GetFileName($seedMeta.Path))))
    if ($reservedDestinations.ContainsKey($destination) -or (Test-Path -LiteralPath $destination)) {
        Add-CopyBlock 'seed-destination-exists' "Destino ocupado/reservado: '$destination'." $seedMeta
        continue
    }
    if ($null -ne $seedMeta.LastUpdate) {
        $reservedDestinations[$destination] = $key
        [void]$seededKeys.Add($key)
    }
    Copy-AcervoMetaToFront -AcervoMeta $seedMeta -DestinationPath $destination -ActionCode 'seeded-and-bumped' -DryRunCode 'dry-run-seed' -MessagePrefix 'semeado do acervo'
}

$status = 'pass'
if (@($findings | Where-Object { $_.severity -eq 'fail' }).Count -gt 0) { $status = 'fail' }
elseif ($frontXmls.Count -eq 0 -and -not $explicitTargetsProvided) { $status = 'not-applicable' }
[pscustomobject]@{
    status = $status
    frontFolder = $FrontFolder
    acervoFolder = $AcervoFolder
    dryRun = $DryRun.IsPresent
    objectsScanned = $frontMetas.Count
    findings = @($findings)
} | ConvertTo-Json -Depth 10
