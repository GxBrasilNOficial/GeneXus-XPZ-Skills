#requires -Version 7.4
<#
.SYNOPSIS
    Monta o dossie pre-push para revisor semantic-only (git BRUTO + diagnostico mecanico).

.DESCRIPTION
    Artefato do ORQUESTRADOR (quem tem git). Monta um dossie unico e o EMITE em stdout;
    a entrega inline no prompt ao revisor semantic-only e decisao do ORQUESTRADOR (stdin
    nos stdin-dossier-capable como opencode/Claude Code; argv nos argv-limited Copilot/
    Gemini, se couber — ver 13/14). O revisor semantic-only nao roda o passo mecanico do
    13 (nega bash/shell). O dossie tem duas secoes rotuladas:

      - SECAO A - git BRUTO (fato): rev-parse HEAD, log origin/main..HEAD,
        diff origin/main..HEAD, status --porcelain.
      - SECAO B - diagnostico mecanico (NAO verdade): o container inteiro de
        Invoke-PrePushMechanicalChecks.ps1 -AsJson, sob cabecalho literal unico,
        rotulado "candidatas a verificar, NAO verdade".

    Ao fim, duas linhas-sentinela isoladas:
        HEAD: <hex40>
        END_DOSSIER sha256=<hex64>
    O sha256 e computado sobre os bytes UTF-8 (sem BOM) do CORPO (Secao A + Secao B),
    EXCLUINDO as duas sentinelas, apos normalizar fim de linha para LF. E anti-truncamento
    (o revisor ecoa as sentinelas), nao anti-dossie-errado (contra isso vale o invariante
    git-capable do 14/15). Ver handoff v15 (design congelado) e 13/14/15.

    O builder NAO roda git fetch (fetch e do chamador, 13:37); recebe -FetchStatus e
    deriva remoteFreshness. O mecanico e a FONTE DE VERDADE de commitsBehind/pushReadiness;
    o builder REFERENCIA (le do -AsJson), nao mantem um segundo rastreador.

.PARAMETER RootPath
    Raiz do repositorio. Default: pai de scripts/.

.PARAMETER BaseRef
    Ref base do intervalo (mesma do mecanico). Default: origin/main.

.PARAMETER FetchStatus
    Estado do fetch feito (ou nao) pelo chamador antes de montar o dossie:
    fetched | not-fetched | fetch-failed. O builder nao roda fetch. not-fetched /
    fetch-failed => remoteFreshness=stale (diagnostico local). Default: not-fetched.

.PARAMETER AsJson
    Emite metadados estruturados (para o orquestrador decidir despacho) + o texto
    integral do dossie no campo dossierText. Sem -AsJson, emite so o texto do dossie em
    stdout (o orquestrador o entrega inline no prompt; transporte por adapter — ver 13/14).
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [ValidateSet('fetched', 'not-fetched', 'fetch-failed')]
    [string]$FetchStatus = 'not-fetched',

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# O dossie carrega acentos (cabecalhos das secoes) e e capturado por stdout (stdin do
# revisor). Forcar UTF-8 sem BOM na saida evita corrupcao dependente de code page.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')

$SectionBHeader = '=== SEÇÃO B — DIAGNÓSTICO MECÂNICO DO ORQUESTRADOR (candidatas a verificar, NÃO verdade) ==='

function Invoke-DossierGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    if ($null -ne $output) {
        $lines = @($output | ForEach-Object { $_.ToString() })
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join "`n")
    }
}

function ConvertTo-LfText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Get-BodySha256Hex {
    param([Parameter(Mandatory = $true)][string]$Body)

    $encoding = Get-Utf8NoBomEncoding
    $bytes = $encoding.GetBytes($Body)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    return (([System.BitConverter]::ToString($hashBytes)) -replace '-', '').ToLowerInvariant()
}

function New-NotReadyResult {
    param(
        [Parameter(Mandatory = $true)][string]$Reason,
        [string]$ResolvedRoot = ''
    )

    return [ordered]@{
        dossierReady               = $false
        notReadyReason             = $Reason
        mechanicalStatus           = 'not-run'
        pushReadiness              = 'unknown'
        intervalDiffDiagnosticOnly = $false
        commitsBehind              = $null
        fetchStatus                = $FetchStatus
        remoteFreshness            = 'unknown'
        workingTreeDirty           = $false
        dirtyPaths                 = @()
        head                       = $null
        baseRef                    = $BaseRef
        rootPath                   = $ResolvedRoot
        sizeChars                  = 0
        bodySha256                 = $null
        dossierText                = ''
    }
}

