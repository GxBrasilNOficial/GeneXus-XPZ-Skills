#requires -Version 7.4
<#
.SYNOPSIS
    Compara os wrappers locais da pasta paralela com os exemplos canonicos do repositório de skills.

.DESCRIPTION
    Infere o prefixo KB a partir dos scripts presentes em scripts/, enumera os exemplos
    em SkillsExamplesPath (*.example.ps1) e verifica se cada wrapper esperado existe
    localmente. Quando a inferencia falha por scripts usarem naming curto (sem prefixo KB),
    tenta obter o nome da KB em kb-source-metadata.md e detecta se os scripts existem no
    padrão curto em vez do padrão canonico. Retorna:
      INVENTORY_OK                        - todos os wrappers canonicos presentes com naming padrão
      INVENTORY_GAPS: <nomes ausentes>    - wrappers ausentes (nem padrão nem curto encontrado)
      INVENTORY_SHORT_NAMING: <lista>     - wrappers existem no padrão curto; renomear para padrão
      INVENTORY_CUSTOMIZED: <lista>        - wrappers presentes com divergencia metodologica objetiva
                                            (ex: requires_version_mismatch; nos wrappers K8/K9
                                            Test-KbSetupAudit/Test-KbIndexGate, missing_AsJson_passthrough
                                            quando o molde repassa -AsJson e o wrapper local nao;
                                            forwards_unknown_engine_param quando o wrapper repassa a um
                                            motor compartilhado advanced um parametro nao-declarado;
                                            shared_engine_unresolved quando o caminho de motor inferido
                                            nao existe na base canonica; surface_mismatch quando o
                                            wrapper local PERDE contrato obrigatorio do molde
                                            (mandatory ausente/rebaixado, no_param_block com molde
                                            obrigatorio) — diff de superficie param()/ValidateSet;
                                            unsafe_last_exitcode_after_ps1_engine quando wrapper que
                                            chama motor PowerShell ainda sai por exit $LASTEXITCODE)
      INVENTORY_ENGINE_DIAGNOSTIC: <lista> - diagnostico brando (motor canonico ausente/parse-broken,
                                            engine_unresolved_or_unparseable); NAO bloqueia o estado de
                                            setup (rotulo fora dos tokens de pendencia do agregador)
      INVENTORY_SURFACE_ADVISORY: <lista>  - aviso de superficie: wrapper local defasado do molde por
                                            REDUCAO opcional (optional_param_missing,
                                            validateset_reduced, optional_promoted_to_mandatory,
                                            extra_mandatory_added, no_param_block com molde so-opcional);
                                            NAO bloqueia (rotulo fora dos tokens de pendencia do
                                            agregador); perda de obrigatorio sai em INVENTORY_CUSTOMIZED
      INVENTORY_RECOMMENDED_MISSING: <lista> - wrappers recomendados ausentes por sinais objetivos
      INVENTORY_LEGACY_ORPHANS: <lista>    - scripts legados lado a lado com canonicos atuais
      INVENTORY_UNKNOWN: <motivo>         - não foi possível determinar o estado

.PARAMETER KbParallelRoot
    Raiz da pasta paralela da KB.

.PARAMETER SkillsExamplesPath
    Caminho para a pasta examples/ do repositório de skills XPZ
    (xpz-kb-parallel-setup/examples).

.OUTPUTS
    String: "INVENTORY_OK", "INVENTORY_GAPS: <nomes ausentes>",
    "INVENTORY_SHORT_NAMING: <nomes esperados>",
    "INVENTORY_CUSTOMIZED: <nomes e motivos>",
    "INVENTORY_ENGINE_DIAGNOSTIC: <nomes e motivos>",
    "INVENTORY_SURFACE_ADVISORY: <nomes e motivos>",
    "INVENTORY_LEGACY_ORPHANS: <canonico(legacy=antigo)>",
    "INVENTORY_RECOMMENDED_MISSING: <nomes recomendados>", ou
    "INVENTORY_UNKNOWN: <motivo>"

