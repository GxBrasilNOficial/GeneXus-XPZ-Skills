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
Quando omitido, o wrapper grava `kb-source-metadata.md` na raiz da pasta
paralela da KB.

.PARAMETER IndexUpdateScriptPath
Caminho opcional do wrapper local que regenera o indice derivado apos
materializacao bem-sucedida. Quando omitido, usa
`Rebuild-KbIntelligenceIndex.ps1` na mesma pasta deste wrapper.

.PARAMETER IndexValidationCasesPath
Caminho opcional para casos de validacao usados no refresh compulsorio do
indice.

.PARAMETER NoGitSummary
Suprime resumo local de alterações Git em `ObjetosDaKbEmXml`.

.PARAMETER ExpectedItems
Lista opcional de itens esperados no formato `Tipo:Nome`, repassada ao motor
compartilhado para comparar foco esperado versus retorno oficial da KB.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`. Use este parâmetro quando
o wrapper sanitizado for adaptado para um ambiente com outro caminho local.

.EXAMPLE
.\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente'

.EXAMPLE
.\Update-KbFromXpz.ps1 -InputPath C:\Exports\MeuPacote.xpz -ExpectedItems 'Transaction:Cliente', 'Procedure:GeraBoleto'
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

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\Sync-GeneXusXpzToXml.ps1"
$destinationRoot = Join-Path $repoRoot "ObjetosDaKbEmXml"

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
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

    $powerShellCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -eq $powerShellCommand) {
        $powerShellCommand = Get-Command powershell -ErrorAction SilentlyContinue
    }
    if ($null -eq $powerShellCommand) {
        throw "PowerShell executable not found for index refresh."
    }
    $powerShellPath = $powerShellCommand.Source

    $arguments = @(
        "-NoProfile",
        "-File",
        $ScriptPath,
        "-SharedSkillsRoot",
        $SharedSkillsRoot
    )

    if ($ValidationCasesPath) {
        $arguments += @(
            "-ValidationCasesPath",
            $ValidationCasesPath,
            "-FailOnValidationFailure"
        )
    }

    Write-Host ""
    Write-Host "Refreshing KbIntelligence index after XPZ/XML materialization..." -ForegroundColor Cyan
    & $powerShellPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Index refresh failed after XPZ/XML materialization. Exit code: $LASTEXITCODE"
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
        Write-Warning "git nao encontrado; resumo local de alteracoes foi ignorado."
        return
    }

    if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".git"))) {
        Write-Warning "repositorio Git nao encontrado em $RepositoryRoot; resumo local foi ignorado."
        return
    }

    $statusLines = @(git -C $RepositoryRoot status --short -- $PathFilter 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "nao foi possivel obter git status para $PathFilter."
        return
    }

    if ($statusLines.Count -eq 0) {
        Write-Host ""
        Write-Host "Git summary (`"$PathFilter`"): sem alteracoes locais pendentes." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "Git summary (`"$PathFilter`"):" -ForegroundColor Cyan
    $statusLines | ForEach-Object { Write-Host ("  {0}" -f $_) }
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
            Write-Warning ("falha ao inspecionar {0}: {1}" -f $file.FullName, $_.Exception.Message)
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
            Write-Host ("Removed renamed-object residue: {0} (guid {1}); kept {2}" -f $item.FullName, $item.Guid, $keep.FullName) -ForegroundColor Yellow
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
    InputPath       = $InputPath
    DestinationRoot = $destinationRoot
    KbMetadataPath  = $KbMetadataPath
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

$result = & $enginePath @params

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
    $fullSnapshotMissing = @(Get-ResultValue -Result $result -PropertyName "FullSnapshotMissing" -DefaultValue @())
    $fullSnapshotExtra = @(Get-ResultValue -Result $result -PropertyName "FullSnapshotExtra" -DefaultValue @())

    $hasMaterialChange = ($created -gt 0) -or ($updated -gt 0) -or
        ($normalizedFileNames -gt 0) -or ($fullSnapshotMissing.Count -gt 0) -or
        ($fullSnapshotExtra.Count -gt 0) -or ($removedRenameResidue.Count -gt 0)
    if (-not $hasMaterialChange) {
        $shouldShowGitSummary = $false
    }
}

$result

if ($removedRenameResidue.Count -gt 0) {
    Write-Host ""
    Write-Host ("RemovedRenameResidue      : {0}" -f $removedRenameResidue.Count) -ForegroundColor Yellow
}

if ($shouldShowGitSummary) {
    Show-LocalGitSummary -RepositoryRoot $repoRoot -PathFilter "ObjetosDaKbEmXml"
}