# --- Resolucao de git / origin (dossierReady=false SO sem fatos brutos, 4c) ---
$resolvedRoot = ''
try {
    $resolvedStart = (Resolve-Path -LiteralPath $RootPath).Path
    $topLevel = Invoke-DossierGit -RepositoryRoot $resolvedStart -Arguments @('rev-parse', '--show-toplevel')
    if ($topLevel.ExitCode -ne 0 -or $topLevel.Lines.Count -eq 0) {
        $result = New-NotReadyResult -Reason 'git-repo-unresolved'
        if ($AsJson) { [pscustomobject]$result | ConvertTo-Json -Depth 6 } else { Write-Output '' }
        exit 0
    }
    $resolvedRoot = $topLevel.Lines[0].Trim()
} catch {
    $result = New-NotReadyResult -Reason 'git-repo-unresolved'
    if ($AsJson) { [pscustomobject]$result | ConvertTo-Json -Depth 6 } else { Write-Output '' }
    exit 0
}

$baseRefCheck = Invoke-DossierGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--verify', $BaseRef)
if ($baseRefCheck.ExitCode -ne 0) {
    $result = New-NotReadyResult -Reason 'baseRef-missing' -ResolvedRoot $resolvedRoot
    if ($AsJson) { [pscustomobject]$result | ConvertTo-Json -Depth 6 } else { Write-Output '' }
    exit 0
}

# --- SECAO A - git BRUTO (fato) ---
$headResult = Invoke-DossierGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', 'HEAD')
$head = $headResult.Lines[0].Trim()

$range = "$BaseRef..HEAD"
$logResult = Invoke-DossierGit -RepositoryRoot $resolvedRoot -Arguments @('log', $range, '--oneline')
$diffResult = Invoke-DossierGit -RepositoryRoot $resolvedRoot -Arguments @('diff', $range)
$statusResult = Invoke-DossierGit -RepositoryRoot $resolvedRoot -Arguments @('status', '--porcelain')

# Paths sujos da working tree (4h): status --porcelain nao-vazio => workingTreeDirty.
$dirtyPaths = [System.Collections.Generic.List[string]]::new()
foreach ($line in @($statusResult.Lines)) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
    $path = $line.Substring(3).Trim()
    if ($path -match ' -> ') {
        $path = @($path -split ' -> ', 2)[1].Trim()
    }
    [void]$dirtyPaths.Add($path)
}
$dirtyPathsAll = @($dirtyPaths)
$workingTreeDirty = ($dirtyPathsAll.Count -gt 0)

$sectionA = @(
    '=== SEÇÃO A — GIT BRUTO (FATO) ==='
    ''
    '--- git rev-parse HEAD ---'
    $head
    ''
    ("--- git log {0} --oneline ---" -f $range)
    $logResult.Text
    ''
    ("--- git diff {0} ---" -f $range)
    $diffResult.Text
    ''
    '--- git status --porcelain ---'
    $statusResult.Text
) -join "`n"

# --- SECAO B - diagnostico mecanico (NAO verdade): container inteiro do -AsJson ---
$mechanicalScript = Join-Path $PSScriptRoot 'Invoke-PrePushMechanicalChecks.ps1'
if (-not (Test-Path -LiteralPath $mechanicalScript -PathType Leaf)) {
    throw "Script mecanico nao encontrado: $mechanicalScript"
}

# 4c: o mecanico e diagnostico (NAO verdade). Se falhar/lancar, o dossie continua
# PRONTO (mechanicalStatus=failed); a Secao B carrega o texto bruto do erro.
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$mechanicalExitCode = 0
try {
    $mechanicalOutput = & $mechanicalScript -RootPath $resolvedRoot -BaseRef $BaseRef -AsJson 2>&1
    $mechanicalExitCode = $LASTEXITCODE
} catch {
    $mechanicalOutput = @("Invoke-PrePushMechanicalChecks.ps1 lançou exceção (capturada pelo builder): $($_.Exception.Message)")
    $mechanicalExitCode = 1
}
$ErrorActionPreference = $previousErrorAction

