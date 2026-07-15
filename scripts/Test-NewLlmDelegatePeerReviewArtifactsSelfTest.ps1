#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do preparador transacional New-LlmDelegatePeerReviewArtifacts.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Deterministico, sem backends reais nem rede. Cobre: sucesso com -ManuscriptText inline e -ManuscriptPath;
    saida JSON uma linha; artefatos, manifesto, hashes, UTF-8 sem BOM, acentos pt-BR; manuscrito vazio/whitespace;
    JSON malformado; reviewers sem backend/invokeArgs; raiz array preservada com um unico revisor;
    UTF-8 invalido em arquivos de entrada; RoundId inseguro; colisao de diretorio final;
    falha injetada afterManuscript/beforePublish sem diretorio final e staging limpo;
    prova que o preparador NAO chama dispatcher nem adapters.

    O preparador e invocado como PROCESSO FILHO (pwsh -File) com stdout/stderr redirecionados a arquivos.

    Sentinela de sucesso: OK: Test-NewLlmDelegatePeerReviewArtifactsSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
$preparer = Join-Path $scriptsDir 'New-LlmDelegatePeerReviewArtifacts.ps1'
if (-not (Test-Path -LiteralPath $preparer -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $preparer" }

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-artifacts-selftest-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tmp) | Out-Null
$ledgerRoot = Join-Path $tmp 'ledger'

function Invoke-Preparer {
    param(
        [hashtable] $ArgsHashtable,
        [switch] $NoRoundId,
        [switch] $FromFile
    )
    $rid = if ($ArgsHashtable.ContainsKey('RoundId')) { $ArgsHashtable['RoundId'] } else { [guid]::NewGuid().ToString('N') }
    # Sanitizar rid para uso em caminhos de arquivo no harness (evita .. \ /)
    $ridSafe = $rid -replace '[\\/.:*?"<>|]', '_'
    $oFile = Join-Path $tmp "out-$ridSafe.txt"
    $eFile = Join-Path $tmp "err-$ridSafe.txt"

    $argList = @('-NoProfile', '-File', $preparer)

    if (-not $NoRoundId) {
        $argList += @('-RoundId', $rid)
    }

    # ProcessStartInfo.ArgumentList preserva argumentos com espacos/newlines/quotes.
    # ReviewersJson continua por arquivo para manter o harness de teste legivel e focado.
    if ($ArgsHashtable.ContainsKey('ManuscriptText')) {
        $argList += @('-ManuscriptText', $ArgsHashtable['ManuscriptText'])
    }
    if ($ArgsHashtable.ContainsKey('ManuscriptPath')) {
        $argList += @('-ManuscriptPath', $ArgsHashtable['ManuscriptPath'])
    }
    if ($ArgsHashtable.ContainsKey('ReviewersJson')) {
        $revTemp = Join-Path $tmp "rev-$ridSafe.json"
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($revTemp, $ArgsHashtable['ReviewersJson'], $utf8NoBom)
        $argList += @('-ReviewersJson', $revTemp)
    }
    if ($ArgsHashtable.ContainsKey('ReviewersJsonPath')) {
        $argList += @('-ReviewersJson', $ArgsHashtable['ReviewersJsonPath'])
    }
    if ($ArgsHashtable.ContainsKey('TempDir')) {
        $argList += @('-TempDir', $ArgsHashtable['TempDir'])
    }
    if ($ArgsHashtable.ContainsKey('FailAt')) {
        $argList += @('-FailAt', $ArgsHashtable['FailAt'])
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'pwsh'
    foreach ($arg in $argList) {
        [void]$psi.ArgumentList.Add([string]$arg)
    }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()
    [void]$p.WaitForExit(60000)
    $stdoutTask.Wait()
    $stderrTask.Wait()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    [System.IO.File]::WriteAllText($oFile, $stdout, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($eFile, $stderr, [System.Text.UTF8Encoding]::new($false))
    if ($null -eq $stdout) { $stdout = '' }
    if ($null -eq $stderr) { $stderr = '' }
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { try { $json = ($stdout.Trim() -split "`r?`n" | Select-Object -Last 1) | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{ stdout = $stdout; stderr = $stderr; exit = $p.ExitCode; json = $json; roundId = $rid }
}

# =======================================================================================
# 1) SUCESSO COM -ManuscriptText INLINE
# =======================================================================================
$manuscriptPt = "# Revisão de plano de teste`n`nConteúdo com acentuação pt-BR: revisão, dedução, ação."
$reviewersValid = '[{"backend":"opencode","invokeArgs":{}},{"backend":"codex","invokeArgs":{"model":"gpt-5.5"}}]'

$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
}
Assert-True ($null -ne $r.json) 'inline success: deveria emitir JSON no stdout'
Assert-True ($r.json.Kind -eq 'xpz-llm-peer-review-artifacts-result') 'inline success: Kind PascalCase'
Assert-True ([int]$r.json.SchemaVersion -eq 1) 'inline success: SchemaVersion=1'
Assert-True ($r.json.success -eq $true) 'inline success: success=true'
Assert-True ($r.json.roundStarted -eq $false) 'inline success: roundStarted=false'
Assert-True ($r.json.dispatchStarted -eq $false) 'inline success: dispatchStarted=false'
Assert-True ([int]$r.json.reviewersDispatched -eq 0) 'inline success: reviewersDispatched=0'
Assert-True ($r.exit -eq 0) 'inline success: exit 0'

# stderr nao deve conter BLOCK
Assert-True ($r.stderr -notmatch 'BLOCK') 'inline success: stderr sem BLOCK'

# Verificar arquivos
$artifactDir = Join-Path $ledgerRoot $r.roundId
Assert-True (Test-Path -LiteralPath $artifactDir -PathType Container) 'inline success: diretorio final existe'

$msPath = Join-Path $artifactDir 'manuscript.md'
$revPath = Join-Path $artifactDir 'reviewers.json'
$maniPath = Join-Path $artifactDir 'preparation-manifest.json'
Assert-True (Test-Path -LiteralPath $msPath -PathType Leaf) 'inline success: manuscript.md existe'
Assert-True (Test-Path -LiteralPath $revPath -PathType Leaf) 'inline success: reviewers.json existe'
Assert-True (Test-Path -LiteralPath $maniPath -PathType Leaf) 'inline success: preparation-manifest.json existe'

# ---------------------------------------------------------------------------------------
# 1a) UTF-8 sem BOM no manuscript.md
# ---------------------------------------------------------------------------------------
$msBytes = [System.IO.File]::ReadAllBytes($msPath)
if ($msBytes.Length -ge 3) {
    Assert-True (-not ($msBytes[0] -eq 0xEF -and $msBytes[1] -eq 0xBB -and $msBytes[2] -eq 0xBF)) 'manuscript.md: sem BOM UTF-8'
}

# ---------------------------------------------------------------------------------------
# 1b) Conteudo preservado com acentos pt-BR
# ---------------------------------------------------------------------------------------
$msContent = Get-Content -LiteralPath $msPath -Raw -Encoding utf8
Assert-True ($msContent -eq $manuscriptPt) "manuscript.md: conteudo preservado; esperado '$manuscriptPt'; got '$msContent'"
Assert-True ($msContent -match 'revisão') 'manuscript.md: acento pt-BR preservado (revisão)'
Assert-True ($msContent -match 'dedução') 'manuscript.md: acento pt-BR preservado (dedução)'
Assert-True ($msContent -match 'ação') 'manuscript.md: acento pt-BR preservado (ação)'

# ---------------------------------------------------------------------------------------
# 1c) reviewers.json valido e sem BOM
# ---------------------------------------------------------------------------------------
$revBytes = [System.IO.File]::ReadAllBytes($revPath)
if ($revBytes.Length -ge 3) {
    Assert-True (-not ($revBytes[0] -eq 0xEF -and $revBytes[1] -eq 0xBB -and $revBytes[2] -eq 0xBF)) 'reviewers.json: sem BOM UTF-8'
}
$revContent = Get-Content -LiteralPath $revPath -Raw -Encoding utf8
$revParsed = $revContent | ConvertFrom-Json -NoEnumerate
Assert-True ($revParsed -is [System.Array]) 'reviewers.json: raiz array preservada'
Assert-True (@($revParsed).Count -eq 2) 'reviewers.json: 2 revisores'
Assert-True ($revParsed[0].backend -eq 'opencode') 'reviewers.json: backend=opencode'

# ---------------------------------------------------------------------------------------
# 1d) Manifesto
# ---------------------------------------------------------------------------------------
$mani = Get-Content -LiteralPath $maniPath -Raw -Encoding utf8 | ConvertFrom-Json
Assert-True ($mani.Kind -eq 'xpz-llm-peer-review-artifacts-manifest') 'manifest: Kind PascalCase'
Assert-True ([int]$mani.SchemaVersion -eq 1) 'manifest: SchemaVersion=1'
Assert-True ($mani.roundId -eq $r.roundId) 'manifest: roundId casa'
Assert-True ($mani.encoding -eq 'utf-8-no-bom') 'manifest: encoding=utf-8-no-bom'
Assert-True ($mani.manuscriptSource -eq 'inline') 'manifest: manuscriptSource=inline'
Assert-True ([int]$mani.reviewerCount -eq 2) 'manifest: reviewerCount=2'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$mani.artifacts.manuscript.sha256)) 'manifest: manuscript sha256 preenchido'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$mani.artifacts.reviewers.sha256)) 'manifest: reviewers sha256 preenchido'
Assert-True ($mani.artifacts.manuscript.filename -eq 'manuscript.md') 'manifest: manuscript filename'
Assert-True ($mani.artifacts.reviewers.filename -eq 'reviewers.json') 'manifest: reviewers filename'
Assert-True ([int]$mani.artifacts.manuscript.size -gt 0) 'manifest: manuscript size > 0'
Assert-True ([int]$mani.artifacts.reviewers.size -gt 0) 'manifest: reviewers size > 0'

