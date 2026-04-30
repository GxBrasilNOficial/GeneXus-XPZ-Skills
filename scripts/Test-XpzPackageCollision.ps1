[CmdletBinding(DefaultParameterSetName = 'ByFront')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
    [string]$PackagePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByFront')]
    [string]$FrontPrefix,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByFront')]
    [string]$NN,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByFront')]
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NextFreeRound {
    param(
        [System.Collections.Generic.HashSet[int]]$UsedRounds,
        [int]$StartAt
    )

    $candidate = $StartAt
    while ($UsedRounds.Contains($candidate)) {
        $candidate++
    }

    return $candidate
}

if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
    $resolvedPackage = [System.IO.Path]::GetFullPath($PackagePath)
    $OutputDir = Split-Path -Parent $resolvedPackage
    $leafName = Split-Path -Leaf $resolvedPackage
    $match = [regex]::Match(
        $leafName,
        '^(?<front>.+)_(?<nn>\d+)\.import_file\.xml$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $match.Success) {
        throw "BLOCK: nome de pacote fora do padrao esperado: $leafName"
    }

    $FrontPrefix = $match.Groups['front'].Value
    $NN = $match.Groups['nn'].Value
}

if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) {
    throw "BLOCK: pasta de saida inexistente: $OutputDir"
}

if ($FrontPrefix -match '[\\/]') {
    throw "BLOCK: FrontPrefix invalido; informe apenas o prefixo nominal da frente"
}

if ($NN -notmatch '^\d+$') {
    throw "BLOCK: NN invalido; use apenas digitos"
}

$requestedRound = [int]$NN
$width = [Math]::Max($NN.Length, 2)
$expectedFileName = '{0}_{1}.import_file.xml' -f $FrontPrefix, $NN

$pattern = '^{0}_(?<nn>\d+)\.import_file\.xml$' -f [regex]::Escape($FrontPrefix)
$usedRounds = New-Object 'System.Collections.Generic.HashSet[int]'
$collidingPath = $null

Get-ChildItem -LiteralPath $OutputDir -File | ForEach-Object {
    $currentMatch = [regex]::Match(
        $_.Name,
        $pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $currentMatch.Success) {
        return
    }

    $currentRound = [int]$currentMatch.Groups['nn'].Value
    [void]$usedRounds.Add($currentRound)

    if ($_.Name -ieq $expectedFileName) {
        $collidingPath = $_.FullName
    }
}

if ($null -ne $collidingPath) {
    $nextFree = Get-NextFreeRound -UsedRounds $usedRounds -StartAt ($requestedRound + 1)
    $nextFreeFormatted = $nextFree.ToString(('D{0}' -f $width))
    throw "BLOCK: _$NN ja existe para o front $FrontPrefix, proximo livre: _$nextFreeFormatted"
}

'COLLISION_OK'
