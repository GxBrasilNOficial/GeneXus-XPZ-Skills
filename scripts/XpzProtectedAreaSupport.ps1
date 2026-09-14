#requires -Version 7.4
<#
.SYNOPSIS
    Guardas de caminho compartilhados das skills XPZ (areas protegidas,
    contencao sob base, pontos de reanalise).

.DESCRIPTION
    Extracao da decisao D2 do desenho de Edit-GeneXusXmlBatchMetadata.ps1: as
    primitivas de caminho que o relatorio de execucao do empacotamento ja usava
    passam a viver aqui, com os MESMOS nomes de funcao, para que mais de um
    motor as consuma sem duplicar implementacao.

    Compatibilidade: XpzExecutionReportSupport.ps1 passa a dot-sourcear este
    arquivo e continua expondo as mesmas funcoes aos seus consumidores
    (New-XpzImportPackage.ps1). Nenhum consumidor existente migra.
#>

Set-StrictMode -Version Latest

function Get-XpzCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [IO.Path]::GetFullPath($Path)
}

function Test-XpzPathEqualOrUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Base
    )

    $candidateFull = Get-XpzCanonicalPath -Path $Candidate
    $baseFull = Get-XpzCanonicalPath -Path $Base
    if ($candidateFull.Equals($baseFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $basePrefix = $baseFull.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return $candidateFull.StartsWith($basePrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-XpzReparsePointInPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $cursor = Get-XpzCanonicalPath -Path $Path
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $item.FullName
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent -or $parent.FullName.Equals($cursor, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $cursor = $parent.FullName
    }
    return $null
}

function Get-XpzProtectedAreaPaths {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    return @(
        (Join-Path $RepoRoot 'ObjetosDaKbEmXml'),
        (Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus'),
        (Join-Path $RepoRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'),
        (Join-Path $RepoRoot 'XpzExportadosPelaIDE'),
        (Join-Path $RepoRoot 'scripts'),
        (Join-Path $RepoRoot 'KbIntelligence'),
        (Join-Path $RepoRoot '.git'),
        (Join-Path $RepoRoot 'ArquivoMorto'),
        (Join-Path $RepoRoot 'historico'),
        (Join-Path $RepoRoot 'kb-source-metadata.md')
    )
}

function Test-XpzProtectedArea {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [AllowEmptyCollection()]
        [string[]]$ExemptAreas = @()
    )

    $exempt = @($ExemptAreas)
    foreach ($area in (Get-XpzProtectedAreaPaths -RepoRoot $RepoRoot)) {
        $isExempt = $false
        foreach ($allowed in $exempt) {
            if ([string]::IsNullOrWhiteSpace($allowed)) { continue }
            if ((Get-XpzCanonicalPath -Path $allowed).Equals((Get-XpzCanonicalPath -Path $area), [StringComparison]::OrdinalIgnoreCase)) {
                $isExempt = $true
                break
            }
        }
        if ($isExempt) { continue }
        if (Test-XpzPathEqualOrUnder -Candidate $Candidate -Base $area) {
            return [pscustomobject]@{ blocked = $true; reason = "caminho pertence a area protegida: $area"; area = (Get-XpzCanonicalPath -Path $area) }
        }
    }
    return [pscustomobject]@{ blocked = $false; reason = $null; area = $null }
}
