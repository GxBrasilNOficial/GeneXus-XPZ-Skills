#requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8SupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8SupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8SupportPath"
}
. $utf8SupportPath

$scriptPath = Join-Path $PSScriptRoot 'Test-GeneXusBCDependency.ps1'
$catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$procedureTypeGuid = $catalog.types.Procedure.objectTypeGuid
$transactionTypeGuid = $catalog.types.Transaction.objectTypeGuid
$utf8 = Get-Utf8NoBomEncoding
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('bcdependency-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))

function New-CaseWorkspace {
    param([string]$Name)
    $caseRoot = Join-Path $tempRoot $Name
    $front = Join-Path $caseRoot 'front'
    $corpus = Join-Path $caseRoot 'corpus'
    $corpusTransaction = Join-Path $corpus 'Transaction'
    [void](New-Item -ItemType Directory -Path $front -Force)
    [void](New-Item -ItemType Directory -Path $corpusTransaction -Force)
    return [pscustomobject]@{
        Front = $front
        Corpus = $corpus
        CorpusTransaction = $corpusTransaction
    }
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function New-ProcedureXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$BcTypes = @()
    )
    $variables = ''
    $index = 1
    foreach ($bcType in $BcTypes) {
        $variables += @"
    <Variable Name="BCVar$index">
      <Properties>
        <Property><Name>ATTCUSTOMTYPE</Name><Value>bc:$bcType</Value></Property>
      </Properties>
    </Variable>
"@
        $index++
    }
    return @"
<Object type="$procedureTypeGuid" name="$Name" guid="$([guid]::NewGuid())">
  <Properties>
    <Property><Name>Name</Name><Value>$Name</Value></Property>
  </Properties>
  <Variables>
$variables  </Variables>
</Object>
"@
}

function New-TransactionXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Levels = @(),
        [string[]]$LevelTypes = @(),
        [AllowNull()][object]$IsBC
    )
    $levelXml = ''
    foreach ($level in $Levels) {
        $levelXml += "      <Level Name=`"$level`" />`n"
    }
    foreach ($levelType in $LevelTypes) {
        $levelXml += "      <Level Type=`"$levelType`" />`n"
    }
    $bcProperty = ''
    if ($PSBoundParameters.ContainsKey('IsBC') -and $null -ne $IsBC) {
        $bcProperty = "    <Property><Name>idISBUSINESSCOMPONENT</Name><Value>$IsBC</Value></Property>`n"
    }
    return @"
<Object type="$transactionTypeGuid" name="$Name" guid="$([guid]::NewGuid())">
  <Properties>
    <Property><Name>Name</Name><Value>$Name</Value></Property>
$bcProperty  </Properties>
  <Part type="264be5fb-1b28-4b25-a598-6ca900dd059f">
$levelXml  </Part>
</Object>
"@
}

function Add-Procedure {
    param(
        [Parameter(Mandatory = $true)]$Workspace,
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$BcTypes = @()
    )
    Write-Utf8NoBomFile -Path (Join-Path $Workspace.Front "$Name.xml") -Content (New-ProcedureXml -Name $Name -BcTypes $BcTypes)
}

function Add-Transaction {
    param(
        [Parameter(Mandatory = $true)]$Workspace,
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Levels = @(),
        [string[]]$LevelTypes = @(),
        [AllowNull()][object]$IsBC,
        [switch]$InFront
    )
    $folder = if ($InFront) { $Workspace.Front } else { $Workspace.CorpusTransaction }
    if ($null -eq $IsBC) {
        $content = New-TransactionXml -Name $Name -Levels $Levels -LevelTypes $LevelTypes
    } else {
        $content = New-TransactionXml -Name $Name -Levels $Levels -LevelTypes $LevelTypes -IsBC ([bool]$IsBC)
    }
    Write-Utf8NoBomFile -Path (Join-Path $folder "$Name.xml") -Content $content
}

function Invoke-BCDependencyGate {
    param($Workspace)
    return (& $scriptPath -FrontFolder $Workspace.Front -CorpusFolder $Workspace.Corpus -AsJson | ConvertFrom-Json)
}

