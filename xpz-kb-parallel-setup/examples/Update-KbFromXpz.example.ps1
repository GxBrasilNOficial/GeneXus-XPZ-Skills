#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para atualizar `ObjetosDaKbEmXml` a partir de um XPZ/XML da KB.

.DESCRIPTION
Usa os caminhos da pasta paralela da KB e delega a extração/verificação para o
motor compartilhado desta base metodológica.

.PARAMETER InputPath
Caminho para um .xpz, para o XML do pacote exportado ou para a pasta que contém
esse XML.

.PARAMETER VerifyOnly
Executa apenas conferência, sem regravar arquivos no destino.

.PARAMETER FullSnapshot
Além da conferência do pacote atual, compara o snapshot inteiro do destino com o
conteúdo do pacote. Use este modo para exports completos da KB.

.PARAMETER ReportPath
Caminho opcional para salvar um relatório JSON com o resultado.

.PARAMETER KeepReport
Mantém o relatório JSON mesmo quando a execução termina sem erro.

.PARAMETER KbMetadataPath
Caminho opcional para salvar metadados da KB em Markdown.
Quando omitido, o wrapper usa `kb-source-metadata.md` na raiz da pasta
paralela da KB. Com `-KbMetadataPath` ativo, o motor compartilhado faz
atualizacao **cirurgica** dos campos de materialização, preservando
`last_setup_audit_run_at`, `setup_contract_signature_*` e o frontmatter fora do escopo.

.PARAMETER IndexUpdateScriptPath
Caminho opcional do wrapper local que regenera o índice derivado após
materialização bem-sucedida. Quando omitido, usa
`Rebuild-KbIntelligenceIndex.ps1` na mesma pasta deste wrapper.

.PARAMETER IndexValidationCasesPath
Caminho opcional para casos de validação usados no refresh compulsorio do
índice.

.PARAMETER NoGitSummary
Suprime resumo local de alterações Git em `ObjetosDaKbEmXml`.

