#requires -Version 7.4

<#
.SYNOPSIS
    Self-test do motor Test-GeneXusSourceIndentation.ps1 (v1: indent-under-depth,
    indent-unit-mismatch-in-delta, BaselinePath, ExportFile, exit 20 via processo filho,
    BaselinePath GUID ausente=unresolved, Acervo hit textual raso + Object profundo,
    Object duplicado entre profundidades, >20 hits textuais sem teto,
    AcervoPath=arquivo sem GUID=unresolved, XML oculto encontrado com -Force,
    ExportFile com 2 Procedures + contadores de prefiltro (1 passagem / N leituras),
    ExportFile misto GUID ok + GUID vazio = unresolved no vazio,
    GUID com espacos nas bordas compared, GUID zero/invalido = unresolved).
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
$guidSecond = 'cccccccc-cccc-cccc-cccc-cccccccccccc'

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

# 17) BaselinePath existe mas sem o GUID do input -> unresolved (nao new-object)
$wrongBaselineFile = Join-Path $tempRoot 'wrong-baseline-guid.xml'
Write-Xml -Path $wrongBaselineFile -Xml (New-ProcXml -Guid $guidNew -Name 'OtherProc' -Source $baselineSource)
$r17 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -BaselinePath $wrongBaselineFile
Assert-True ($r17.baselineStatus -eq 'no-baseline-unresolved') 'BaselinePath com GUID ausente deve unresolved'
Assert-True ($r17.baselineCompared -ne $true) 'nao deve comparar baseline errado'
Assert-True ($r17.sourceIndentStatus -eq 'inconclusive') 'deve inconclusive sem tratar como new-object'
Assert-True (-not (Test-HasCode -Result $r17 -Code 'indent-under-depth')) 'nao inventar under-depth por falso new-object'
Assert-True (Test-HasCode -Result $r17 -Code 'indent-inconclusive') 'esperado indent-inconclusive'

