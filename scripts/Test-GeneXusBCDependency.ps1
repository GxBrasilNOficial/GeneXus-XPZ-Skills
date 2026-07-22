#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolver catalogo de tipos canonico (gx-object-type-catalog.json fica em scripts/ da base compartilhada)
$CatalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalogo de tipos nao encontrado: $CatalogPath"
}
$Catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$ProcedureTypeGuid   = $Catalog.types.Procedure.objectTypeGuid
$TransactionTypeGuid = $Catalog.types.Transaction.objectTypeGuid

# Regex compativel com Build-KbIntelligenceIndex.py (paridade com o índice)
$VariableRegex      = [regex]::new('<Variable\b(?<attrs>[^>]*)>(?<body>.*?)</Variable>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                                   [System.Text.RegularExpressions.RegexOptions]::Singleline)
$AttCustomTypeRegex = [regex]::new('<Property>\s*<Name>ATTCUSTOMTYPE</Name>\s*<Value>(?<value>.*?)</Value>\s*</Property>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                                   [System.Text.RegularExpressions.RegexOptions]::Singleline)
$VariableNameRegex  = [regex]::new('Name="(?<name>[^"]*)"',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$LevelRegex         = [regex]::new('<Level\s(?<attrs>[^>]*)>',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$LevelNameRegex     = [regex]::new('\bname="(?<n>[^"]+)"',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$LevelTypeRegex     = [regex]::new('\btype="(?<n>[^"]+)"',
                                   [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Normalize-CustomType {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '' }
    $unescaped = [System.Net.WebUtility]::HtmlDecode($Value).Trim()
    $stripped  = ($unescaped -split '//', 2)[0].Trim()
    return ($stripped -split '\s+' -join ' ')
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ProcedureName,
        [string]$ProcedureFile,
        [string]$TransactionName,
        [string]$Location,
        [string]$SublevelPath
    )
    return [pscustomobject]@{
        severity        = $Severity
        code            = $Code
        message         = $Message
        procedureName   = $ProcedureName
        procedureFile   = $ProcedureFile
        transactionName = $TransactionName
        location        = $Location
        sublevelPath    = $SublevelPath
    }
}

function Get-ObjectMetadata {
    param([string]$XmlPath)
    try {
        [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    } catch {
        return $null
    }
    $root = $doc.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'Object') { return $null }
    $objType = $root.GetAttribute('type')
    $objName = ''
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'Name') { $objName = $prop.Value; break }
    }
    $isBC = $null  # null = property absent
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'idISBUSINESSCOMPONENT') {
            $isBC = ($prop.Value -eq 'True')
            break
        }
    }
    return [pscustomobject]@{
        Path     = $XmlPath
        Name     = $objName
        TypeGuid = $objType
        IsBC     = $isBC  # $true / $false / $null
    }
}

function Get-TransactionLevels {
    param([string]$XmlPath)
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $LevelRegex.Matches($text)) {
        $attrs = $m.Groups['attrs'].Value
        $nameMatch = $LevelNameRegex.Match($attrs)
        if ($nameMatch.Success) {
            [void]$names.Add($nameMatch.Groups['n'].Value)
        }
        $typeMatch = $LevelTypeRegex.Match($attrs)
        if ($typeMatch.Success) {
            [void]$names.Add($typeMatch.Groups['n'].Value)
        }
    }
    return ,$names
}

function Get-BCDependencies {
    param([string]$XmlPath)
    $deps = @()
    $text = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    foreach ($varMatch in $VariableRegex.Matches($text)) {
        $varName = ''
        $nameMatch = $VariableNameRegex.Match($varMatch.Groups['attrs'].Value)
        if ($nameMatch.Success) { $varName = $nameMatch.Groups['name'].Value }
        $body = $varMatch.Groups['body'].Value
        $ctMatch = $AttCustomTypeRegex.Match($body)
        if (-not $ctMatch.Success) { continue }
        $ct = Normalize-CustomType $ctMatch.Groups['value'].Value
        if (-not $ct.ToLowerInvariant().StartsWith('bc:')) { continue }
        $txName = ($ct.Substring(3)).Trim()
        if ([string]::IsNullOrEmpty($txName)) { continue }
        $deps += [pscustomobject]@{
            VariableName    = $varName
            TransactionName = $txName
        }
    }
    return ,@($deps)
}