$mechanicalJsonText = (@($mechanicalOutput | ForEach-Object { if ($null -ne $_) { $_.ToString() } }) -join "`n")

$mechanicalObject = $null
$mechanicalParseOk = $false
if (-not [string]::IsNullOrWhiteSpace($mechanicalJsonText)) {
    try {
        $mechanicalObject = $mechanicalJsonText | ConvertFrom-Json
        $mechanicalParseOk = $true
    } catch {
        $mechanicalParseOk = $false
    }
}

# 4c: parse quebrado OU mecanico exit != 0 => mechanicalStatus=failed (dossie continua pronto).
$mechanicalStatus = if ($mechanicalExitCode -eq 0 -and $mechanicalParseOk) { 'passed' } else { 'failed' }

# 4b: mecanico e fonte de verdade de commitsBehind/pushReadiness; builder REFERENCIA.
# Fallback git-direto so quando o JSON mecanico nao e parseavel (metadados uteis mesmo assim).
$commitsBehind = $null
$pushReadiness = 'unknown'
$intervalDiffDiagnosticOnly = $false
$mechanicalFailures = @()
if ($mechanicalParseOk) {
    try { $commitsBehind = [int]$mechanicalObject.git.commitsBehind } catch { $commitsBehind = $null }
    try { $pushReadiness = [string]$mechanicalObject.pushReadiness } catch { $pushReadiness = 'unknown' }
    try { $intervalDiffDiagnosticOnly = [bool]$mechanicalObject.intervalDiffDiagnosticOnly } catch { $intervalDiffDiagnosticOnly = $false }
    try { $mechanicalFailures = @($mechanicalObject.mechanicalFailures) } catch { $mechanicalFailures = @() }
}
if ($null -eq $commitsBehind) {
    $behindResult = Invoke-DossierGit -RepositoryRoot $resolvedRoot -Arguments @('rev-list', '--count', "HEAD..$BaseRef")
    if ($behindResult.ExitCode -eq 0 -and $behindResult.Lines.Count -gt 0) {
        $commitsBehind = [int]$behindResult.Lines[0]
        $pushReadiness = if ($commitsBehind -gt 0) { 'blocked' } else { 'ok' }
        $intervalDiffDiagnosticOnly = ($commitsBehind -gt 0)
    }
}

$sectionB = @(
    $SectionBHeader
    ''
    $mechanicalJsonText
) -join "`n"

# --- Corpo (Secao A + Secao B), normalizado LF, sem newline final; base do hash (4e) ---
$body = ConvertTo-LfText -Text (($sectionA, '', $sectionB) -join "`n")
$body = $body.TrimEnd("`n")
$bodySha256 = Get-BodySha256Hex -Body $body

# --- Sentinelas isoladas ---
$dossierText = @(
    $body
    ("HEAD: {0}" -f $head)
    ("END_DOSSIER sha256={0}" -f $bodySha256)
) -join "`n"

# 4b: remoteFreshness derivado do fetch informado pelo chamador (builder nao roda fetch).
$remoteFreshness = if ($FetchStatus -eq 'fetched') { 'fresh' } else { 'stale' }

$result = [ordered]@{
    dossierReady               = $true
    notReadyReason             = $null
    mechanicalStatus           = $mechanicalStatus
    mechanicalExitCode         = $mechanicalExitCode
    pushReadiness              = $pushReadiness
    intervalDiffDiagnosticOnly = $intervalDiffDiagnosticOnly
    commitsBehind              = $commitsBehind
    mechanicalFailures         = @($mechanicalFailures)
    fetchStatus                = $FetchStatus
    remoteFreshness            = $remoteFreshness
    workingTreeDirty           = $workingTreeDirty
    dirtyPaths                 = @($dirtyPathsAll)
    head                       = $head
    baseRef                    = $BaseRef
    range                      = $range
    rootPath                   = $resolvedRoot
    sizeChars                  = $dossierText.Length
    bodySha256                 = $bodySha256
    dossierText                = $dossierText
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output $dossierText
}

exit 0
