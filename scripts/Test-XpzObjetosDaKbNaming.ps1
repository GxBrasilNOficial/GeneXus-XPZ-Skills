#requires -Version 7.4
<#
.SYNOPSIS
Audita o naming dos diretórios imediatos de ObjetosDaKbEmXml.

.DESCRIPTION
Para cada diretório imediato em ObjetosDaKbEmXml, le o primeiro XML classificavel,
extrai o tipo canonico pelo elemento raiz Attribute ou por Object/@type, compara
com o nome do diretório e emite resultado estruturado. Usa o catalogo efetivo
(base compartilhada + override local em scripts/ da pasta paralela quando existir).
O script e somente leitura.

.PARAMETER ParallelKbRoot
Raiz da pasta paralela da KB.

.PARAMETER CatalogPath
Caminho opcional para gx-object-type-catalog.json (base compartilhada).

.PARAMETER CatalogOverridePath
Caminho opcional para gx-object-type-catalog.override.json na pasta paralela.

.PARAMETER AsJson
Emite JSON estruturado em vez da tabela textual.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ParallelKbRoot,

    [string]$CatalogPath,

    [string]$CatalogOverridePath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportScript = Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1'
if (-not (Test-Path -LiteralPath $supportScript -PathType Leaf)) {
    throw "Support script not found: $supportScript"
}
. $supportScript

function Get-GeneXusLegacyOrphanTokenMap {
    # Mapa typeToken (lower) -> { TypeToken, FolderName } dos elementos legados orfaos do registro
    # gx-legacy-export-element-registry.json (camada de governanca de export legado GX9). Carregado
    # dinamicamente; ausente -> mapa vazio (comportamento inalterado).
    $registryPath = Join-Path $PSScriptRoot 'gx-legacy-export-element-registry.json'
    $map = @{}
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return $map
    }
    $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $registry.PSObject.Properties['elements']) {
        return $map
    }
    foreach ($prop in $registry.elements.PSObject.Properties) {
        $element = $prop.Value
        if ($null -ne $element.PSObject.Properties['class'] -and $element.class -eq 'orphan') {
            $token = [string]$element.typeToken
            $folder = [string]$element.materializedFolderName
            if (-not [string]::IsNullOrWhiteSpace($token) -and -not [string]::IsNullOrWhiteSpace($folder)) {
                $map[$token.ToLowerInvariant()] = [pscustomobject]@{ TypeToken = $token; FolderName = $folder }
            }
        }
    }
    return $map
}

function Write-StructuredError {
    param([string]$Message)

    if ($AsJson) {
        [pscustomobject]@{
            status    = 'STRUCTURAL_ERROR'
            divergent = @()
            all       = @()
            error     = $Message
        } | ConvertTo-Json -Depth 8
    } else {
        Write-Output "STRUCTURAL_ERROR: $Message"
    }
}