.PARAMETER ExpectedItems
Lista opcional de itens esperados no formato `Tipo:Nome`, repassada ao motor
compartilhado para comparar foco esperado versus retorno oficial da KB. Ao
invocar via `pwsh -File` a partir de Bash/CMD, prefira string única separada
por vírgula para evitar ambiguidade de parser entre shells.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`. Use este parâmetro quando
o wrapper sanitizado for adaptado para um ambiente com outro caminho local.

.NOTES
Contrato de conclusao (rigor KbIntelligence; ver xpz-sync e README da base):
- Sucesso: materialização XPZ/XML em ObjetosDaKbEmXml e refresh do índice concluidos (exit 0).
- Falha com mensagem PREREQUISITO AUSENTE: Python 3 utilizavel ausente no rebuild
  (motor Build-KbIntelligenceIndex.ps1 retorna exit 8). A materialização pode ter
  concluido; o fluxo oficial ainda falhou porque o índice não foi regenerado.
  Não tratar como falha do pacote exportado. Instalar Python 3.x e rerodar
  Rebuild-KbIntelligenceIndex.ps1 antes de triagem ampla ou declaracao de sync OK.
- Outras falhas: erro de materialização ou do motor do índice (não confundir com Python ausente).

.EXAMPLE
.\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente'

.EXAMPLE
.\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente', 'Procedure:GeraBoleto'

.EXAMPLE
pwsh -NoProfile -File .\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente,Procedure:GeraBoleto'
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [switch]$VerifyOnly,

    [switch]$FullSnapshot,

    [string]$ReportPath,

    [switch]$KeepReport,

    [string]$KbMetadataPath,

    [string]$IndexUpdateScriptPath,

    [string]$IndexValidationCasesPath,

    [string[]]$ExpectedItems = @(),

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills",

    [switch]$NoGitSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Diagnostico humano vai para o STDERR, nunca para o stdout. Quando este wrapper roda como
# processo filho (pwsh -File) e o chamador captura o stdout para `ConvertFrom-Json`, os
# streams Host/Warning/Information do filho VAZAM para esse stdout (medido empiricamente);
# so [Console]::Error (fd 2) fica de fora. Contrato: stdout = exclusivamente a linha JSON
# do motor (re-emitida ao final); todo o resto (resumos, avisos) sai por aqui.
function Write-HumanLine {
    param([string]$Message = '')
    [Console]::Error.WriteLine($Message)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\Sync-GeneXusXpzToXml.ps1"
$destinationRoot = Join-Path $repoRoot "ObjetosDaKbEmXml"

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

$pythonPrerequisiteScript = Join-Path $SharedSkillsRoot 'scripts/GeneXusPythonPrerequisite.ps1'
if (-not (Test-Path -LiteralPath $pythonPrerequisiteScript -PathType Leaf)) {
    throw "Shared prerequisite script not found: $pythonPrerequisiteScript"
}

. $pythonPrerequisiteScript

$reminderScriptPath = Join-Path $SharedSkillsRoot 'scripts\Test-XpzCatalogOverrideSessionReminder.ps1'
if (Test-Path -LiteralPath $reminderScriptPath -PathType Leaf) {
    $reminderResult = & $reminderScriptPath -ParallelKbRoot $repoRoot -AsJson | ConvertFrom-Json
    if ($reminderResult.noticeRequired -and -not [string]::IsNullOrWhiteSpace($reminderResult.message)) {
        Write-HumanLine ("AVISO: " + $reminderResult.message)
    }
}

if (-not $VerifyOnly) {
    $inventoryScriptPath = Join-Path $SharedSkillsRoot 'scripts\Get-GeneXusImportPackageObjectInventory.ps1'
    if (Test-Path -LiteralPath $inventoryScriptPath -PathType Leaf) {
        $global:LASTEXITCODE = $null
        $null = & $inventoryScriptPath -InputPath $InputPath -ParallelKbRoot $repoRoot -FailOnUnknownTypes 2>&1
        $inventorySucceeded = $?
        $inventoryExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
        $inventoryExitCode = if ($null -ne $inventoryExitCodeVariable -and $inventoryExitCodeVariable.Value -is [int]) {
            $inventoryExitCodeVariable.Value
        } elseif ($inventorySucceeded) {
            0
        } else {
            1
        }
        if ($inventoryExitCode -eq 3) {
            throw 'Pre-varredura bloqueada: tipos nao mapeados no catalogo efetivo (base + override). Resolver antes de materializar; ver xpz-sync e 08-guia-para-agente-gpt.md.'
        }
    }
}

function Invoke-IndexRefresh {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string]$SharedSkillsRoot,

        [string]$ValidationCasesPath
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Index refresh wrapper not found: $ScriptPath"
    }

    $rebuildParams = @{
        SharedSkillsRoot = $SharedSkillsRoot
    }

    if ($ValidationCasesPath) {
        $rebuildParams.ValidationCasesPath = $ValidationCasesPath
        $rebuildParams.FailOnValidationFailure = $true
    }

    Write-HumanLine ""
    Write-HumanLine "Refreshing KbIntelligence index after XPZ/XML materialization..."

    $prefix = 'Index refresh failed after XPZ/XML materialization. A materializacao XPZ/XML foi concluida; apenas o indice KbIntelligence nao foi gerado.'

    try {
        $global:LASTEXITCODE = $null
        & $ScriptPath @rebuildParams
        $rebuildSucceeded = $?
        $rebuildExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
        $rebuildExitCode = if ($null -ne $rebuildExitCodeVariable -and $rebuildExitCodeVariable.Value -is [int]) {
            $rebuildExitCodeVariable.Value
        } elseif ($rebuildSucceeded) {
            0
        } else {
            1
        }
        if ($rebuildExitCode -ne 0) {
            if ($rebuildExitCode -eq 8) {
                throw "$(Get-GeneXusPythonPrerequisiteErrorMessage)"
            }

            throw "Falha no rebuild do indice (exit $rebuildExitCode)."
        }
    } catch {
        if ($_.Exception.Message -match '^PREREQUISITO AUSENTE:') {
            throw "$prefix $($_.Exception.Message)"
        }

        throw "$prefix $($_.Exception.Message)"
    }
}

function Show-LocalGitSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$PathFilter
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-HumanLine "AVISO: git nao encontrado; resumo local de alteracoes foi ignorado."
        return
    }

    if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".git"))) {
        Write-HumanLine "AVISO: repositorio Git nao encontrado em $RepositoryRoot; resumo local foi ignorado."
        return
    }

    $statusLines = @(git -C $RepositoryRoot status --short -- $PathFilter 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Write-HumanLine "AVISO: nao foi possivel obter git status para $PathFilter."
        return
    }

    if ($statusLines.Count -eq 0) {
        Write-HumanLine ""
        Write-HumanLine "Git summary (`"$PathFilter`"): sem alteracoes locais pendentes."
        return
    }

    $modifiedCount  = @($statusLines | Where-Object { $_ -match '^( M|M |MM|AM|RM| T|MT|TM)' }).Count
    $addedCount     = @($statusLines | Where-Object { $_ -match '^(A | A|AA)' }).Count
    $deletedCount   = @($statusLines | Where-Object { $_ -match '^( D|D |DD|AD|DA)' }).Count
    $renamedCount   = @($statusLines | Where-Object { $_ -match '^(R | R|RR)' }).Count
    $untrackedCount = @($statusLines | Where-Object { $_ -match '^\?\?' }).Count

    Write-HumanLine ""
    Write-HumanLine ("Git summary (`"{0}`"):" -f $PathFilter)
    Write-HumanLine ("  Modified : {0}" -f $modifiedCount)
    Write-HumanLine ("  Added    : {0}" -f $addedCount)
    Write-HumanLine ("  Deleted  : {0}" -f $deletedCount)
    Write-HumanLine ("  Renamed  : {0}" -f $renamedCount)
    Write-HumanLine ("  Untracked: {0}" -f $untrackedCount)
    Write-HumanLine ""
    Write-HumanLine "Changed paths:"
    $statusLines | ForEach-Object { Write-HumanLine ("  {0}" -f $_) }
}

function Get-ResultValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $true)]
        [object]$DefaultValue
    )

    if ($null -eq $Result) {
        return $DefaultValue
    }

    $prop = $Result.PSObject.Properties[$PropertyName]
    if ($null -eq $prop) {
        return $DefaultValue
    }

    return $prop.Value
}

function Remove-RenamedObjectResidue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $xmlFiles = Get-ChildItem -Path $RootPath -Recurse -File -Filter *.xml
    $objectInfos = New-Object System.Collections.Generic.List[object]

    foreach ($file in $xmlFiles) {
        try {
            $firstMeaningfulLine = Get-Content -Path $file.FullName -TotalCount 2 | Select-Object -Last 1
            if ($null -eq $firstMeaningfulLine -or $firstMeaningfulLine -notmatch '^<Object ') {
                continue
            }

            $guidMatch = [regex]::Match($firstMeaningfulLine, ' guid="([^"]+)"')
            if (-not $guidMatch.Success) {
                continue
            }

            $nameMatch = [regex]::Match($firstMeaningfulLine, ' name="([^"]+)"')
            $lastUpdateMatch = [regex]::Match($firstMeaningfulLine, ' lastUpdate="([^"]+)"')

            $parsedLastUpdate = [datetime]::MinValue
            if ($lastUpdateMatch.Success) {
                [datetime]::TryParse($lastUpdateMatch.Groups[1].Value, [ref]$parsedLastUpdate) | Out-Null
            }

            $objectInfos.Add([pscustomobject]@{
                Guid = $guidMatch.Groups[1].Value
                Name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { "" }
                LastUpdate = $parsedLastUpdate
                FullName = $file.FullName
                BaseName = $file.BaseName
            })
        } catch {
            Write-HumanLine ("AVISO: falha ao inspecionar {0}: {1}" -f $file.FullName, $_.Exception.Message)
        }
    }

    $removedFiles = New-Object System.Collections.Generic.List[string]

    foreach ($group in ($objectInfos | Group-Object Guid | Where-Object { $_.Count -gt 1 })) {
        $ordered = @(
            $group.Group |
            Sort-Object `
                @{ Expression = { if ($_.Name -and $_.BaseName -eq $_.Name) { 1 } else { 0 } }; Descending = $true }, `
                @{ Expression = { $_.LastUpdate }; Descending = $true }, `
                @{ Expression = { $_.FullName }; Descending = $false }
        )

        $keep = $ordered[0]
        $toRemove = @($ordered | Select-Object -Skip 1)

        foreach ($item in $toRemove) {
            Remove-Item -LiteralPath $item.FullName -Force
            $removedFiles.Add($item.FullName)
            Write-HumanLine ("Removed renamed-object residue: {0} (guid {1}); kept {2}" -f $item.FullName, $item.Guid, $keep.FullName)
        }
    }

    return $removedFiles
}