# 18) Acervo: GUID so como texto num XML raso; Object real mais fundo -> compared
$nestedAcervo = Join-Path $tempRoot 'acervo-nested'
$shallowDir = Join-Path $nestedAcervo 'shallow'
$deepDir = Join-Path $nestedAcervo 'deep\Procedure'
[void](New-Item -ItemType Directory -Path $shallowDir -Force)
[void](New-Item -ItemType Directory -Path $deepDir -Force)
$refOnlyXml = @"
<Object type="$procType" name="RefOnly" guid="$guidNew">
  <Part type="$mainPart">
    <Source><![CDATA[// referencia textual $guidGood]]></Source>
  </Part>
</Object>
"@
Write-Xml -Path (Join-Path $shallowDir 'RefOnly.xml') -Xml $refOnlyXml
Write-Xml -Path (Join-Path $deepDir 'ProcIndent.xml') -Xml $baselineXml
$r18 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $nestedAcervo
Assert-True ($r18.baselineCompared -eq $true) 'recurse deve achar Object profundo apesar de hit textual raso'
Assert-True ($r18.baselineStatus -eq 'compared') 'baselineStatus compared'
Assert-True (Test-HasCode -Result $r18 -Code 'indent-under-depth') 'com baseline real deve achar under-depth'

# 19) Object com mesmo GUID raso + fundo -> unresolved (duplicata entre profundidades)
$dupAcervo = Join-Path $tempRoot 'acervo-dup'
$dupShallow = Join-Path $dupAcervo 'shallow'
$dupDeep = Join-Path $dupAcervo 'deep\Procedure'
[void](New-Item -ItemType Directory -Path $dupShallow -Force)
[void](New-Item -ItemType Directory -Path $dupDeep -Force)
Write-Xml -Path (Join-Path $dupShallow 'ProcIndent.xml') -Xml $baselineXml
Write-Xml -Path (Join-Path $dupDeep 'ProcIndentCopy.xml') -Xml $baselineXml
$r19 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $dupAcervo
Assert-True ($r19.baselineStatus -eq 'no-baseline-unresolved') 'GUID duplicado raso+fundo deve unresolved'
Assert-True ($r19.baselineCompared -ne $true) 'duplicata nao deve compared'
Assert-True ($r19.sourceIndentStatus -eq 'inconclusive') 'duplicata deve inconclusive'
Assert-True (-not (Test-HasCode -Result $r19 -Code 'indent-under-depth')) 'duplicata nao inventa under-depth'

# 20) >20 hits textuais rasos + Object profundo (regressao do antigo -First 20)
$manyAcervo = Join-Path $tempRoot 'acervo-many-refs'
$manyShallow = Join-Path $manyAcervo 'shallow'
$manyDeep = Join-Path $manyAcervo 'deep\Procedure'
[void](New-Item -ItemType Directory -Path $manyShallow -Force)
[void](New-Item -ItemType Directory -Path $manyDeep -Force)
for ($i = 1; $i -le 25; $i++) {
    $refXml = @"
<Object type="$procType" name="Ref$i" guid="eeeeeeee-eeee-eeee-eeee-eeeeeeee$($i.ToString('0000'))">
  <Part type="$mainPart">
    <Source><![CDATA[// ref $guidGood]]></Source>
  </Part>
</Object>
"@
    Write-Xml -Path (Join-Path $manyShallow ("Ref{0:D2}.xml" -f $i)) -Xml $refXml
}
Write-Xml -Path (Join-Path $manyDeep 'ProcIndent.xml') -Xml $baselineXml
$r20 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $manyAcervo
Assert-True ($r20.baselineCompared -eq $true) 'sem teto de 20: Object profundo deve compared'
Assert-True ($r20.baselineStatus -eq 'compared') 'baselineStatus compared com muitos refs'
Assert-True (Test-HasCode -Result $r20 -Code 'indent-under-depth') 'com baseline profundo deve under-depth'

# 21) AcervoPath=arquivo isolado sem o GUID -> unresolved (nao new-object)
$acervoLeafWrong = Join-Path $tempRoot 'acervo-leaf-wrong.xml'
Write-Xml -Path $acervoLeafWrong -Xml (New-ProcXml -Guid $guidNew -Name 'OtherProc' -Source $baselineSource)
$r21 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $acervoLeafWrong
Assert-True ($r21.baselineStatus -eq 'no-baseline-unresolved') 'AcervoPath arquivo sem GUID deve unresolved'
Assert-True ($r21.baselineCompared -ne $true) 'folha isolada nao compared'
Assert-True ($r21.sourceIndentStatus -eq 'inconclusive') 'folha isolada inconclusive'
Assert-True (-not (Test-HasCode -Result $r21 -Code 'indent-under-depth')) 'folha isolada nao inventa under-depth'

# 22) XML oculto sob o acervo com o Object -> compared (-Force)
$hiddenAcervo = Join-Path $tempRoot 'acervo-hidden'
$hiddenDir = Join-Path $hiddenAcervo 'Procedure'
[void](New-Item -ItemType Directory -Path $hiddenDir -Force)
$hiddenXml = Join-Path $hiddenDir 'ProcIndent-hidden.xml'
Write-Xml -Path $hiddenXml -Xml $baselineXml
$hiddenItem = Get-Item -LiteralPath $hiddenXml -Force
$hiddenItem.Attributes = $hiddenItem.Attributes -bor [System.IO.FileAttributes]::Hidden
$r22 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $hiddenAcervo
Assert-True ($r22.baselineCompared -eq $true) 'XML oculto deve ser encontrado com -Force'
Assert-True ($r22.baselineStatus -eq 'compared') 'baselineStatus compared com oculto'
Assert-True (Test-HasCode -Result $r22 -Code 'indent-under-depth') 'oculto compared deve under-depth'

# 23) ExportFile com 2 Procedures: indice = 1 passagem e N leituras (nao N×Procedures)
$multiAcervo = Join-Path $tempRoot 'acervo-multi'
$multiDir = Join-Path $multiAcervo 'Procedure'
[void](New-Item -ItemType Directory -Path $multiDir -Force)
Write-Xml -Path (Join-Path $multiDir 'ProcIndent.xml') -Xml $baselineXml
$baselineSecondXml = New-ProcXml -Guid $guidSecond -Name 'ProcSecond' -Source $baselineSource
Write-Xml -Path (Join-Path $multiDir 'ProcSecond.xml') -Xml $baselineSecondXml
$multiXmlCount = @(Get-ChildItem -LiteralPath $multiAcervo -Filter *.xml -File -Recurse -Force).Count
$exportTwo = @"
<ExportFile>
  <Objects>
$(New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder)
$(New-ProcXml -Guid $guidSecond -Name 'ProcSecond' -Source $badUnder)
  </Objects>
</ExportFile>
"@
$r23 = Invoke-Indent -Xml $exportTwo -AcervoPath $multiAcervo
Assert-True ($r23.inScopePartCount -eq 2) 'ExportFile com 2 Procedures deve ter 2 parts in-scope'
Assert-True ($r23.baselineCompared -eq $true) 'indice multi-GUID deve compared'
Assert-True (@($r23.parts | Where-Object { $_.baselineStatus -eq 'compared' }).Count -eq 2) 'ambas as Procedures devem compared'
Assert-True (Test-HasCode -Result $r23 -Code 'indent-under-depth') 'multi-GUID compared deve under-depth'
Assert-True ($r23.acervoDirectoryIndexUsed -eq $true) 'acervoDirectoryIndexUsed deve ser true'
Assert-True ($r23.acervoDirectoryPrefilterPassCount -eq 1) ("prefiltro deve ter 1 passagem; obtido $($r23.acervoDirectoryPrefilterPassCount)")
Assert-True ($r23.acervoDirectoryPrefilterFileReads -eq $multiXmlCount) ("leituras devem ser $multiXmlCount (nao $($multiXmlCount * 2)); obtido $($r23.acervoDirectoryPrefilterFileReads)")
Assert-True ($multiXmlCount -eq 2) 'fixture multi deve ter 2 XMLs'

# 24) ExportFile misto: GUID ok + GUID vazio com indice montado -> vazio unresolved (nao new-object)
$exportMixedGuid = @"
<ExportFile>
  <Objects>
$(New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder)
$(New-ProcXml -Guid '' -Name 'Pnoguid' -Source $badUnder)
  </Objects>
</ExportFile>
"@
$r24 = Invoke-Indent -Xml $exportMixedGuid -AcervoPath $multiAcervo
Assert-True ($r24.inScopePartCount -eq 2) 'ExportFile misto deve ter 2 parts in-scope'
$r24ok = @($r24.parts | Where-Object { $_.objectName -eq 'ProcIndent' })[0]
$r24empty = @($r24.parts | Where-Object { $_.objectName -eq 'Pnoguid' })[0]
Assert-True ($null -ne $r24ok) 'part ProcIndent presente'
Assert-True ($null -ne $r24empty) 'part Pnoguid presente'
Assert-True ($r24ok.baselineStatus -eq 'compared') 'GUID ok deve compared com indice'
Assert-True ($r24empty.baselineStatus -eq 'no-baseline-unresolved') 'GUID vazio deve unresolved (nao new-object)'
Assert-True ($r24empty.status -eq 'inconclusive') 'GUID vazio deve status inconclusive'
Assert-True (-not (@($r24empty.findings | Where-Object { $_.code -eq 'indent-under-depth' }).Count -gt 0)) 'GUID vazio nao inventa under-depth'
Assert-True ($r24.acervoDirectoryIndexUsed -eq $true) 'indice ainda montado pelo GUID ok'

# 25) GUID com espacos nas bordas no input: indice + Find normalizados -> compared
$paddedGuidXml = @"
<Object type="$procType" name="ProcPadded" guid="  $guidGood  ">
  <Part type="$mainPart">
    <Source><![CDATA[$badUnder]]></Source>
  </Part>
</Object>
"@
$r25 = Invoke-Indent -Xml $paddedGuidXml -AcervoPath $acervoRoot
Assert-True ($r25.baselineCompared -eq $true) 'GUID com espacos deve compared apos Normalize-ObjectGuid'
Assert-True ($r25.baselineStatus -eq 'compared') 'baselineStatus compared com GUID padded'
Assert-True (Test-HasCode -Result $r25 -Code 'indent-under-depth') 'GUID padded compared deve under-depth'

# 26) GUID zero -> unresolved (nao new-object), mesmo com AcervoPath pasta
$guidZero = '00000000-0000-0000-0000-000000000000'
$r26 = Invoke-Indent -Xml (New-ProcXml -Guid $guidZero -Name 'ProcZero' -Source $badUnder) -AcervoPath $acervoRoot
Assert-True ($r26.baselineStatus -eq 'no-baseline-unresolved') 'GUID zero deve unresolved'
Assert-True ($r26.baselineCompared -ne $true) 'GUID zero nao compared'
Assert-True ($r26.sourceIndentStatus -eq 'inconclusive') 'GUID zero inconclusive'
Assert-True (-not (Test-HasCode -Result $r26 -Code 'indent-under-depth')) 'GUID zero nao inventa under-depth'

# 27) GUID nao-UUID -> unresolved (nao new-object)
$r27 = Invoke-Indent -Xml (New-ProcXml -Guid 'YOUR-GUID-HERE' -Name 'ProcInvalid' -Source $badUnder) -AcervoPath $acervoRoot
Assert-True ($r27.baselineStatus -eq 'no-baseline-unresolved') 'GUID invalido deve unresolved'
Assert-True ($r27.baselineCompared -ne $true) 'GUID invalido nao compared'
Assert-True ($r27.sourceIndentStatus -eq 'inconclusive') 'GUID invalido inconclusive'
Assert-True (-not (Test-HasCode -Result $r27 -Code 'indent-under-depth')) 'GUID invalido nao inventa under-depth'

# --- indent-context-depth-drift (wrap / recontextualizacao) ---

$guidWrap = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
$wrapBaselineSrc = @"
if &Gerar
	&Cell += 1
endif
"@
$wrapBaselineXml = New-ProcXml -Guid $guidWrap -Name 'ProcWrap' -Source $wrapBaselineSrc
Write-Xml -Path (Join-Path $acervoRoot 'ProcWrap.xml') -Xml $wrapBaselineXml

# 28) wrap sem aprofundar corpo => indent-context-depth-drift (sem Absolute)
$wrapBadSrc = @"
if &Outer
if &Gerar
	&Cell += 1
endif
endif
"@
$r28 = Invoke-Indent -Xml (New-ProcXml -Guid $guidWrap -Name 'ProcWrap' -Source $wrapBadSrc) -AcervoPath $acervoRoot
Assert-True (Test-HasCode -Result $r28 -Code 'indent-context-depth-drift') 'wrap under-indent deveria drift'
$drift28 = @($r28.findings | Where-Object { $_.code -eq 'indent-context-depth-drift' } | Select-Object -First 1)
Assert-True ($null -ne $drift28) 'finding drift presente'
Assert-True ($drift28.deltaLineClass -eq 'preserved') 'drift em preserved'
Assert-True ([int]$drift28.baselineExpectedDepth -lt [int]$drift28.expectedDepth) 'profundidade deve ter subido'

# 29) wrap com +1 nivel no bloco interno (If/corpo/Endif) => some o drift
$wrapGoodSrc = @"
if &Outer
	if &Gerar
		&Cell += 1
	endif
endif
"@
$r29 = Invoke-Indent -Xml (New-ProcXml -Guid $guidWrap -Name 'ProcWrap' -Source $wrapGoodSrc) -AcervoPath $acervoRoot
Assert-True (-not (Test-HasCode -Result $r29 -Code 'indent-context-depth-drift')) 'wrap corrigido nao deve drift'

# 30) under-depth herdado (Absolute) sem aumento de profundidade => under-depth sem drift
$r30 = Invoke-Indent -Xml (New-ProcXml -Guid $guidGood -Name 'ProcIndent' -Source $badUnder) -AcervoPath $acervoRoot -Absolute
Assert-True (Test-HasCode -Result $r30 -Code 'indent-under-depth') 'Absolute herdado ainda under-depth'
Assert-True (-not (Test-HasCode -Result $r30 -Code 'indent-context-depth-drift')) 'herdado sem depth+ nao e drift'

# 31) BaselinePath = InputPath => unresolved (nao compared util)
$samePathXml = New-ProcXml -Guid $guidWrap -Name 'ProcWrap' -Source $wrapBadSrc
$samePathFile = Join-Path $tempRoot 'same-as-baseline.xml'
Write-Xml -Path $samePathFile -Xml $samePathXml
$r31json = & $scriptPath -InputPath $samePathFile -BaselinePath $samePathFile
$r31 = $r31json | ConvertFrom-Json
Assert-True ($r31.parts[0].baselineStatus -eq 'no-baseline-unresolved') 'baseline=input deve unresolved'
Assert-True ($r31.parts[0].baselineCompared -ne $true) 'baseline=input nao compared'
Assert-True (-not (Test-HasCode -Result $r31 -Code 'indent-context-depth-drift')) 'baseline=input nao inventa drift'

# 32) AcervoPath=folha no mesmo InputPath => unresolved
$r32json = & $scriptPath -InputPath $samePathFile -AcervoPath $samePathFile
$r32 = $r32json | ConvertFrom-Json
Assert-True ($r32.parts[0].baselineStatus -eq 'no-baseline-unresolved') 'AcervoPath=input deve unresolved'
Assert-True (-not (Test-HasCode -Result $r32 -Code 'indent-context-depth-drift')) 'AcervoPath=input nao inventa drift'

# 33) unitMode=none: wrap sem recuo no corpo => drift (bifurcacao none)
$guidNone = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
$noneBase = @"
if &a
msg('x')
endif
"@
Write-Xml -Path (Join-Path $acervoRoot 'ProcNone.xml') -Xml (New-ProcXml -Guid $guidNone -Name 'ProcNone' -Source $noneBase)
$noneWrap = @"
if &o
if &a
msg('x')
endif
endif
"@
$r33 = Invoke-Indent -Xml (New-ProcXml -Guid $guidNone -Name 'ProcNone' -Source $noneWrap) -AcervoPath $acervoRoot
Assert-True (Test-HasCode -Result $r33 -Code 'indent-context-depth-drift') 'unitMode=none wrap deve drift'

# 34) reindented com profundidade aumentada e recuo curto => drift
$guidRe = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
$reBase = @"
if &a
	msg('x')
endif
"@
Write-Xml -Path (Join-Path $acervoRoot 'ProcRe.xml') -Xml (New-ProcXml -Guid $guidRe -Name 'ProcRe' -Source $reBase)
# If interno aprofundado; corpo sem tab (reindented zero + under na nova depth 2)
$reWrap = @"
if &o
	if &a
msg('x')
	endif
endif
"@
$r34 = Invoke-Indent -Xml (New-ProcXml -Guid $guidRe -Name 'ProcRe' -Source $reWrap) -AcervoPath $acervoRoot
Assert-True (Test-HasCode -Result $r34 -Code 'indent-context-depth-drift') 'reindented under apos wrap deve drift'
Assert-True (@($r34.findings | Where-Object { $_.code -eq 'indent-context-depth-drift' -and $_.deltaLineClass -eq 'reindented' }).Count -gt 0) 'classe reindented no drift'

# 35) G1: preserved com unidade divergente SEM depth+ e SEM Absolute => nao inventa unit-mismatch
# Moda tab inequívoca (2+ tabs vs 1 espaço) — empate 1/1 cairia em unitMode=mixed e vacinaria o assert
$guidUnit = 'abababab-abab-abab-abab-abababababab'
$unitBase = @"
if &x
	msg('tab1')
	msg('tab2')
 msg('space')
endif
"@
Write-Xml -Path (Join-Path $acervoRoot 'ProcUnit.xml') -Xml (New-ProcXml -Guid $guidUnit -Name 'ProcUnit' -Source $unitBase)
$r35 = Invoke-Indent -Xml (New-ProcXml -Guid $guidUnit -Name 'ProcUnit' -Source $unitBase) -AcervoPath $acervoRoot
Assert-True (-not (Test-HasCode -Result $r35 -Code 'indent-unit-mismatch-in-delta')) 'preserved unit divergente sem Absolute/sem depth+ nao e mismatch'
Assert-True (-not (Test-HasCode -Result $r35 -Code 'indent-context-depth-drift')) 'sem wrap nao e drift'
Assert-True (-not (Test-HasCode -Result $r35 -Code 'indent-inconclusive')) 'moda tab inequívoca nao deve inconclusive de mixed'

# 36) G2: wrap sobre close mismatch (inconclusiveLocal) com depth+ => indent-inconclusive (sem Absolute)
$guidInc = 'acacacac-acac-acac-acac-acacacacacac'
$incBase = @"
if &a
	msg('x')
endfor
"@
Write-Xml -Path (Join-Path $acervoRoot 'ProcInc.xml') -Xml (New-ProcXml -Guid $guidInc -Name 'ProcInc' -Source $incBase)
$incWrap = @"
if &o
if &a
	msg('x')
endfor
endif
"@
$r36 = Invoke-Indent -Xml (New-ProcXml -Guid $guidInc -Name 'ProcInc' -Source $incWrap) -AcervoPath $acervoRoot
Assert-True (Test-HasCode -Result $r36 -Code 'indent-inconclusive') 'wrap+inconclusiveLocal deve inconclusive'
Assert-True (@($r36.findings | Where-Object { $_.code -eq 'indent-inconclusive' -and $_.deltaLineClass -eq 'preserved' }).Count -gt 0) 'inconclusive em preserved apos depth+'

# 37) anti-duplicata: mesma sourceLine + mesmo code nao repete (reindented covered by Absolute loop)
$guidDup = 'adadadad-adad-adad-adad-adadadadadad'
$dupBase = @"
if &a
	msg('x')
endfor
"@
Write-Xml -Path (Join-Path $acervoRoot 'ProcDup.xml') -Xml (New-ProcXml -Guid $guidDup -Name 'ProcDup' -Source $dupBase)
# Aprofundar If interno (reindented) mantendo endfor mismatch
$dupWrap = @"
if &o
	if &a
		msg('x')
	endfor
endif
"@
$r37 = Invoke-Indent -Xml (New-ProcXml -Guid $guidDup -Name 'ProcDup' -Source $dupWrap) -AcervoPath $acervoRoot
$inc37 = @($r37.findings | Where-Object { $_.code -eq 'indent-inconclusive' })
Assert-True ($inc37.Count -gt 0) 'reindented inconclusive deve aparecer (laco Absolute)'
$dupGroups = $inc37 | Group-Object -Property sourceLineNumber
Assert-True (@($dupGroups | Where-Object { $_.Count -gt 1 }).Count -eq 0) 'indent-inconclusive nao deve duplicar por linha'
$r37abs = Invoke-Indent -Xml (New-ProcXml -Guid $guidDup -Name 'ProcDup' -Source $dupWrap) -AcervoPath $acervoRoot -Absolute
$inc37abs = @($r37abs.findings | Where-Object { $_.code -eq 'indent-inconclusive' })
$dupAbs = $inc37abs | Group-Object -Property sourceLineNumber
Assert-True (@($dupAbs | Where-Object { $_.Count -gt 1 }).Count -eq 0) 'com Absolute tambem sem duplicata de inconclusive'

# 38) unit-mismatch nao engole drift: MESMA linha preserved (ja com espaco no baseline), moda tab, depth+
$guidUm = 'aeaeaeae-aeae-aeae-aeae-aeaeaeaeaeae'
# Linha " x" ja nasce com 1 espaco (unidade divergente) em part cuja moda sera tab apos o wrap
$umBase = @"
if &Gerar
	msg('a')
	msg('b')
 x
	msg('c')
endif
"@
Write-Xml -Path (Join-Path $acervoRoot 'ProcUm.xml') -Xml (New-ProcXml -Guid $guidUm -Name 'ProcUm' -Source $umBase)
$umWrap = @"
if &Outer
	msg('k1')
	msg('k2')
if &Gerar
	msg('a')
	msg('b')
 x
	msg('c')
endif
	msg('k3')
endif
"@
$r38 = Invoke-Indent -Xml (New-ProcXml -Guid $guidUm -Name 'ProcUm' -Source $umWrap) -AcervoPath $acervoRoot
# linePreview do motor e trimado ("x"); ancora pela sourceLine da linha com espaco no Source
$drift38 = @($r38.findings | Where-Object { $_.code -eq 'indent-context-depth-drift' -and $_.deltaLineClass -eq 'preserved' -and $_.linePreview -eq 'x' })
$unit38 = @($r38.findings | Where-Object { $_.code -eq 'indent-unit-mismatch-in-delta' -and $_.deltaLineClass -eq 'preserved' -and $_.linePreview -eq 'x' })
Assert-True ($drift38.Count -gt 0) 'mesma linha preserved deve drift (unit-mismatch nao engole)'
Assert-True ($unit38.Count -gt 0) 'mesma linha preserved deve unit-mismatch a parte'
Assert-True ([int]$drift38[0].sourceLineNumber -eq [int]$unit38[0].sourceLineNumber) 'drift e unit-mismatch na mesma sourceLineNumber'
Assert-True ([int]$drift38[0].baselineExpectedDepth -lt [int]$drift38[0].expectedDepth) 'depth+ na linha do caso 38'

# 39) wrap + Absolute: drift continua (Absolute nao suprime indent-context-depth-drift)
$r39 = Invoke-Indent -Xml (New-ProcXml -Guid $guidWrap -Name 'ProcWrap' -Source $wrapBadSrc) -AcervoPath $acervoRoot -Absolute
Assert-True (Test-HasCode -Result $r39 -Code 'indent-context-depth-drift') 'Absolute+wrap ainda emite drift'

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'OK: Test-GeneXusSourceIndentationSelfTest.ps1'