.EXAMPLE
    .\Test-XpzWrapperInventory.ps1 `
        -KbParallelRoot "C:\DevTests\Gx_MyCinema" `
        -SkillsExamplesPath "C:\Dev\Knowledge\GeneXus-XPZ-Skills\xpz-kb-parallel-setup\examples"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbParallelRoot,

    [Parameter(Mandatory = $true)]
    [string]$SkillsExamplesPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Helper do check generico forwards_unknown_engine_param (resolve motor compartilhado por
# valor + AST; sem executar motor nem exigir KB). EnginesRoot = scripts/ do auditor ($PSScriptRoot).
. (Join-Path $PSScriptRoot 'XpzWrapperEngineParamSupport.ps1')

$scriptsPath = Join-Path $KbParallelRoot 'scripts'

function Get-RequiresVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $pattern = '^\s*#requires\s+-version\s+(?<version>\d+(\.\d+)*)\b'
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $match = [regex]::Match($line, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return $match.Groups['version'].Value
        }

        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) {
            continue
        }
        if ($trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed -eq '<#') {
            continue
        }

        break
    }

    return $null
}

if (-not (Test-Path -LiteralPath $scriptsPath -PathType Container)) {
    Write-Output "INVENTORY_UNKNOWN: pasta scripts nao encontrada em $KbParallelRoot"
    exit 0
}

if (-not (Test-Path -LiteralPath $SkillsExamplesPath -PathType Container)) {
    Write-Output "INVENTORY_UNKNOWN: pasta examples nao encontrada em $SkillsExamplesPath"
    exit 0
}

# Inferir prefixo KB a partir dos scripts existentes (ex: Test-MyCinemaKbIndexGate.ps1 -> MyCinema)
$kbPrefix = $null
foreach ($f in Get-ChildItem -LiteralPath $scriptsPath -Filter '*.ps1' -Name | Sort-Object) {
    if ($f -match '^[A-Za-z]+-([A-Za-z0-9]+)Kb[A-Za-z]') {
        $kbPrefix = $Matches[1]
        break
    }
}

# Quando a inferencia falha, tentar obter o nome da KB em kb-source-metadata.md
if ([string]::IsNullOrWhiteSpace($kbPrefix)) {
    $metadataPath = Join-Path $KbParallelRoot 'kb-source-metadata.md'
    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        $inSourceVersion = $false
        foreach ($line in [System.IO.File]::ReadAllLines($metadataPath)) {
            if ($line -match '^\s*kb_name\s*[:=]\s*(?<value>\S+)') {
                $candidate = $Matches['value'].Trim()
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $kbPrefix = $candidate; break
                }
            }
            if ($line -match '^\s*##\s+Source/Version') { $inSourceVersion = $true; continue }
            if ($inSourceVersion -and $line -match '^\s*##\s') { $inSourceVersion = $false }
            if ($inSourceVersion -and $line -match '^\s*\|\s*name\s*\|\s*(?<value>[^|]+)\|') {
                $candidate = $Matches['value'].Trim()
                if (-not [string]::IsNullOrWhiteSpace($candidate) -and $candidate -notmatch '^[-\s]+$') {
                    $kbPrefix = $candidate; break
                }
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($kbPrefix)) {
    Write-Output 'INVENTORY_UNKNOWN: nao foi possivel inferir o prefixo KB a partir dos scripts nem de kb-source-metadata.md'
    exit 0
}

$scriptNames = @(Get-ChildItem -LiteralPath $scriptsPath -Filter '*.ps1' -Name | Sort-Object)

function Test-FrontHistory {
    param([string]$RootPath)

    $generatedPath = Join-Path $RootPath 'ObjetosGeradosParaImportacaoNaKbNoGenexus'
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Container)) {
        return $false
    }

    $frontDirs = @(Get-ChildItem -LiteralPath $generatedPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'ArquivoMorto' })
    return $frontDirs.Count -gt 0
}