# ---------------------------------------------------------------------------------------
# 1e) Hashes do stdout batem com arquivos reais
# ---------------------------------------------------------------------------------------
$msRealHash = (Get-FileHash -LiteralPath $msPath -Algorithm SHA256).Hash
$revRealHash = (Get-FileHash -LiteralPath $revPath -Algorithm SHA256).Hash
Assert-True ($r.json.hashes.manuscript -eq $msRealHash) 'stdout manuscript hash casa com arquivo real'
Assert-True ($r.json.hashes.reviewers -eq $revRealHash) 'stdout reviewers hash casa com arquivo real'

# ---------------------------------------------------------------------------------------
# 1f) Artifact paths no stdout
# ---------------------------------------------------------------------------------------
Assert-True ($r.json.artifactPaths.manuscript -eq $msPath) 'stdout artifactPaths.manuscript correto'
Assert-True ($r.json.artifactPaths.reviewers -eq $revPath) 'stdout artifactPaths.reviewers correto'
Assert-True ($r.json.artifactPaths.manifest -eq $maniPath) 'stdout artifactPaths.manifest correto'

# =======================================================================================
# 1g) REVIEWERS COM UM UNICO ITEM CONTINUA ARRAY
# =======================================================================================
$reviewersSingle = '[{"backend":"opencode","invokeArgs":{}}]'
$rSingle = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersSingle
    TempDir        = $ledgerRoot
}
Assert-True ($rSingle.json.success -eq $true) 'single-reviewer: success=true'
$singleRevPath = Join-Path (Join-Path $ledgerRoot $rSingle.roundId) 'reviewers.json'
$singleRevContent = Get-Content -LiteralPath $singleRevPath -Raw -Encoding utf8
Assert-True ($singleRevContent.TrimStart().StartsWith('[')) 'single-reviewer: reviewers.json deve iniciar com array'
$singleRevParsed = $singleRevContent | ConvertFrom-Json -NoEnumerate
Assert-True ($singleRevParsed -is [System.Array]) 'single-reviewer: raiz array preservada'
Assert-True (@($singleRevParsed).Count -eq 1) 'single-reviewer: array com 1 item'
Assert-True ($singleRevParsed[0].backend -eq 'opencode') 'single-reviewer: backend preservado'