function Assert-Result {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$CaseName,
        [Parameter(Mandatory = $true)][string]$ExpectedStatus,
        [Parameter(Mandatory = $true)][int]$ExpectedCount,
        [string[]]$ExpectedCodes = @(),
        [string[]]$RejectedCodes = @()
    )
    if ($Result.status -ne $ExpectedStatus) {
        throw "${CaseName}: status esperado '$ExpectedStatus'; obtido '$($Result.status)'."
    }
    if ($Result.bcDependenciesFound -ne $ExpectedCount) {
        throw "${CaseName}: bcDependenciesFound esperado '$ExpectedCount'; obtido '$($Result.bcDependenciesFound)'."
    }
    $codes = @($Result.findings | ForEach-Object { $_.code })
    foreach ($code in $ExpectedCodes) {
        if ($codes -notcontains $code) {
            throw "${CaseName}: finding esperado '$code' ausente. Findings: $($codes -join ', ')"
        }
    }
    foreach ($code in $RejectedCodes) {
        if ($codes -contains $code) {
            throw "${CaseName}: finding rejeitado '$code' presente."
        }
    }
}

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    $w1 = New-CaseWorkspace 'no-procedure'
    Add-Transaction -Workspace $w1 -Name 'Cliente' -Levels @('Cliente') -IsBC $true
    Assert-Result -Result (Invoke-BCDependencyGate $w1) -CaseName 'nenhum Procedure' -ExpectedStatus 'not-applicable' -ExpectedCount 0

    $w2 = New-CaseWorkspace 'procedure-no-bc'
    Add-Procedure -Workspace $w2 -Name 'ProcSemBc'
    Assert-Result -Result (Invoke-BCDependencyGate $w2) -CaseName 'Procedure sem bc' -ExpectedStatus 'pass' -ExpectedCount 0

    $w3 = New-CaseWorkspace 'one-valid-bc'
    Add-Procedure -Workspace $w3 -Name 'ProcUmaBc' -BcTypes @('Cliente')
    Add-Transaction -Workspace $w3 -Name 'Cliente' -Levels @('Cliente') -IsBC $true
    Assert-Result -Result (Invoke-BCDependencyGate $w3) -CaseName 'uma dependencia BC valida' -ExpectedStatus 'pass' -ExpectedCount 1 -ExpectedCodes @('bc-isbc-true-corpus')

    $w4 = New-CaseWorkspace 'multiple-valid-bc'
    Add-Procedure -Workspace $w4 -Name 'ProcMultiplasBc' -BcTypes @('Cliente', 'Pedido')
    Add-Transaction -Workspace $w4 -Name 'Cliente' -Levels @('Cliente') -IsBC $true
    Add-Transaction -Workspace $w4 -Name 'Pedido' -Levels @('Pedido') -IsBC $true
    Assert-Result -Result (Invoke-BCDependencyGate $w4) -CaseName 'multiplas dependencias BC validas' -ExpectedStatus 'pass' -ExpectedCount 2 -ExpectedCodes @('bc-isbc-true-corpus')

    $w5 = New-CaseWorkspace 'valid-sublevel'
    Add-Procedure -Workspace $w5 -Name 'ProcSublevel' -BcTypes @('Pedido.Item')
    Add-Transaction -Workspace $w5 -Name 'Pedido' -Levels @('Pedido', 'Item') -IsBC $true
    Assert-Result -Result (Invoke-BCDependencyGate $w5) -CaseName 'subnivel valido' -ExpectedStatus 'pass' -ExpectedCount 1 -ExpectedCodes @('bc-isbc-true-corpus')

    $w5Type = New-CaseWorkspace 'valid-sublevel-by-type'
    Add-Procedure -Workspace $w5Type -Name 'ProcSublevelPorType' -BcTypes @('Pedido.Item')
    Add-Transaction -Workspace $w5Type -Name 'Pedido' -Levels @('Pedido') -LevelTypes @('Item') -IsBC $true
    Assert-Result -Result (Invoke-BCDependencyGate $w5Type) -CaseName 'subnivel valido por Type' -ExpectedStatus 'pass' -ExpectedCount 1 -ExpectedCodes @('bc-isbc-true-corpus')

    $w6 = New-CaseWorkspace 'missing-sublevel'
    Add-Procedure -Workspace $w6 -Name 'ProcSublevelAusente' -BcTypes @('Pedido.Item')
    Add-Transaction -Workspace $w6 -Name 'Pedido' -Levels @('Pedido') -IsBC $true
    Assert-Result -Result (Invoke-BCDependencyGate $w6) -CaseName 'subnivel ausente' -ExpectedStatus 'fail' -ExpectedCount 1 -ExpectedCodes @('bc-sublevel-not-found-corpus')

    $w7 = New-CaseWorkspace 'missing-transaction'
    Add-Procedure -Workspace $w7 -Name 'ProcTransactionAusente' -BcTypes @('Cliente')
    Assert-Result -Result (Invoke-BCDependencyGate $w7) -CaseName 'Transaction ausente' -ExpectedStatus 'fail' -ExpectedCount 1 -ExpectedCodes @('bc-missing-everywhere')

    $w8 = New-CaseWorkspace 'isbc-false'
    Add-Procedure -Workspace $w8 -Name 'ProcBcFalse' -BcTypes @('Cliente')
    Add-Transaction -Workspace $w8 -Name 'Cliente' -Levels @('Cliente') -IsBC $false
    Assert-Result -Result (Invoke-BCDependencyGate $w8) -CaseName 'idISBUSINESSCOMPONENT False' -ExpectedStatus 'fail' -ExpectedCount 1 -ExpectedCodes @('bc-isbc-false-corpus')

    $w9 = New-CaseWorkspace 'isbc-absent'
    Add-Procedure -Workspace $w9 -Name 'ProcBcAusente' -BcTypes @('Cliente')
    Add-Transaction -Workspace $w9 -Name 'Cliente' -Levels @('Cliente') -IsBC $null
    Assert-Result -Result (Invoke-BCDependencyGate $w9) -CaseName 'idISBUSINESSCOMPONENT ausente' -ExpectedStatus 'fail' -ExpectedCount 1 -ExpectedCodes @('bc-isbc-property-absent-corpus')

    $w10 = New-CaseWorkspace 'same-batch-ordering-risk'
    Add-Procedure -Workspace $w10 -Name 'ProcMesmoBatch' -BcTypes @('Cliente')
    Add-Transaction -Workspace $w10 -Name 'Cliente' -Levels @('Cliente') -IsBC $true -InFront
    Assert-Result -Result (Invoke-BCDependencyGate $w10) -CaseName 'Transaction BC no mesmo batch' -ExpectedStatus 'alert' -ExpectedCount 1 -ExpectedCodes @('bc-isbc-true-same-batch-ordering-risk')
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'OK: Test-GeneXusBCDependencySelfTest.ps1'
exit 0
