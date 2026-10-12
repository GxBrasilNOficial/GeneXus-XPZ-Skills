#requires -Version 7.4

<#
.SYNOPSIS
    Regressao mínima do contrato Find-CsAttributeAssignments.ps1.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir 'Find-CsAttributeAssignments.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Find-CsAttributeAssignments.ps1 nao encontrado: $scriptPath"
}

$canonicalAttr = 'A490VendaPedidoVendedorId'
$shortAttr = 'VendaPedidoVendedorId'

function New-ContractCsFixture {
    return @"
public class venda_pedido_impl
{
    protected void OnLoadActions490( IGxContext context )
    {
        if (StringUtil.StrCmp(Gx_mode, "INS") == 0 && !(0==AV10Insert_VendaPedidoVendedorId))
        {
            $canonicalAttr = AV10Insert_VendaPedidoVendedorId;
        }
        else if (true)
        {
            $canonicalAttr = new procVendedorPadrao(context).execute(out AV11X);
        }
        else
        {
            $canonicalAttr = (AV12X==0 ? AV13A : AV13B);
        }
    }

    protected void CheckExtendedTable490( IGxContext context )
    {
        $canonicalAttr = 99;
        AssignAttri("", false, "$canonicalAttr", AV99);
    }

    protected void Valid_Other490( IGxContext context )
    {
        A490VendaPedidoOutroCampo = 1;
    }
}
"@
}

function New-AlternateCascadeCsFixture {
    return @"
public class venda_pedido_impl
{
    protected void OnLoadActions490( IGxContext context )
    {
        if (StringUtil.StrCmp(Gx_mode, "INS") == 0 && !(0==AV10Insert_VendaPedidoVendedorId))
        {
            $canonicalAttr = AV10Insert_VendaPedidoVendedorId;
        }
        else if (true)
        {
            $canonicalAttr = (AV12X==0 ? AV13A : AV13B);
        }
        else
        {
            $canonicalAttr = new procVendedorPadrao(context).execute(out AV11X);
        }
    }
}
"@
}

function Invoke-FindAssignments {
    param(
        [string]$CsPath,
        [string]$Attribute
    )

    $jsonText = & $scriptPath -CsPath $CsPath -Attribute $Attribute -AsJson 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{
        ExitCode = $exitCode
        Json     = ($jsonText | ConvertFrom-Json)
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('find-cs-attr-assign-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

try {
    $fixturePath = Join-Path $tempRoot 'vendapedido.cs'
    [System.IO.File]::WriteAllText($fixturePath, (New-ContractCsFixture), (Get-Utf8NoBomEncoding))

    $result = Invoke-FindAssignments -CsPath $fixturePath -Attribute $shortAttr
    if ($result.ExitCode -ne 0) {
        throw "Exit esperado 0; obtido $($result.ExitCode)"
    }
    if ($result.Json.status -ne 'OK') {
        throw 'status OK esperado'
    }
    if ([string]$result.Json.attributeCanonicalName -ne $canonicalAttr) {
        throw "canonical esperado $canonicalAttr; obtido $($result.Json.attributeCanonicalName)"
    }
    if ([int]$result.Json.totals.assignmentCount -ne 4) {
        throw "assignmentCount esperado 4; obtido $($result.Json.totals.assignmentCount)"
    }
    if ([int]$result.Json.totals.methodCount -ne 2) {
        throw "methodCount esperado 2; obtido $($result.Json.totals.methodCount)"
    }
    if ([int]$result.Json.totals.assignAttriCount -ne 1) {
        throw "assignAttriCount esperado 1; obtido $($result.Json.totals.assignAttriCount)"
    }

    $tripletMethod = @($result.Json.methods | Where-Object { $_.name -eq 'OnLoadActions490' } | Select-Object -First 1)
    if ($tripletMethod.Count -eq 0) {
        throw 'metodo OnLoadActions490 nao encontrado'
    }
    if (-not $tripletMethod.tripletDetected) {
        throw 'tripletDetected esperado true em OnLoadActions490'
    }
    if ([string]$tripletMethod.tripletPattern.cascadeOrder -ne 'override-then-default-then-fallback') {
        throw "cascadeOrder inesperado: $($tripletMethod.tripletPattern.cascadeOrder)"
    }

    $checkMethod = @($result.Json.methods | Where-Object { $_.name -eq 'CheckExtendedTable490' } | Select-Object -First 1)
    if ($checkMethod.Count -eq 0) {
        throw 'metodo CheckExtendedTable490 nao encontrado'
    }
    $checkAssignment = @($checkMethod.assignments | Select-Object -First 1)
    if (-not $checkAssignment.hasAssignAttriInMethod) {
        throw 'hasAssignAttriInMethod esperado true em CheckExtendedTable490'
    }
    if ($checkMethod.tripletDetected) {
        throw 'tripletDetected nao esperado em CheckExtendedTable490'
    }

    $alternatePath = Join-Path $tempRoot 'vendapedido-alternate.cs'
    [System.IO.File]::WriteAllText($alternatePath, (New-AlternateCascadeCsFixture), (Get-Utf8NoBomEncoding))
    $alternateResult = Invoke-FindAssignments -CsPath $alternatePath -Attribute $shortAttr
    if ($alternateResult.ExitCode -ne 0) {
        throw "Exit esperado 0 no alternativo; obtido $($alternateResult.ExitCode)"
    }
    $alternateTripletMethod = @($alternateResult.Json.methods | Where-Object { $_.name -eq 'OnLoadActions490' } | Select-Object -First 1)
    if ($alternateTripletMethod.Count -eq 0) {
        throw 'metodo OnLoadActions490 alternativo nao encontrado'
    }
    if (-not $alternateTripletMethod.tripletDetected) {
        throw 'tripletDetected esperado true no alternativo'
    }
    if ([string]$alternateTripletMethod.tripletPattern.cascadeOrder -ne 'override-then-fallback-then-default') {
        throw "cascadeOrder alternativo inesperado: $($alternateTripletMethod.tripletPattern.cascadeOrder)"
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'FIND_CS_ATTRIBUTE_ASSIGNMENTS_CONTRACT_OK'