# Validar parâmetros
if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
    throw "FrontFolder nao encontrado ou nao e diretorio: $FrontFolder"
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}
$FrontFolder  = (Resolve-Path -LiteralPath $FrontFolder).Path
$CorpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path

# 1. Enumerar XMLs no FrontFolder e classificar
$batchProcedures = @()
$batchTransactions = @{}  # name (lower) -> ObjectMetadata
$batchXmls = Get-ChildItem -LiteralPath $FrontFolder -Recurse -Filter *.xml -File
foreach ($xml in $batchXmls) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
    if ($meta.TypeGuid -eq $ProcedureTypeGuid) {
        $batchProcedures += $meta
    } elseif ($meta.TypeGuid -eq $TransactionTypeGuid) {
        $batchTransactions[$meta.Name.ToLowerInvariant()] = $meta
    }
}

# 2. Se nenhum Procedure no batch -> not-applicable
$findings = @()
$bcDependenciesFound = 0
if ($batchProcedures.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 3. Coletar BC dependencies por Procedure
    $procDeps = @{}  # ProcedurePath -> @(BCDep)
    $pendingCorpusLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($proc in $batchProcedures) {
        $deps = Get-BCDependencies $proc.Path
        $procDeps[$proc.Path] = $deps
        $bcDependenciesFound += $deps.Count
        foreach ($d in $deps) {
            $mainTxName = ($d.TransactionName -split '\.', 2)[0]
            if (-not $batchTransactions.ContainsKey($mainTxName.ToLowerInvariant())) {
                [void]$pendingCorpusLookup.Add($mainTxName)
            }
        }
    }
    # 4. Varrer corpus uma única vez por TX pendentes (restringe a subpasta canonica Transaction/)
    $corpusTransactions = @{}  # name (lower) -> ObjectMetadata
    if ($pendingCorpusLookup.Count -gt 0) {
        $corpusTransactionFolder = Join-Path $CorpusFolder 'Transaction'
        if (-not (Test-Path -LiteralPath $corpusTransactionFolder -PathType Container)) {
            throw "Layout do CorpusFolder inesperado: subpasta 'Transaction' nao encontrada em $CorpusFolder; gate exige layout canonico <Type>/<Name>.xml gerado por Sync-GeneXusXpzToXml.ps1"
        }
        $corpusXmls = Get-ChildItem -LiteralPath $corpusTransactionFolder -Recurse -Filter *.xml -File
        foreach ($xml in $corpusXmls) {
            $meta = Get-ObjectMetadata $xml.FullName
            if ($null -eq $meta -or [string]::IsNullOrEmpty($meta.Name)) { continue }
            if ($meta.TypeGuid -ne $TransactionTypeGuid) { continue }
            if ($pendingCorpusLookup.Contains($meta.Name)) {
                $corpusTransactions[$meta.Name.ToLowerInvariant()] = $meta
            }
        }
    }
    # 5. Gerar findings
    foreach ($proc in $batchProcedures) {
        $procRel = [System.IO.Path]::GetRelativePath($FrontFolder, $proc.Path)
        foreach ($dep in $procDeps[$proc.Path]) {
            $depFullName = $dep.TransactionName
            $parts = @($depFullName -split '\.')
            $mainTxName = $parts[0]
            if ($parts.Count -gt 1) {
                $sublevelParts = @($parts[1..($parts.Count - 1)])
            } else {
                $sublevelParts = @()
            }
            $sublevelPath = $sublevelParts -join '.'
            $mainKey = $mainTxName.ToLowerInvariant()
            $tx = $null
            $location = $null
            if ($batchTransactions.ContainsKey($mainKey)) {
                $tx = $batchTransactions[$mainKey]
                $location = 'batch'
            } elseif ($corpusTransactions.ContainsKey($mainKey)) {
                $tx = $corpusTransactions[$mainKey]
                $location = 'corpus'
            }
            if ($null -eq $tx) {
                $findings += New-Finding -Severity 'fail' -Code 'bc-missing-everywhere' `
                    -Message "Transaction '$depFullName' nao encontrada nem no batch nem no corpus" `
                    -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $depFullName -Location 'absent' -SublevelPath $sublevelPath
                continue
            }
            # Verificar isBC da Transaction principal
            if ($null -eq $tx.IsBC) {
                $code = if ($location -eq 'batch') { 'bc-isbc-property-absent-batch' } else { 'bc-isbc-property-absent-corpus' }
                $tail = if ($location -eq 'batch') { 'corrigir antes de empacotar' } else { 'dependencia bc: nao pode ser satisfeita' }
                $findings += New-Finding -Severity 'fail' -Code $code `
                    -Message "Transaction '$($tx.Name)' no $location nao tem a propriedade idISBUSINESSCOMPONENT; $tail" `
                    -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $depFullName -Location $location -SublevelPath $sublevelPath
                continue
            }
            if ($tx.IsBC -eq $false) {
                $code = if ($location -eq 'batch') { 'bc-isbc-false-batch' } else { 'bc-isbc-false-corpus' }
                $tail = if ($location -eq 'batch') { 'corrigir antes de empacotar' } else { 'dependencia bc: nao pode ser satisfeita' }
                $findings += New-Finding -Severity 'fail' -Code $code `
                    -Message "Transaction '$($tx.Name)' no $location tem idISBUSINESSCOMPONENT=False; $tail" `
                    -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $depFullName -Location $location -SublevelPath $sublevelPath
                continue
            }
            # Transaction principal e BC=True. Se ha sublevel, verificar.
            if ($sublevelParts.Count -gt 0) {
                $levels = Get-TransactionLevels $tx.Path
                $missingSub = $null
                foreach ($lvlName in $sublevelParts) {
                    if (-not $levels.Contains($lvlName)) { $missingSub = $lvlName; break }
                }
                if ($null -ne $missingSub) {
                    $code = if ($location -eq 'batch') { 'bc-sublevel-not-found-batch' } else { 'bc-sublevel-not-found-corpus' }
                    $findings += New-Finding -Severity 'fail' -Code $code `
                        -Message "Transaction '$($tx.Name)' no $location existe como BC, mas o sublevel '$missingSub' (referenciado em '$depFullName') nao existe na estrutura de Levels" `
                        -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $depFullName -Location $location -SublevelPath $sublevelPath
                    continue
                }
            }
            # Caso de sucesso: Transaction principal BC=True, sublevels (se houver) validos
            if ($location -eq 'batch') {
                $msg = "Transaction '$($tx.Name)' e o Procedure '$($proc.Name)' estao no mesmo batch; risco de ordenacao na importacao"
                if ($sublevelParts.Count -gt 0) { $msg += " (referenciada como sublevel '$sublevelPath')" }
                $findings += New-Finding -Severity 'warn' -Code 'bc-isbc-true-same-batch-ordering-risk' `
                    -Message $msg `
                    -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $depFullName -Location 'batch' -SublevelPath $sublevelPath
            } else {
                $msg = "Transaction '$($tx.Name)' ja existe como BC no corpus"
                if ($sublevelParts.Count -gt 0) { $msg += " (referenciada como sublevel '$sublevelPath')" }
                $findings += New-Finding -Severity 'info' -Code 'bc-isbc-true-corpus' `
                    -Message $msg `
                    -ProcedureName $proc.Name -ProcedureFile $procRel -TransactionName $depFullName -Location 'corpus' -SublevelPath $sublevelPath
            }
        }
    }
    # 6. Status agregado
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    $hasWarn = $findings | Where-Object { $_.severity -eq 'warn' } | Select-Object -First 1
    if ($hasFail) { $status = 'fail' }
    elseif ($hasWarn) { $status = 'alert' }
    else { $status = 'pass' }
}

# 7. Emitir
$result = [pscustomobject]@{
    status              = $status
    frontFolder         = $FrontFolder
    corpusFolder        = $CorpusFolder
    proceduresScanned   = $batchProcedures.Count
    bcDependenciesFound = $bcDependenciesFound
    findings            = $findings
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "corpusFolder: $CorpusFolder"
    Write-Output "proceduresScanned: $($batchProcedures.Count)"
    Write-Output "bcDependenciesFound: $bcDependenciesFound"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            Write-Output "    procedure: $($f.procedureName) ($($f.procedureFile))"
            Write-Output "    transaction: $($f.transactionName) [$($f.location)]"
        }
    }
}