if (-not $KbMetadataPath) {
    $KbMetadataPath = Join-Path $repoRoot "kb-source-metadata.md"
}

if (-not $IndexUpdateScriptPath) {
    $IndexUpdateScriptPath = Join-Path $PSScriptRoot "Rebuild-KbIntelligenceIndex.ps1"
    if (-not (Test-Path -LiteralPath $IndexUpdateScriptPath)) {
        throw "Local index refresh wrapper not found: $IndexUpdateScriptPath. Generate or update the local final wrapper before normal XPZ/XML sync."
    }
}

$params = @{
    InputPath        = $InputPath
    DestinationRoot  = $destinationRoot
    KbMetadataPath   = $KbMetadataPath
    ParallelKbRoot   = $repoRoot
}

if ($VerifyOnly) {
    $params.VerifyOnly = $true
}

if ($FullSnapshot) {
    $params.FullSnapshot = $true
}

if ($ReportPath) {
    $params.ReportPath = $ReportPath
}

if ($KeepReport) {
    $params.KeepReport = $true
}

if ($ExpectedItems.Count -gt 0) {
    $params.ExpectedItems = @($ExpectedItems)
}

# O motor emite no stdout uma unica linha JSON (-Compress). Invocado in-process via &,
# $rawResult e essa string; parseamos para objeto para a logica abaixo. Se o motor falhar
# antes de emitir o JSON, ele lanca (ErrorActionPreference=Stop aborta aqui) e o JSON-em-falha
# so e recuperavel pelo agente que captura stdout+exitcode, nao por este wrapper.
$rawResult = & $enginePath @params
$result = $null
if ($null -ne $rawResult) {
    try {
        $result = $rawResult | ConvertFrom-Json
    } catch {
        throw "Falha ao parsear o JSON de saida do motor Sync-GeneXusXpzToXml.ps1: $($_.Exception.Message). Saida bruta: $rawResult"
    }
}

