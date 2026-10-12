#requires -Version 7.4

<#
.SYNOPSIS
    Localiza atribuicoes de atributo Transaction no .cs gerado (camada web GeneXus).

.DESCRIPTION
    Mapeia copias de atribuicao por método, detecta AssignAttri no mesmo método e
    padrão triplet tipico do Specifier (override INS/Insert_, default por proc, fallback ternario).
    Em -AsJson, methods[].name preserva o nome literal do método gerado; veja o mapa canonico
    em xpz-builder/responsibilities-by-type/transaction.md.

.PARAMETER CsPath
    Caminho absoluto do arquivo .cs gerado.

.PARAMETER Attribute
    Nome do atributo com ou sem prefixo A<n>.

.PARAMETER AsJson
    Emite JSON estruturado para agentes.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsPath,

    [Parameter(Mandatory = $true)]
    [string]$Attribute,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusCsAttributeAssignmentSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusCsAttributeAssignmentSupport.ps1 nao encontrado: $supportPath"
}

. $supportPath

function Write-AssignmentHumanReport {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    Write-Output 'FIND_CS_ATTRIBUTE_ASSIGNMENTS_OK'
    Write-Output ("  csPath                 : {0}" -f $Report.CsPath)
    Write-Output ("  attribute              : {0}" -f $Report.Attribute)
    Write-Output ("  attributeCanonicalName : {0}" -f $Report.AttributeCanonicalName)
    Write-Output ("  assignmentCount        : {0}" -f $Report.Totals.assignmentCount)
    Write-Output ("  methodCount            : {0}" -f $Report.Totals.methodCount)
    Write-Output ("  assignAttriCount       : {0}" -f $Report.Totals.assignAttriCount)

    if ($Report.OutputTruncated) {
        Write-Output ("  outputTruncated        : {0}" -f $Report.TruncationSummary)
    }

    foreach ($method in $Report.Methods) {
        Write-Output ''
        Write-Output ("  method {0} (decl line {1})" -f $method.name, $method.startLine)
        if ($method.tripletDetected) {
            Write-Output ("    tripletDetected: true ({0})" -f $method.tripletPattern.cascadeOrder)
        }
        foreach ($assignment in $method.assignments) {
            $assignFlag = if ($assignment.hasAssignAttriInMethod) { 'yes' } else { 'no' }
            Write-Output ("    L{0} AssignAttri={1} | {2}" -f $assignment.line, $assignFlag, $assignment.snippet)
        }
    }
}

try {
    $report = Get-GeneXusCsAttributeAssignmentReport -CsPath $CsPath -AttributeLookupName $Attribute

    if ($AsJson) {
        $jsonMethods = [System.Collections.Generic.List[object]]::new()
        foreach ($method in $report.Methods) {
            $jsonMethods.Add([pscustomobject]@{
                name            = $method.name
                startLine       = $method.startLine
                assignments     = $method.assignments
                tripletDetected = $method.tripletDetected
                tripletPattern  = $method.tripletPattern
            }) | Out-Null
        }

        [pscustomobject]@{
            status                 = 'OK'
            csPath                 = $report.CsPath
            attribute              = $report.Attribute
            attributeCanonicalName = $report.AttributeCanonicalName
            methods                = $jsonMethods.ToArray()
            totals                 = $report.Totals
            outputTruncated        = $report.OutputTruncated
            truncationSummary      = $report.TruncationSummary
        } | ConvertTo-Json -Depth 8 -Compress
    } else {
        Write-AssignmentHumanReport -Report $report
    }

    exit 0
} catch {
    $message = $_.Exception.Message
    if ($null -ne $_.ScriptStackTrace) {
        $message = "$message | $($_.ScriptStackTrace)"
    }
    if ($AsJson) {
        [pscustomobject]@{
            status  = 'ERROR'
            message = $message
        } | ConvertTo-Json -Depth 3 -Compress
    } else {
        Write-Output $message
    }
    if ($message -like 'CS_NOT_FOUND:*') {
        exit 14
    }
    exit 90
}