# =======================================================================================
# 1h) SUCESSO COM -ManuscriptPath (arquivo)
# =======================================================================================
$msFile = Join-Path $tmp 'manuscrito-utf8.md'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($msFile, $manuscriptPt, $utf8NoBom)
$r2 = Invoke-Preparer -ArgsHashtable @{
    ManuscriptPath = $msFile
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
}
Assert-True ($r2.json.success -eq $true) 'ManuscriptPath: success=true'
Assert-True ($r2.exit -eq 0) 'ManuscriptPath: exit 0'
$artifactDir2 = Join-Path $ledgerRoot $r2.roundId
$msPath2 = Join-Path $artifactDir2 'manuscript.md'
$msContent2 = Get-Content -LiteralPath $msPath2 -Raw -Encoding utf8
Assert-True ($msContent2 -eq $manuscriptPt) 'ManuscriptPath: conteudo preservado'
$mani2 = Get-Content -LiteralPath (Join-Path $artifactDir2 'preparation-manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
Assert-True ($mani2.manuscriptSource -eq 'file') 'ManuscriptPath: manuscriptSource=file'

# =======================================================================================
# 1i) UTF-8 INVALIDO EM ARQUIVOS DE ENTRADA -> FALHA
# =======================================================================================
$badUtf8Manuscript = Join-Path $tmp 'manuscrito-invalid-utf8.md'
[System.IO.File]::WriteAllBytes($badUtf8Manuscript, [byte[]](0x61, 0xFF, 0x62))
$rBadMs = Invoke-Preparer -ArgsHashtable @{
    ManuscriptPath = $badUtf8Manuscript
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
}
Assert-True ($rBadMs.json.success -eq $false) 'utf8-manuscript: success=false'
Assert-True ($rBadMs.json.failureCode -eq 'manuscript-utf8-invalid') "utf8-manuscript: manuscript-utf8-invalid; got $($rBadMs.json.failureCode)"
Assert-True ($rBadMs.exit -eq 1) 'utf8-manuscript: exit 1'

$badUtf8Reviewers = Join-Path $tmp 'reviewers-invalid-utf8.json'
[System.IO.File]::WriteAllBytes($badUtf8Reviewers, [byte[]](0x5B, 0x7B, 0xFF, 0x7D, 0x5D))
$rBadRev = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText     = $manuscriptPt
    ReviewersJsonPath  = $badUtf8Reviewers
    TempDir            = $ledgerRoot
}
Assert-True ($rBadRev.json.success -eq $false) 'utf8-reviewers: success=false'
Assert-True ($rBadRev.json.failureCode -eq 'reviewers-utf8-invalid') "utf8-reviewers: reviewers-utf8-invalid; got $($rBadRev.json.failureCode)"
Assert-True ($rBadRev.exit -eq 1) 'utf8-reviewers: exit 1'