$removedRenameResidue = @()
if (-not $VerifyOnly) {
    $removedRenameResidue = @(Remove-RenamedObjectResidue -RootPath $destinationRoot)
    Invoke-IndexRefresh `
        -ScriptPath $IndexUpdateScriptPath `
        -SharedSkillsRoot $SharedSkillsRoot `
        -ValidationCasesPath $IndexValidationCasesPath
}

$shouldShowGitSummary = -not $NoGitSummary
if ($shouldShowGitSummary -and $null -ne $result) {
    $created = [int](Get-ResultValue -Result $result -PropertyName "Created" -DefaultValue 0)
    $updated = [int](Get-ResultValue -Result $result -PropertyName "Updated" -DefaultValue 0)
    $normalizedFileNames = [int](Get-ResultValue -Result $result -PropertyName "NormalizedFileNames" -DefaultValue 0)
    # FullSnapshotMissing/Extra sao CONTADORES (int) ou null no summary, nao arrays: ler como
    # [int] e comparar > 0. Envolver em @(...).Count daria @(0).Count == 1 -> sempre verdadeiro.
    $fullSnapshotMissing = [int](Get-ResultValue -Result $result -PropertyName "FullSnapshotMissing" -DefaultValue 0)
    $fullSnapshotExtra = [int](Get-ResultValue -Result $result -PropertyName "FullSnapshotExtra" -DefaultValue 0)
    # Uma rodada so com renames tambem e mudanca material (RenamedByGuid aplica; em VerifyOnly
    # RenameResidualsDetected sinaliza acervo desatualizado).
    $renamedByGuid = [int](Get-ResultValue -Result $result -PropertyName "RenamedByGuid" -DefaultValue 0)
    $renameResidualsDetected = [int](Get-ResultValue -Result $result -PropertyName "RenameResidualsDetected" -DefaultValue 0)

    $hasMaterialChange = ($created -gt 0) -or ($updated -gt 0) -or
        ($normalizedFileNames -gt 0) -or ($fullSnapshotMissing -gt 0) -or
        ($fullSnapshotExtra -gt 0) -or ($renamedByGuid -gt 0) -or
        ($renameResidualsDetected -gt 0) -or ($removedRenameResidue.Count -gt 0)
    if (-not $hasMaterialChange) {
        $shouldShowGitSummary = $false
    }
}

# stdout: exclusivamente a linha JSON do motor, re-emitida byte-a-byte (sem re-serializar,
# para nao introduzir drift de formatacao/ordem). Todo diagnostico humano sai por stderr.
$rawResult

if ($removedRenameResidue.Count -gt 0) {
    Write-HumanLine ""
    Write-HumanLine ("RemovedRenameResidue      : {0}" -f $removedRenameResidue.Count)
}

if ($shouldShowGitSummary) {
    Show-LocalGitSummary -RepositoryRoot $repoRoot -PathFilter "ObjetosDaKbEmXml"
}
