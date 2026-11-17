#requires -Version 7.4

<#
.SYNOPSIS
    Self-test do motor Test-GeneXusSourceIndentation.ps1 (v1: indent-under-depth,
    indent-unit-mismatch-in-delta, BaselinePath, ExportFile, exit 20 via processo filho).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8SupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8SupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8SupportPath"
}
. $utf8SupportPath

$scriptPath = Join-Path $PSScriptRoot 'Test-GeneXusSourceIndentation.ps1'
$utf8 = Get-Utf8NoBomEncoding
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sourceindent-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)
$acervoRoot = Join-Path $tempRoot 'acervo'
[void](New-Item -ItemType Directory -Path $acervoRoot -Force)

$procType = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webType = 'c9584656-94b6-4ccd-890f-332d11fc2c25'
$mainPart = '528d1c06-a9c2-420d-bd35-21dca83f12ff'
$guidGood = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
$guidNew = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'

function New-ProcXml {
    param(
        [string]$Guid,
        [string]$Name,
        [string]$Source,
        [string]$ObjectType = $procType
    )
    $escaped = $Source # CDATA: evitar ]]>
    return @"
<Object type="$ObjectType" name="$Name" guid="$Guid">
  <Part type="$mainPart">
    <Source><![CDATA[$escaped]]></Source>
  </Part>
</Object>
"@
}

function Write-Xml {
    param([string]$Path, [string]$Xml)
    [System.IO.File]::WriteAllText($Path, $Xml, $utf8)
}

function Invoke-Indent {
    param(
        [string]$Xml,
        [string]$AcervoPath,
        [string]$BaselinePath,
        [switch]$Absolute
    )
    $f = Join-Path $tempRoot ('i-{0}.xml' -f ([guid]::NewGuid().ToString('N')))
    Write-Xml -Path $f -Xml $Xml
    $args = @{ InputPath = $f }
    if ($AcervoPath) { $args.AcervoPath = $AcervoPath }
    if ($BaselinePath) { $args.BaselinePath = $BaselinePath }
    if ($Absolute) { $args.AbsoluteIndentCheck = $true }
    $json = & $scriptPath @args
    return ($json | ConvertFrom-Json)
}

function Invoke-IndentChild {
    param([string[]]$Arguments)
    $output = & pwsh -NoProfile -File $scriptPath @Arguments 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text     = (($output | Out-String).Trim())
    }
}

function Assert-True {
    param([bool]$Cond, [string]$Msg)
    if (-not $Cond) { throw "ASSERT_FAILED: $Msg" }
}

function Test-HasCode {
    param($Result, [string]$Code)
    return @($Result.findings | Where-Object { $_.code -eq $Code }).Count -gt 0
}

# Baseline tabada correta
$baselineSource = @"
if &x = 1
	msg('a')
else
	msg('b')
endif
"@
$baselineXml = New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $baselineSource
Write-Xml -Path (Join-Path $acervoRoot 'ProcIndent.xml') -Xml $baselineXml

# 1) under-depth: corpo do if sem tab
$badUnder = @"
if &x = 1
msg('a')
else
	msg('b')
endif
"@
$r1 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $acervoRoot
Assert-True ($r1.sourceIndentStatus -eq 'warn') 'caso under-depth deveria warn'
Assert-True (Test-HasCode -Result $r1 -Code 'indent-under-depth') 'faltou indent-under-depth'
Assert-True ($r1.baselineCompared -eq $true) 'baseline deveria comparar'

# 2) reindented: mesma linha, leading mudou (tab -> zero) no msg('b') ja coberto; forcar so reindent do else body
$reindented = @"
if &x = 1
	msg('a')
else
msg('b')
endif
"@
$r2 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $reindented) -AcervoPath $acervoRoot
Assert-True (Test-HasCode -Result $r2 -Code 'indent-under-depth') 'reindented under-depth deveria warn'

# 3) unit mismatch: moda tab, linha nova com espacos
$unitMix = @"
if &x = 1
	msg('a')
else
	msg('b')
    msg('c')
endif
"@
$r3 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $unitMix) -AcervoPath $acervoRoot
Assert-True (Test-HasCode -Result $r3 -Code 'indent-unit-mismatch-in-delta') 'faltou indent-unit-mismatch-in-delta'

# 4) sem baseline e sem absoluto -> inconclusive
$r4 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $baselineSource)
Assert-True ($r4.sourceIndentStatus -eq 'inconclusive') 'sem baseline deveria inconclusive'
Assert-True ($r4.baselineStatus -eq 'no-baseline-unresolved') 'baselineStatus unresolved'

# 5) absoluto sem acervo ainda checa
$absBad = @"
if &x = 1
msg('z')
endif
"@
$r5 = Invoke-Indent -Xml (New-ProcXml -Guid $guidNew -Name 'ProcNewAbs' -Source $absBad) -Absolute
Assert-True (Test-HasCode -Result $r5 -Code 'indent-under-depth') 'absoluto deveria achar under-depth'
Assert-True ($r5.absoluteCheckApplied -eq $true) 'absoluteCheckApplied'

# 6) objeto novo no acervo (GUID ausente) = part inteira delta
$r6 = Invoke-Indent -Xml (New-ProcXml -Guid $guidNew -Name 'ProcNew' -Source $absBad) -AcervoPath $acervoRoot
Assert-True ($r6.parts[0].baselineStatus -eq 'no-baseline-new-object') 'deveria new-object'
Assert-True (Test-HasCode -Result $r6 -Code 'indent-under-depth') 'new-object under-depth'