# =======================================================================================
# 2) SAIDA JSON = EXATAMENTE 1 LINHA
# =======================================================================================
# (ja validado no stdout do caso de sucesso)
$stdoutTrim = $r.stdout.TrimEnd("`r", "`n")
Assert-True (@($stdoutTrim -split "`n").Count -eq 1) 'stdout: exatamente 1 linha'

# =======================================================================================
# 3) MANUSCRITO VAZIO / WHITESPACE -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = ''
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'vazio: success=false'
Assert-True ($r.json.failureCode -eq 'manuscript-empty') "vazio: manuscript-empty; got $($r.json.failureCode)"
Assert-True ($r.exit -eq 1) 'vazio: exit 1'
Assert-True ($r.stderr -match 'BLOCK') 'vazio: stderr com BLOCK'

$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = '   '
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'whitespace: success=false'
Assert-True ($r.json.failureCode -eq 'manuscript-empty') 'whitespace: manuscript-empty'

# =======================================================================================
# 4) JSON MALFORMADO -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = '{lixo-nao-json'
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'json-invalido: success=false'
Assert-True ($r.json.failureCode -eq 'reviewers-json-invalid') "json-invalido: reviewers-json-invalid; got $($r.json.failureCode)"
Assert-True ($r.exit -eq 1) 'json-invalido: exit 1'