function Try-ClassifyXml {
    param(
        [string]$Path,
        [hashtable]$GuidMap,
        [hashtable]$LegacyOrphanMap
    )

    $document = [xml](Get-Content -LiteralPath $Path -Raw)
    $root = $document.DocumentElement
    if ($null -eq $root) {
        throw "XML sem elemento raiz"
    }

    $rootName = $root.LocalName
    if ($rootName -eq 'Attribute' -or $rootName -eq 'Attributes') {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $null
            TipoReal             = 'Attribute'
            NomeCanonicoEsperado = 'Attribute'
            StatusNaming         = $null
            SourceFile           = $Path
        }
    }

    if ($rootName -ne 'Object') {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $null
            TipoReal             = 'DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    $typeGuid = $root.GetAttribute('type')
    if ([string]::IsNullOrWhiteSpace($typeGuid)) {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $null
            TipoReal             = 'DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    if ($typeGuid -match '^gxlegacy/') {
        # Elemento legado orfao materializado por typeToken (gxlegacy/<Elemento>): o @type nunca
        # casa GUID do catalogo moderno; classifica pelo registro, nao como TIPO_DESCONHECIDO.
        $tokenKey = $typeGuid.ToLowerInvariant()
        if ($null -ne $LegacyOrphanMap -and $LegacyOrphanMap.ContainsKey($tokenKey)) {
            $orphan = $LegacyOrphanMap[$tokenKey]
            return [pscustomobject]@{
                Root                 = $rootName
                TypeGuid             = $typeGuid
                TipoReal             = $orphan.TypeToken
                NomeCanonicoEsperado = $orphan.FolderName
                StatusNaming         = $null
                SourceFile           = $Path
            }
        }
        # typeToken gxlegacy nao registrado -> desconhecido (defensivo).
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $typeGuid
            TipoReal             = 'TIPO_DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    $guidKey = $typeGuid.ToLowerInvariant()
    if (-not $GuidMap.ContainsKey($guidKey)) {
        return [pscustomobject]@{
            Root                 = $rootName
            TypeGuid             = $typeGuid
            TipoReal             = 'TIPO_DESCONHECIDO'
            NomeCanonicoEsperado = $null
            StatusNaming         = 'TIPO_DESCONHECIDO'
            SourceFile           = $Path
        }
    }

    $mapped = $GuidMap[$guidKey]
    return [pscustomobject]@{
        Root                 = $rootName
        TypeGuid             = $typeGuid
        TipoReal             = $mapped.TypeName
        NomeCanonicoEsperado = $mapped.FolderName
        StatusNaming         = $null
        SourceFile           = $Path
    }
}

try {
    $resolvedKbRoot = (Resolve-Path -LiteralPath $ParallelKbRoot).Path
    $objetosPath = Join-Path $resolvedKbRoot 'ObjetosDaKbEmXml'
    if (-not (Test-Path -LiteralPath $objetosPath -PathType Container)) {
        throw "ObjetosDaKbEmXml nao encontrado: $objetosPath"
    }

    $catalogResolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath $CatalogPath -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $resolvedKbRoot
    $typeMap = Get-GeneXusCatalogGuidToTypeMap -MergedCatalog $catalogResolution.MergedCatalog
    $guidMap = @{}
    foreach ($entry in $typeMap.GetEnumerator()) {
        $guidMap[$entry.Key] = $entry.Value
    }
    $legacyOrphanMap = Get-GeneXusLegacyOrphanTokenMap
    $rows = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($dir in Get-ChildItem -LiteralPath $objetosPath -Directory | Sort-Object Name) {
        $xmlFiles = @(Get-ChildItem -LiteralPath $dir.FullName -Filter '*.xml' -File | Sort-Object Name)
        if ($xmlFiles.Count -eq 0) {
            $rows.Add([pscustomobject]@{
                Diretorio             = $dir.Name
                Root                  = $null
                TypeGuid              = $null
                TipoReal              = 'INDETERMINADO'
                StatusNaming          = 'INDETERMINADO'
                NomeCanonicoEsperado  = $null
                SourceFile            = $null
                Observacao            = 'diretorio sem XML legivel'
            })
            continue
        }

        $classified = $null
        $lastError = $null
        foreach ($xmlFile in $xmlFiles) {
            try {
                $classified = Try-ClassifyXml -Path $xmlFile.FullName -GuidMap $guidMap -LegacyOrphanMap $legacyOrphanMap
                break
            } catch {
                $lastError = $_.Exception.Message
            }
        }

        if ($null -eq $classified) {
            $rows.Add([pscustomobject]@{
                Diretorio             = $dir.Name
                Root                  = $null
                TypeGuid              = $null
                TipoReal              = 'INDETERMINADO'
                StatusNaming          = 'INDETERMINADO'
                NomeCanonicoEsperado  = $null
                SourceFile            = $null
                Observacao            = "nenhum XML classificavel: $lastError"
            })
            continue
        }

        $status = $classified.StatusNaming
        if ($null -eq $status) {
            $status = if ($dir.Name -eq $classified.NomeCanonicoEsperado) { 'OK' } else { 'DIVERGENTE' }
        }

        $rows.Add([pscustomobject]@{
            Diretorio             = $dir.Name
            Root                  = $classified.Root
            TypeGuid              = $classified.TypeGuid
            TipoReal              = $classified.TipoReal
            StatusNaming          = $status
            NomeCanonicoEsperado  = if ($status -eq 'DIVERGENTE') { $classified.NomeCanonicoEsperado } else { $null }
            SourceFile            = $classified.SourceFile
            Observacao            = if ($status -eq 'TIPO_DESCONHECIDO') {
                if ($catalogResolution.OverrideActive) {
                    'GUID nao mapeado no catalogo efetivo (base + override); atualizar gx-object-type-catalog.override.json ou GeneXus-XPZ-Skills (gx-object-type-catalog.json + 01a)'
                } else {
                    'GUID nao mapeado no catalogo efetivo; atualizar GeneXus-XPZ-Skills (gx-object-type-catalog.json + 01a) ou registrar override local aprovado'
                }
            } else { $null }
        })
    }

    $divergentRows = @($rows | Where-Object { $_.StatusNaming -eq 'DIVERGENTE' })
    $indeterminedRows = @($rows | Where-Object { $_.StatusNaming -in @('INDETERMINADO', 'TIPO_DESCONHECIDO') })
    $statusText = if ($divergentRows.Count -gt 0) {
        'NAMING_DIVERGENT'
    } elseif ($indeterminedRows.Count -gt 0) {
        'NAMING_INDETERMINADO'
    } else {
        'NAMING_OK'
    }

    if ($AsJson) {
        [pscustomobject]@{
            status                 = $statusText
            divergent              = @($divergentRows | ForEach-Object { $_.Diretorio })
            all                    = @($rows)
            catalogBasePath        = $catalogResolution.BaseCatalogPath
            catalogOverridePath    = $catalogResolution.OverridePath
            catalogOverrideActive  = $catalogResolution.OverrideActive
            catalogUpstreamPending = $catalogResolution.UpstreamPending
            catalogDeclaredUpstreamPending = $catalogResolution.DeclaredUpstreamPending
            catalogEffectiveUpstreamPending = $catalogResolution.EffectiveUpstreamPending
            catalogOverrideClassification = $catalogResolution.OverrideClassification
        } | ConvertTo-Json -Depth 10
    } else {
        $rows |
            Select-Object Diretorio, Root, TypeGuid, TipoReal, StatusNaming, NomeCanonicoEsperado |
            Format-Table -AutoSize

        if ($divergentRows.Count -gt 0) {
            Write-Output ("NAMING_DIVERGENT: {0}" -f (($divergentRows | ForEach-Object { $_.Diretorio }) -join ','))
        } elseif ($indeterminedRows.Count -gt 0) {
            Write-Output ("NAMING_INDETERMINADO: {0}" -f (($indeterminedRows | ForEach-Object { $_.Diretorio }) -join ','))
        } else {
            Write-Output 'NAMING_OK'
        }
    }

    if ($divergentRows.Count -gt 0) {
        exit 1
    }

    exit 0
} catch {
    Write-StructuredError -Message $_.Exception.Message
    exit 2
}
