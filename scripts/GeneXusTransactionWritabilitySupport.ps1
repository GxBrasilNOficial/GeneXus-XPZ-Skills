#requires -Version 7.4
<#
.SYNOPSIS
    Invoca GeneXusTransactionWritabilityCore.py (classificador canonico de gravabilidade).
#>

Set-StrictMode -Version Latest

function Invoke-GeneXusTransactionWritabilityCore {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $scriptDir = $PSScriptRoot
    . (Join-Path $scriptDir 'GeneXusPythonPrerequisite.ps1')

    $corePath = Join-Path $scriptDir 'GeneXusTransactionWritabilityCore.py'
    if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) {
        throw "Motor de gravabilidade nao encontrado: $corePath"
    }

    $python = Get-GeneXusPythonExecutable
    if ($null -eq $python) {
        throw (Get-GeneXusPythonPrerequisiteErrorMessage -Operation 'transaction-writability')
    }

    $output = @(& $python.Source $corePath @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $detail = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = "(sem saida capturada do motor Python)"
        }
        throw "GeneXusTransactionWritabilityCore falhou (exit $LASTEXITCODE).`n$detail"
    }

    $jsonText = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw "GeneXusTransactionWritabilityCore retornou JSON vazio."
    }
    return $jsonText | ConvertFrom-Json
}

function Invoke-GeneXusWritabilityOperational {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $scriptDir = $PSScriptRoot
    . (Join-Path $scriptDir 'GeneXusPythonPrerequisite.ps1')
    $operationalPath = Join-Path $scriptDir 'GeneXusWritabilityOperational.py'
    if (-not (Test-Path -LiteralPath $operationalPath -PathType Leaf)) {
        throw "Motor operacional de gravabilidade nao encontrado: $operationalPath"
    }

    $python = Get-GeneXusPythonExecutable
    if ($null -eq $python) {
        throw (Get-GeneXusPythonPrerequisiteErrorMessage -Operation 'transaction-writability')
    }

    $output = @(& $python.Source -B $operationalPath @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $detail = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = '(sem saida capturada do motor operacional Python)'
        }
        throw "GeneXusWritabilityOperational falhou (exit $LASTEXITCODE).`n$detail"
    }

    $jsonText = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw 'GeneXusWritabilityOperational retornou JSON vazio.'
    }
    try {
        return $jsonText | ConvertFrom-Json -Depth 100
    } catch {
        throw "GeneXusWritabilityOperational retornou JSON invalido: $($_.Exception.Message)"
    }
}

function Invoke-GeneXusTransactionWritabilityClassify {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TransactionPath,

        [Parameter(Mandatory = $true)]
        [string]$CorpusFolder,

        [string]$CatalogPath
    )

    $arguments = @(
        'classify-transaction',
        '--transaction-path', $TransactionPath,
        '--corpus-folder', $CorpusFolder
    )
    if (-not [string]::IsNullOrWhiteSpace($CatalogPath)) {
        $arguments += @('--catalog-path', $CatalogPath)
    }
    return Invoke-GeneXusTransactionWritabilityCore -Arguments $arguments
}

function ConvertFrom-GeneXusWritabilityBatchPayload {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Payload
    )

    $maps = @{}
    foreach ($txProp in $Payload.transactions.PSObject.Properties) {
        $txPayload = $txProp.Value
        $attrMap = @{}
        foreach ($attrProp in $txPayload.attributes.PSObject.Properties) {
            $row = $attrProp.Value
            $attrMap[$attrProp.Name] = [pscustomobject]@{
                attributeName  = [string]$row.attributeName
                levelName      = [string]$row.levelName
                key            = [bool]$row.key
                isRedundant    = [bool]$row.isRedundant
                classification = [string]$row.classification
                writable       = $row.writable
                evidence       = [string]$row.evidence
            }
        }
        $maps[$txProp.Name] = $attrMap
    }
    return $maps
}

function Invoke-GeneXusTransactionWritabilityBatch {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TransactionPaths,

        [Parameter(Mandatory = $true)]
        [string]$CorpusFolder,

        [string]$CatalogPath
    )

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $jsonPaths = @($TransactionPaths | ForEach-Object { [string]$_ })
        Set-Content -LiteralPath $tempFile -Value ($jsonPaths | ConvertTo-Json -Compress) -Encoding UTF8

        $arguments = @(
            'classify-batch',
            '--corpus-folder', $CorpusFolder,
            '--transaction-paths-file', $tempFile
        )
        if (-not [string]::IsNullOrWhiteSpace($CatalogPath)) {
            $arguments += @('--catalog-path', $CatalogPath)
        }
        return Invoke-GeneXusTransactionWritabilityCore -Arguments $arguments
    } finally {
        if (Test-Path -LiteralPath $tempFile -PathType Leaf) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