# =======================================================================================
# 5) REVIEWERS SEM BACKEND -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = '[{"invokeArgs":{}}]'
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'sem-backend: success=false'
Assert-True ($r.json.failureCode -eq 'reviewer-missing-backend') "sem-backend: reviewer-missing-backend; got $($r.json.failureCode)"

# =======================================================================================
# 6) REVIEWERS COM RAIZ NAO ARRAY -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = '{"backend":"opencode","invokeArgs":{}}'
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'root-nao-array: success=false'
Assert-True ($r.json.failureCode -eq 'reviewers-root-not-array') "root-nao-array: reviewers-root-not-array; got $($r.json.failureCode)"

# =======================================================================================
# 7) REVIEWERS SEM invokeArgs -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = '[{"backend":"opencode"}]'
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'sem-invokeargs: success=false'
Assert-True ($r.json.failureCode -eq 'reviewer-missing-invokeArgs') "sem-invokeargs: reviewer-missing-invokeArgs; got $($r.json.failureCode)"

# =======================================================================================
# 8) REVIEWERS COM invokeArgs NAO OBJETO -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = '[{"backend":"opencode","invokeArgs":"nao-objeto"}]'
    TempDir        = $ledgerRoot
}
Assert-True ($r.json.success -eq $false) 'invokeargs-nao-objeto: success=false'
Assert-True ($r.json.failureCode -eq 'reviewer-invalid-invokeArgs') "invokeargs-nao-objeto: reviewer-invalid-invokeArgs; got $($r.json.failureCode)"

# =======================================================================================
# 9) ROUNDID INSEGURO -> FALHA
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
    RoundId        = 'bad$round!'
}
Assert-True ($r.json.success -eq $false) 'roundid-unsafe: success=false'
Assert-True ($r.json.failureCode -eq 'roundId-unsafe-chars') "roundid-unsafe: roundId-unsafe-chars; got $($r.json.failureCode)"

$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
    RoundId        = '../escape'
}
Assert-True ($r.json.success -eq $false) 'roundid-trav: success=false'
Assert-True ($r.json.failureCode -eq 'roundId-unsafe-chars') "roundid-trav: roundId-unsafe-chars; got $($r.json.failureCode)"

$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
    RoundId        = 'a\b'
}
Assert-True ($r.json.success -eq $false) 'roundid-backslash: success=false'
Assert-True ($r.json.failureCode -eq 'roundId-unsafe-chars') "roundid-backslash: roundId-unsafe-chars; got $($r.json.failureCode)"

# =======================================================================================
# 10) COLISAO COM DIRETORIO FINAL EXISTENTE -> FALHA
# =======================================================================================
$collisionRid = 'collision-' + [guid]::NewGuid().ToString('N')
$collisionDir = Join-Path $ledgerRoot $collisionRid
[System.IO.Directory]::CreateDirectory($collisionDir) | Out-Null

$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
    RoundId        = $collisionRid
}
Assert-True ($r.json.success -eq $false) 'collision: success=false'
Assert-True ($r.json.failureCode -eq 'final-dir-exists') "collision: final-dir-exists; got $($r.json.failureCode)"
Assert-True ($r.exit -eq 1) 'collision: exit 1'

Remove-Item -LiteralPath $collisionDir -Recurse -Force -ErrorAction SilentlyContinue