# 7) part vazia -> not-applicable
$r7 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcEmpty' -Source '   ') -AcervoPath $acervoRoot
Assert-True ($r7.sourceIndentStatus -eq 'not-applicable') 'part vazia not-applicable'

# 8) WebPanel fora da allowlist
$r8 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'Wp' -Source $badUnder -ObjectType $webType) -AcervoPath $acervoRoot -Absolute
Assert-True ($r8.sourceIndentStatus -eq 'not-applicable') 'WebPanel fora do escopo'
Assert-True ($r8.inScopePartCount -eq 0) 'inScopePartCount 0'

# 9) XML malformado
$badXmlPath = Join-Path $tempRoot 'bad.xml'
Write-Xml -Path $badXmlPath -Xml '<Object><Part>'
$r9 = & $scriptPath -InputPath $badXmlPath | ConvertFrom-Json
Assert-True ($r9.sourceIndentStatus -eq 'inconclusive') 'xml malformado inconclusive'
Assert-True (Test-HasCode -Result $r9 -Code 'xml-parse') 'xml-parse'

# 10) pass limpo com baseline
$r10 = Invoke-Indent -Xml $baselineXml -AcervoPath $acervoRoot
Assert-True ($r10.sourceIndentStatus -eq 'pass') 'baseline identica deveria pass'
Assert-True ($r10.warnCount -eq 0) 'warnCount 0'

# 11) parts[] carrega identidade
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r10.parts[0].objectGuid)) 'objectGuid em parts'
Assert-True ($r10.parts[0].objectName -eq 'ProcIndent') 'objectName em parts'

# 12) Absolute + baseline compared: preserved com under-depth herdado
$inheritedBad = @"
if &x = 1
msg('a')
endif
"@
$guidInherited = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
$inheritedXml = New-ProcXml -Guid $guidInherited -Name 'ProcInherited' -Source $inheritedBad
Write-Xml -Path (Join-Path $acervoRoot 'ProcInherited.xml') -Xml $inheritedXml
$r12noAbs = Invoke-Indent -Xml $inheritedXml -AcervoPath $acervoRoot
Assert-True ($r12noAbs.sourceIndentStatus -eq 'pass') 'sem absoluto, preserved herdado nao deve warn'
$r12abs = Invoke-Indent -Xml $inheritedXml -AcervoPath $acervoRoot -Absolute
Assert-True (Test-HasCode -Result $r12abs -Code 'indent-under-depth') 'absoluto+baseline deve achar preserved under-depth'
Assert-True ($r12abs.absoluteCheckApplied -eq $true) 'absoluteCheckApplied com baseline'
Assert-True ($r12abs.baselineCompared -eq $true) 'baseline compared no absoluto'

# 13) xmlLineNumber: primeira linha do Source nao deve ser offset+1 a mais
$underFinding = @($r1.findings | Where-Object { $_.code -eq 'indent-under-depth' } | Select-Object -First 1)
Assert-True ($null -ne $underFinding) 'r1 precisa de under-depth para checar xmlLineNumber'
Assert-True ($underFinding.sourceLineNumber -ge 1) 'sourceLineNumber >= 1'
Assert-True ($underFinding.xmlLineNumber -eq (2 + $underFinding.sourceLineNumber)) 'xmlLineNumber = linha Source(3) + sourceLine - 1 => 2+sourceLine quando Object/Part/Source nas linhas 1-3'

# 14) BaselinePath explicito (sem AcervoPath)
$baselineFile = Join-Path $tempRoot 'explicit-baseline.xml'
Write-Xml -Path $baselineFile -Xml $baselineXml
$r14 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -BaselinePath $baselineFile
Assert-True ($r14.baselineCompared -eq $true) 'BaselinePath deveria comparar'
Assert-True (Test-HasCode -Result $r14 -Code 'indent-under-depth') 'BaselinePath deveria achar under-depth'

# 15) ExportFile com 1 Procedure in-scope
$exportXml = @"
<ExportFile>
  <Objects>
$(New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder)
  </Objects>
</ExportFile>
"@
$r15 = Invoke-Indent -Xml $exportXml -AcervoPath $acervoRoot
Assert-True ($r15.inScopePartCount -ge 1) 'ExportFile deveria achar Procedure in-scope'
Assert-True (Test-HasCode -Result $r15 -Code 'indent-under-depth') 'ExportFile deveria achar under-depth'
Assert-True ($r15.parts[0].objectName -eq 'ProcIndent') 'ExportFile objectName'

# 16) exit 20 / status=bloqueado via processo filho (InputPath ausente)
$missingPath = Join-Path $tempRoot 'missing-no-such-input.xml'
$child16 = Invoke-IndentChild -Arguments @('-InputPath', $missingPath)
Assert-True ($child16.ExitCode -eq 20) ("exit 20 esperado; obtido $($child16.ExitCode)")
$r16 = $child16.Text | ConvertFrom-Json
Assert-True ($r16.status -eq 'bloqueado') 'status bloqueado no exit 20'
Assert-True ($r16.exitCode -eq 20) 'exitCode 20 no JSON'
Assert-True (Test-HasCode -Result $r16 -Code 'preflight') 'finding preflight no bloqueio'

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'OK: Test-GeneXusSourceIndentationSelfTest.ps1'