function Test-GeneratedLastUpdateHistory {
    param([string]$RootPath)

    $generatedPath = Join-Path $RootPath 'ObjetosGeradosParaImportacaoNaKbNoGenexus'
    if (-not (Test-Path -LiteralPath $generatedPath -PathType Container)) {
        return $false
    }

    foreach ($xmlFile in Get-ChildItem -LiteralPath $generatedPath -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue) {
        $content = [System.IO.File]::ReadAllText($xmlFile.FullName)
        if ($content -match '\blastUpdate\b') {
            return $true
        }
    }

    return $false
}

function Test-ImportPackageHistory {
    param([string]$RootPath)

    $packagesPath = Join-Path $RootPath 'PacotesGeradosParaImportacaoNaKbNoGenexus'
    if (-not (Test-Path -LiteralPath $packagesPath -PathType Container)) {
        return $false
    }

    $packages = @(Get-ChildItem -LiteralPath $packagesPath -File -Filter '*.import_file.xml' -ErrorAction SilentlyContinue)
    return $packages.Count -gt 0
}

function Test-KbIdentityMetadata {
    param([string]$RootPath)

    $metadataPath = Join-Path $RootPath 'kb-source-metadata.md'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $false
    }

    $metadataText = [System.IO.File]::ReadAllText($metadataPath)
    return $metadataText -match '(?i)(\bkb\s*\(GUID\)|\bsource_guid\b|\bUNCPath\b|\busername\b|\bversionGuid\b|\bVersion/guid\b)'
}

$recommendedEvidenceByBaseName = @{
    'New-KbFront' = (Test-FrontHistory -RootPath $KbParallelRoot)
    'Get-KbLastUpdate' = (Test-GeneratedLastUpdateHistory -RootPath $KbParallelRoot)
    'New-KbImportPackage' = (Test-ImportPackageHistory -RootPath $KbParallelRoot)
    'Resolve-KbIdentity' = (Test-KbIdentityMetadata -RootPath $KbParallelRoot)
    'Resolve-KbGeneratedCsPath' = $false
}

# Mapear cada exemplo para o nome local esperado e verificar presenca
$absent      = [System.Collections.Generic.List[string]]::new()
$shortNaming = [System.Collections.Generic.List[string]]::new()
$customized  = [System.Collections.Generic.List[string]]::new()
$recommendedMissing = [System.Collections.Generic.List[string]]::new()
$legacyOrphans = [System.Collections.Generic.List[string]]::new()
$engineDiagnostics = [System.Collections.Generic.List[string]]::new()
$surfaceAdvisory = [System.Collections.Generic.List[string]]::new()
$optionalBaseNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$optionalBaseNames.Add('New-KbImportPackage')
[void]$optionalBaseNames.Add('New-KbFront')
[void]$optionalBaseNames.Add('Get-KbLastUpdate')
[void]$optionalBaseNames.Add('Notify-TaskComplete')
[void]$optionalBaseNames.Add('Resolve-KbIdentity')
[void]$optionalBaseNames.Add('Resolve-KbGeneratedCsPath')
$requiresVersionExemptBaseNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$requiresVersionExemptBaseNames.Add('Test-KbPowerShellRuntime')