# =======================================================================================
# 11) FALHA INJETADA afterManuscript -> SEM DIRETORIO FINAL, STAGING LIMPO
# =======================================================================================
$failRid = 'fail-am-' + [guid]::NewGuid().ToString('N')
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
    RoundId        = $failRid
    FailAt         = 'afterManuscript'
}
Assert-True ($r.json.success -eq $false) 'afterManuscript: success=false'
Assert-True ($r.json.failureCode -eq 'injected-failure') "afterManuscript: injected-failure; got $($r.json.failureCode)"
Assert-True ($r.exit -eq 1) 'afterManuscript: exit 1'

# Diretorio final NAO deve existir
$finalAfterAM = Join-Path $ledgerRoot $failRid
Assert-True (-not (Test-Path -LiteralPath $finalAfterAM -PathType Container)) 'afterManuscript: diretorio final NAO existe'

# Nenhum staging .prepare-* deve permanecer
$stagingLeftovers = @(Get-ChildItem -LiteralPath $ledgerRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '.prepare-*' })
Assert-True ($stagingLeftovers.Count -eq 0) "afterManuscript: nenhum staging residual; encontrados=$($stagingLeftovers.Count)"

# =======================================================================================
# 12) FALHA INJETADA beforePublish -> SEM DIRETORIO FINAL, STAGING LIMPO
# =======================================================================================
$failRid = 'fail-bp-' + [guid]::NewGuid().ToString('N')
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
    RoundId        = $failRid
    FailAt         = 'beforePublish'
}
Assert-True ($r.json.success -eq $false) 'beforePublish: success=false'
Assert-True ($r.json.failureCode -eq 'injected-failure') "beforePublish: injected-failure; got $($r.json.failureCode)"
Assert-True ($r.exit -eq 1) 'beforePublish: exit 1'

$finalAfterBP = Join-Path $ledgerRoot $failRid
Assert-True (-not (Test-Path -LiteralPath $finalAfterBP -PathType Container)) 'beforePublish: diretorio final NAO existe'

$stagingLeftovers = @(Get-ChildItem -LiteralPath $ledgerRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '.prepare-*' })
Assert-True ($stagingLeftovers.Count -eq 0) "beforePublish: nenhum staging residual; encontrados=$($stagingLeftovers.Count)"

# =======================================================================================
# 13) PROVA QUE O PREPARADOR NAO CHAMA DISPATCHER NEM ADAPTERS
# =======================================================================================
# Verifica estaticamente que o script nao referencia os adapters nem o dispatcher
$preparerText = Get-Content -LiteralPath $preparer -Raw -Encoding utf8
Assert-True ($preparerText -notmatch 'Invoke-OpenCode') 'nao chama adapters: sem Invoke-OpenCode'
Assert-True ($preparerText -notmatch 'Invoke-Codex') 'nao chama adapters: sem Invoke-Codex'
Assert-True ($preparerText -notmatch 'Invoke-ClaudeCode') 'nao chama adapters: sem Invoke-ClaudeCode'
Assert-True ($preparerText -notmatch 'Invoke-Copilot') 'nao chama adapters: sem Invoke-Copilot'
Assert-True ($preparerText -notmatch 'Invoke-Gemini') 'nao chama adapters: sem Invoke-Gemini'
Assert-True ($preparerText -notmatch 'Start-OpenCodeJob') 'nao chama adapters: sem Start-OpenCodeJob'
Assert-True ($preparerText -notmatch '& .*Invoke-LlmDelegatePanelDispatch') 'nao chama dispatcher: sem chamada a PanelDispatch'

# =======================================================================================
# 14) ROUNDID PADRAO (guid when omitted)
# =======================================================================================
$r = Invoke-Preparer -ArgsHashtable @{
    ManuscriptText = $manuscriptPt
    ReviewersJson  = $reviewersValid
    TempDir        = $ledgerRoot
} -NoRoundId
Assert-True ($r.json.roundId -match '^[0-9a-f]{32}$') "RoundId default: deveria gerar guid 'N'; got '$($r.json.roundId)'"

Write-Output 'OK: Test-NewLlmDelegatePeerReviewArtifactsSelfTest.ps1'