foreach ($exampleFile in Get-ChildItem -LiteralPath $SkillsExamplesPath -Filter '*.example.ps1' -Name | Sort-Object) {
    $baseName = $exampleFile -replace '\.example\.ps1$', ''

    if ($baseName -match '^([A-Za-z]+-)(Kb.+)$') {
        $standardLocalName = "$($Matches[1])${kbPrefix}$($Matches[2]).ps1"
        $shortLocalName    = "$baseName.ps1"
    } else {
        $standardLocalName = "$baseName.ps1"
        $shortLocalName    = $null
    }

    $standardPath   = Join-Path $scriptsPath $standardLocalName
    $examplePath    = Join-Path $SkillsExamplesPath $exampleFile
    $standardExists = Test-Path -LiteralPath $standardPath -PathType Leaf
    $shortExists    = $shortLocalName -and (Test-Path -LiteralPath (Join-Path $scriptsPath $shortLocalName) -PathType Leaf)

    if ($standardExists) {
        if ($shortExists) {
            $legacyOrphans.Add(('{0}(legacy={1})' -f $standardLocalName, $shortLocalName))
        }

        if ($standardLocalName -match '^([A-Za-z]+-)(' + [regex]::Escape($kbPrefix) + ')Kb(.+\.ps1)$') {
            $legacyLocalName = "$($Matches[1])$($Matches[2])$($Matches[3])"
            if ($scriptNames -contains $legacyLocalName) {
                $legacyOrphans.Add(('{0}(legacy={1})' -f $standardLocalName, $legacyLocalName))
            }
        }

        if (-not $requiresVersionExemptBaseNames.Contains($baseName)) {
            $canonicalRequiresVersion = Get-RequiresVersion -Path $examplePath
            $localRequiresVersion = Get-RequiresVersion -Path $standardPath
            if ($canonicalRequiresVersion -and $localRequiresVersion -ne $canonicalRequiresVersion) {
                $localLabel = if ($localRequiresVersion) { $localRequiresVersion } else { 'ausente' }
                $customized.Add(('{0}(reason=requires_version_mismatch: local={1} canonical={2})' -f $standardLocalName, $localLabel, $canonicalRequiresVersion))
            }
        }

        if ($baseName -ieq 'Set-KbSourceMetadataDeployment') {
            $exampleText = [System.IO.File]::ReadAllText($examplePath)
            $localText = [System.IO.File]::ReadAllText($standardPath)
            if ($localText -match 'InventoryFromKbNativePath|InventoryFromGeneXusMsBuild') {
                $customized.Add(('{0}(reason=uses_removed_inventory_discovery)' -f $standardLocalName))
            } elseif ($exampleText -match 'KbEnvironmentNames' -and $localText -notmatch 'KbEnvironmentNames') {
                $customized.Add(('{0}(reason=missing_KbEnvironmentNames)' -f $standardLocalName))
            } elseif ($exampleText -match 'KbEnvironmentOutputDirs' -and $localText -notmatch 'KbEnvironmentOutputDirs') {
                $customized.Add(('{0}(reason=missing_KbEnvironmentOutputDirs)' -f $standardLocalName))
            } elseif ($exampleText -match 'KbNativePath' -and $localText -notmatch 'KbNativePath') {
                $customized.Add(('{0}(reason=missing_KbNativePath_for_msbuild_validation)' -f $standardLocalName))
            } elseif ($exampleText -match 'InventoryWorkingDirectory' -and $localText -notmatch 'InventoryWorkingDirectory') {
                $customized.Add(('{0}(reason=missing_InventoryWorkingDirectory_for_msbuild_validation)' -f $standardLocalName))
            }
        }

        if ($baseName -ieq 'Test-KbSetupAudit' -or $baseName -ieq 'Test-KbIndexGate') {
            $exampleText = [System.IO.File]::ReadAllText($examplePath)
            $localText = [System.IO.File]::ReadAllText($standardPath)
            # Detecta o REPASSE de -AsJson ao motor, nao a mera mencao do termo: um
            # wrapper com `[switch]$AsJson` declarado mas sem repasse (migracao parcial)
            # tem 'AsJson' no texto mas ainda bloqueia K8/K9. Os dois moldes repassam de
            # formas distintas, ambas cobertas: setup-audit via `-AsJson:$AsJson` (token
            # `-AsJson`); index-gate via `$forward['AsJson']` (chave entre aspas). O param
            # `$AsJson` sozinho nao casa nenhum dos dois.
            if ($exampleText -match 'AsJson' -and $localText -notmatch '(-AsJson|[''"]AsJson)') {
                $customized.Add(('{0}(reason=missing_AsJson_passthrough)' -f $standardLocalName))
            }
        }

        if ($baseName -ieq 'Update-KbFromXpz') {
            $exampleText = [System.IO.File]::ReadAllText($examplePath)
            $localText = [System.IO.File]::ReadAllText($standardPath)
            # Drift de contrato de CONSUMO do motor: o molde canonico consome o stdout do
            # Sync-GeneXusXpzToXml.ps1 como contrato JSON v1 (ConvertFrom-Json). Um wrapper
            # local que ainda trata esse stdout como TEXTO (sem ConvertFrom-Json) consome a
            # forma de saida defasada e, sem este check, passaria como nao-customizado. Mesma
            # mecanica heuristica (texto local vs molde) do precedente missing_AsJson_passthrough:
            # marca quando o molde consome JSON e o local nao. LIMITE CONHECIDO (heuristica
            # textual conservadora, nao prova de conformidade): nao detecta migracao parcial
            # (ConvertFrom-Json presente num ramo mas stdout consumido como texto em outro) nem
            # parsers alternativos (System.Text.Json, Invoke-RestMethod). Esses casos sao materia
            # do follow-up de versao-de-contrato (Kind/SchemaVersion) no 999-ideias-pendentes.md.
            if ($exampleText -match 'ConvertFrom-Json' -and $localText -notmatch 'ConvertFrom-Json') {
                $customized.Add(('{0}(reason=consumes_legacy_text_stdout)' -f $standardLocalName))
            }
        }

        $localTextForEngineExit = [System.IO.File]::ReadAllText($standardPath)
        # Motores compartilhados e wrappers auxiliares locais sao .ps1; chamada PowerShell
        # bem-sucedida nao garante $LASTEXITCODE definido, e valor antigo pode vazar. Sob
        # StrictMode, `exit $LASTEXITCODE` pode falhar ou devolver codigo obsoleto depois de
        # executar o motor. O molde atual zera $global:LASTEXITCODE antes da chamada e consulta
        # a variavel via Get-Variable, preservando `$?` como fallback.
        if (
            $localTextForEngineExit -match '&\s+\$(enginePath|engineScript|engine|PowerShellRuntimeWrapperPath)\b' -and
            $localTextForEngineExit -match 'exit\s+\$LASTEXITCODE\b'
        ) {
            $customized.Add(('{0}(reason=unsafe_last_exitcode_after_ps1_engine)' -f $standardLocalName))
        }

        # Check generico: parametro repassado a motor compartilhado advanced que o motor nao
        # declara (forwards_unknown_engine_param), caminho de motor inexistente
        # (shared_engine_unresolved) -> desvios-de-wrapper, viram INVENTORY_CUSTOMIZED (capturado
        # pelo agregador). Motor canonico irresoluvel/parse-broken -> INVENTORY_ENGINE_DIAGNOSTIC
        # (infra do repo de skills; nao bloqueia estado de pasta paralela).
        $engineParamFinding = Get-XpzWrapperEngineParamFinding -WrapperPath $standardPath -EnginesRoot $PSScriptRoot
        foreach ($sig in $engineParamFinding.Signals) {
            $customized.Add(('{0}(reason={1}: {2})' -f $standardLocalName, $sig.Reason, $sig.Detail))
        }
        foreach ($diag in $engineParamFinding.EngineDiagnostics) {
            $engineDiagnostics.Add(('{0}(reason={1}: {2})' -f $standardLocalName, $diag.Reason, $diag.Detail))
        }

        # Diff de superficie wrapper-local vs molde canonico (helper Get-XpzWrapperSurfaceFinding,
        # direcao wrapper->molde, complementar ao forwards_unknown_engine_param acima). PERDA de
        # contrato obrigatorio (mandatory ausente/rebaixado; no_param_block com molde obrigatorio)
        # -> INVENTORY_CUSTOMIZED reason=surface_mismatch (capturado pelo agregador). Reducoes
        # opcionais/ValidateSet -> INVENTORY_SURFACE_ADVISORY (rotulo proprio, FORA do regex de
        # pendencia do agregador -> nao bloqueia). Excedente/delegacao legitima -> quieto. Coexiste
        # com os checks por-token acima (redundancia aceita, nao deduplicar).
        $surfaceFinding = Get-XpzWrapperSurfaceFinding -MoldePath $examplePath -LocalPath $standardPath
        foreach ($b in $surfaceFinding.Blocking) {
            $blockDetail = if ($b.Detail) { '{0} {1}' -f $b.Reason, $b.Detail } else { [string]$b.Reason }
            $customized.Add(('{0}(reason=surface_mismatch: {1})' -f $standardLocalName, $blockDetail))
        }
        foreach ($a in $surfaceFinding.Advisory) {
            $advBody = if ($a.Detail) { '{0}: {1}' -f $a.Reason, $a.Detail } else { [string]$a.Reason }
            $surfaceAdvisory.Add(('{0}(reason={1})' -f $standardLocalName, $advBody))
        }
    } elseif ($shortExists) {
        $shortNaming.Add($standardLocalName)
    } elseif ($optionalBaseNames.Contains($baseName)) {
        if ($recommendedEvidenceByBaseName.ContainsKey($baseName) -and $recommendedEvidenceByBaseName[$baseName]) {
            $recommendedMissing.Add($standardLocalName)
        }
    } else {
        $absent.Add($standardLocalName)
    }
}

$knownLegacyPairs = @(
    @{
        Canonical = ('Test-{0}KbFullSnapshot.ps1' -f $kbPrefix)
        Legacy = ('Test-{0}FullSnapshot.ps1' -f $kbPrefix)
    },
    @{
        Canonical = ('Update-{0}KbFromXpz.ps1' -f $kbPrefix)
        Legacy = ('Update-{0}FromXpz.ps1' -f $kbPrefix)
    },
    @{
        Canonical = ('Test-{0}KbIndexGate.ps1' -f $kbPrefix)
        Legacy = ('Test-{0}KbGate.ps1' -f $kbPrefix)
    }
)
foreach ($knownLegacyPair in $knownLegacyPairs) {
    if (($scriptNames -contains $knownLegacyPair.Canonical) -and ($scriptNames -contains $knownLegacyPair.Legacy)) {
        $entry = '{0}(legacy={1})' -f $knownLegacyPair.Canonical, $knownLegacyPair.Legacy
        if (-not $legacyOrphans.Contains($entry)) {
            $legacyOrphans.Add($entry)
        }
    }
}

$statusParts = [System.Collections.Generic.List[string]]::new()
if ($shortNaming.Count -gt 0) {
    $statusParts.Add("INVENTORY_SHORT_NAMING: $($shortNaming -join ', ')")
}
if ($customized.Count -gt 0) {
    $statusParts.Add("INVENTORY_CUSTOMIZED: $($customized -join ', ')")
}
if ($legacyOrphans.Count -gt 0) {
    $statusParts.Add("INVENTORY_LEGACY_ORPHANS: $($legacyOrphans -join ', ')")
}
if ($absent.Count -gt 0) {
    $statusParts.Add("INVENTORY_GAPS: $($absent -join ', ')")
}
if ($recommendedMissing.Count -gt 0) {
    $statusParts.Add("INVENTORY_RECOMMENDED_MISSING: $($recommendedMissing -join ', ')")
}
if ($engineDiagnostics.Count -gt 0) {
    # Canal brando: rotulo deliberadamente FORA dos 4 tokens do regex de pendencia do
    # agregador (Test-XpzSetupAudit.ps1) -> nao bloqueia o estado de pasta paralela.
    $statusParts.Add("INVENTORY_ENGINE_DIAGNOSTIC: $($engineDiagnostics -join ', ')")
}
if ($surfaceAdvisory.Count -gt 0) {
    # Canal de aviso de superficie: rotulo deliberadamente FORA dos 4 tokens do regex de
    # pendencia do agregador (Test-XpzSetupAudit.ps1) -> nao bloqueia o estado de pasta paralela.
    # So reducao opcional/ValidateSet/no_param_block-opcional; a perda de contrato obrigatorio ja
    # saiu em INVENTORY_CUSTOMIZED (reason=surface_mismatch) acima.
    $statusParts.Add("INVENTORY_SURFACE_ADVISORY: $($surfaceAdvisory -join ', ')")
}

if ($statusParts.Count -eq 0) {
    Write-Output 'INVENTORY_OK'
} else {
    Write-Output ($statusParts -join ' | ')
}
exit 0
