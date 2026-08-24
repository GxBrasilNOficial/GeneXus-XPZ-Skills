#requires -Version 7.4
<#
.SYNOPSIS
    Self-test deterministico do perfil Antigravity public-review, sem CLI real nem rede.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$passed = 0
$failed = 0
function Assert-True([bool] $Condition, [string] $Message) {
    if ($Condition) { $script:passed++; Write-Host "[PASS] $Message" -ForegroundColor Green }
    else { $script:failed++; Write-Host "[FAIL] $Message" -ForegroundColor Red }
}

function Invoke-CapturedPublicReview {
    param(
        [string] $Prompt,
        [string] $ReceiptPath,
        [string] $FakeExe,
        [hashtable] $Extra = @{}
    )
    $args = @{
        Message = $Prompt
        Model = 'gemini-3.6-flash-high'
        Profile = 'public-review'
        AntigravityExe = $FakeExe
        ReceiptPath = $ReceiptPath
        TimeoutSec = 5
    }
    foreach ($key in $Extra.Keys) { $args[$key] = $Extra[$key] }
    $output = $null
    $errorText = $null
    try { $output = & $script:invokeScript @args } catch { $errorText = $_.Exception.Message }
    $receipt = if (Test-Path -LiteralPath $ReceiptPath -PathType Leaf) {
        Get-Content -LiteralPath $ReceiptPath -Raw -Encoding utf8 | ConvertFrom-Json
    } else { $null }
    return [pscustomobject]@{ output = $output; error = $errorText; receipt = $receipt }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('agy-public-review-selftest-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($tempRoot)
$invokeScript = Join-Path $PSScriptRoot 'Invoke-Antigravity.ps1'

try {
    $fakePs1 = Join-Path $tempRoot 'fake-agy.ps1'
    @'
param()
if ($args -contains '--help') { 'Usage: agy -p prompt --mode plan --output-format json --print-timeout 5s --model model'; exit 0 }
if ($args -contains '--version') { 'agy 1.1.19'; exit 0 }
$promptIndex = [array]::IndexOf($args, '-p')
$prompt = if ($promptIndex -ge 0) { [string]$args[$promptIndex + 1] } else { '' }
$safe = [regex]::Replace($prompt, '[^A-Za-z0-9_-]', '-')
$log = [ordered]@{
    prompt = $prompt
    cwd = (Get-Location).Path
    args = @($args)
    env = [ordered]@{
        USERPROFILE = $env:USERPROFILE; HOME = $env:HOME; APPDATA = $env:APPDATA
        LOCALAPPDATA = $env:LOCALAPPDATA; TEMP = $env:TEMP; TMP = $env:TMP
        XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME; XDG_DATA_HOME = $env:XDG_DATA_HOME
        XDG_CACHE_HOME = $env:XDG_CACHE_HOME; ANTIGRAVITY_HOME = $env:ANTIGRAVITY_HOME; AGY_HOME = $env:AGY_HOME
    }
}
$log | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $PSScriptRoot "invoke-$safe.json") -Encoding utf8NoBOM
switch ($prompt) {
    'AUTH0' { 'Opening authentication page in your browser'; exit 0 }
    'AUTH1' { [Console]::Error.WriteLine('Error authenticating: unauthorized'); exit 7 }
    'BADJSON' { 'not-json'; exit 0 }
    'STATUSERROR' { @{ status='ERROR'; response=''; error='backend failed' } | ConvertTo-Json -Compress; exit 0 }
    'TIMEOUT' { Start-Sleep -Seconds 3; @{ status='SUCCESS'; response='late' } | ConvertTo-Json -Compress; exit 0 }
    'CHILD' {
        $child = Start-Process pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 30') -PassThru
        Set-Content -LiteralPath (Join-Path $PSScriptRoot 'child.pid') -Value $child.Id -Encoding ascii
        @{ status='SUCCESS'; response='CHILD_OK' } | ConvertTo-Json -Compress
        exit 0
    }
    default { @{ status='SUCCESS'; response="OK:$prompt" } | ConvertTo-Json -Compress; exit 0 }
}
'@ | Set-Content -LiteralPath $fakePs1 -Encoding utf8NoBOM
    $fakeCmd = Join-Path $tempRoot 'fake-agy.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-agy.ps1" %*
'@ | Set-Content -LiteralPath $fakeCmd -Encoding ascii

    # Sucesso, flags fixas, recibo, versao e isolamento do ambiente do pai.
    $parentEnvBefore = [ordered]@{}
    foreach ($name in @('USERPROFILE','HOME','APPDATA','LOCALAPPDATA','TEMP','TMP','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME','ANTIGRAVITY_HOME','AGY_HOME')) {
        $parentEnvBefore[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    $okReceipt = Join-Path $tempRoot 'ok.receipt.json'
    $ok = Invoke-CapturedPublicReview -Prompt 'SUCCESS' -ReceiptPath $okReceipt -FakeExe $fakeCmd
    Assert-True ($ok.output -eq 'OK:SUCCESS' -and -not $ok.error) 'retorna response do envelope SUCCESS'
    Assert-True ($ok.receipt.Kind -eq 'antigravity-public-review-receipt' -and $ok.receipt.Profile -eq 'public-review') 'grava recibo tipado do perfil fixo'
    Assert-True ($ok.receipt.CliVersion -eq '1.1.19' -and $ok.receipt.CliVersionMatchesBaseline) 'recibo registra cliVersion e baseline promovida'
    Assert-True ($ok.receipt.CleanupStatus -eq 'clean' -and $ok.receipt.ScratchRemoved) 'limpeza nominal e classificada como clean'
    Assert-True ($ok.receipt.KeyringIsolation -eq 'not-isolated-global-keyring') 'recibo declara keyring global nao isolado'
    $okLog = Get-Content -LiteralPath (Join-Path $tempRoot 'invoke-SUCCESS.json') -Raw -Encoding utf8 | ConvertFrom-Json
    $argv = @($okLog.args)
    Assert-True (($argv -join ' ') -match '--mode plan' -and ($argv -join ' ') -match '--model gemini-3.6-flash-high') 'propaga somente mode plan e modelo explicito'
    Assert-True (-not (($argv -join ' ') -match '--project|--add-dir|accept-edits|dangerously-skip-permissions|approval-mode|--agent')) 'nao repassa opcoes proibidas'
    Assert-True ([string]$okLog.cwd -ne (Get-Location).Path) 'processo filho usa scratch, nao a raiz do repositorio'
    $childEnvValues = @($okLog.env.PSObject.Properties | ForEach-Object { [string]$_.Value })
    Assert-True (@($childEnvValues | Where-Object { $_ -notlike "$($ok.receipt.ScratchPath)*" }).Count -eq 0) 'ambiente redirecionado aponta integralmente ao scratch'
    $parentUnchanged = $true
    foreach ($name in $parentEnvBefore.Keys) {
        if ($parentEnvBefore[$name] -ne [Environment]::GetEnvironmentVariable($name, 'Process')) { $parentUnchanged = $false }
    }
    Assert-True $parentUnchanged 'redirecionamento nao altera o ambiente do processo pai'

    # Scratch concorrente: duas chamadas simultaneas recebem cwd unico e descartavel.
    $parallel = 1,2 | ForEach-Object -Parallel {
        $receipt = Join-Path $using:tempRoot ("parallel-$_.receipt.json")
        $out = & $using:invokeScript -Message "RUN$_" -Model gemini-3.6-flash-high -Profile public-review -AntigravityExe $using:fakeCmd -ReceiptPath $receipt -TimeoutSec 5
        [pscustomobject]@{ output=$out; receipt=(Get-Content $receipt -Raw | ConvertFrom-Json) }
    } -ThrottleLimit 2
    Assert-True (@($parallel).Count -eq 2 -and @($parallel | Where-Object { $_.output -match '^OK:RUN' }).Count -eq 2) 'duas chamadas concorrentes concluem'
    Assert-True ($parallel[0].receipt.ScratchPath -ne $parallel[1].receipt.ScratchPath) 'scratch concorrente e exclusivo por chamada'
    Assert-True ($parallel[0].receipt.ScratchRemoved -and $parallel[1].receipt.ScratchRemoved) 'scratch concorrente e removido em ambas'

    # Entradas e falhas tipadas.
    $large = Invoke-CapturedPublicReview -Prompt ('x' * 30001) -ReceiptPath (Join-Path $tempRoot 'large.json') -FakeExe $fakeCmd
    Assert-True ($large.error -match 'reason=inputTooLarge') 'prompt acima de 30000 e omitido sem truncar'
    $missing = Invoke-CapturedPublicReview -Prompt 'X' -ReceiptPath (Join-Path $tempRoot 'missing.json') -FakeExe (Join-Path $tempRoot 'missing.exe')
    Assert-True ($missing.error -match 'reason=cliMissing') 'CLI ausente usa reason cliMissing'
    $auth0 = Invoke-CapturedPublicReview -Prompt 'AUTH0' -ReceiptPath (Join-Path $tempRoot 'auth0.json') -FakeExe $fakeCmd
    Assert-True ($auth0.error -match 'reason=unauthenticated') 'autenticacao interativa com exit 0 usa unauthenticated'
    $auth1 = Invoke-CapturedPublicReview -Prompt 'AUTH1' -ReceiptPath (Join-Path $tempRoot 'auth1.json') -FakeExe $fakeCmd
    Assert-True ($auth1.error -match 'reason=unauthenticated') 'falha de autenticacao com exit diferente de zero usa unauthenticated'
    $bad = Invoke-CapturedPublicReview -Prompt 'BADJSON' -ReceiptPath (Join-Path $tempRoot 'bad.json') -FakeExe $fakeCmd
    Assert-True ($bad.error -match 'reason=invalidOutput') 'JSON invalido usa invalidOutput'
    $statusError = Invoke-CapturedPublicReview -Prompt 'STATUSERROR' -ReceiptPath (Join-Path $tempRoot 'status.json') -FakeExe $fakeCmd
    Assert-True ($statusError.error -match 'reason=processFailure') 'status ERROR usa processFailure'
    $timeout = Invoke-CapturedPublicReview -Prompt 'TIMEOUT' -ReceiptPath (Join-Path $tempRoot 'timeout.json') -FakeExe $fakeCmd -Extra @{ TimeoutSec=1 }
    Assert-True ($timeout.error -match 'reason=timeout') 'timeout usa reason timeout'
    $cdOverride = Invoke-CapturedPublicReview -Prompt 'X' -ReceiptPath (Join-Path $tempRoot 'cd.json') -FakeExe $fakeCmd -Extra @{ Cd=$tempRoot }
    Assert-True ($cdOverride.error -match 'reason=unsafeWorkspace') 'override de Cd e recusado'

    # Workspace: vazio e seguro ja foi provado pelo sucesso; agora .git, raiz de repo, raiz de KB e reparse.
    $gitScratch = Join-Path $tempRoot 'git-scratch'; [void][IO.Directory]::CreateDirectory((Join-Path $gitScratch '.git'))
    $gitCase = Invoke-CapturedPublicReview -Prompt 'X' -ReceiptPath (Join-Path $tempRoot 'git.json') -FakeExe $fakeCmd -Extra @{ ScratchPath=$gitScratch }
    Assert-True ($gitCase.error -match 'reason=unsafeWorkspace' -and $gitCase.receipt.Workspace.hasGit) 'scratch com .git e recusado'
    $repoCase = Invoke-CapturedPublicReview -Prompt 'X' -ReceiptPath (Join-Path $tempRoot 'repo.json') -FakeExe $fakeCmd -Extra @{ ScratchPath=(Split-Path $PSScriptRoot -Parent) }
    Assert-True ($repoCase.error -match 'reason=unsafeWorkspace' -and $repoCase.receipt.Workspace.insideRepository) 'raiz de repositorio e recusada'
    $kbScratch = Join-Path $tempRoot 'kb-root'; [void][IO.Directory]::CreateDirectory((Join-Path $kbScratch 'ObjetosDaKbEmXml'))
    $kbCase = Invoke-CapturedPublicReview -Prompt 'X' -ReceiptPath (Join-Path $tempRoot 'kb.json') -FakeExe $fakeCmd -Extra @{ ScratchPath=$kbScratch }
    Assert-True ($kbCase.error -match 'reason=unsafeWorkspace' -and $kbCase.receipt.Workspace.insideParallelKb) 'raiz de KB paralela e recusada'
    $junctionTarget = Join-Path $tempRoot 'junction-target'; [void][IO.Directory]::CreateDirectory($junctionTarget)
    $junctionPath = Join-Path $tempRoot 'junction-scratch'
    try {
        $null = New-Item -ItemType Junction -Path $junctionPath -Target $junctionTarget -ErrorAction Stop
        $junctionCase = Invoke-CapturedPublicReview -Prompt 'X' -ReceiptPath (Join-Path $tempRoot 'junction.json') -FakeExe $fakeCmd -Extra @{ ScratchPath=$junctionPath }
        Assert-True ($junctionCase.error -match 'reason=unsafeWorkspace' -and $junctionCase.receipt.Workspace.hasReparsePoint) 'scratch reparse point e recusado'
    } catch {
        Write-Host "[SKIP] Junction indisponivel: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Descendente e semantica limpa/degradada/falha.
    $childCase = Invoke-CapturedPublicReview -Prompt 'CHILD' -ReceiptPath (Join-Path $tempRoot 'child.json') -FakeExe $fakeCmd
    Assert-True ($childCase.output -eq 'CHILD_OK' -and @($childCase.receipt.AliveDescendantsAfterCleanup).Count -eq 0 -and $childCase.receipt.CleanupStatus -ne 'failed') 'descendente observado nao permanece vivo apos limpeza'
    $degraded = Invoke-CapturedPublicReview -Prompt 'DEGRADED' -ReceiptPath (Join-Path $tempRoot 'degraded.json') -FakeExe $fakeCmd -Extra @{ SimulateCleanupFailure='degraded' }
    Assert-True ($degraded.output -eq 'OK:DEGRADED' -and $degraded.receipt.CleanupStatus -eq 'degraded' -and $degraded.receipt.Reason -eq 'cleanupIncomplete') 'limpeza degradada preserva parecer mas nao promove smoke limpo'
    $failedCleanup = Invoke-CapturedPublicReview -Prompt 'FAILED' -ReceiptPath (Join-Path $tempRoot 'failed.json') -FakeExe $fakeCmd -Extra @{ SimulateCleanupFailure='failed' }
    Assert-True ($failedCleanup.error -match 'reason=cleanupIncomplete' -and $failedCleanup.receipt.CleanupStatus -eq 'failed' -and -not $failedCleanup.receipt.ResponseAccepted) 'limpeza falha invalida aceite e usa cleanupIncomplete'

} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Resultado do autoteste: $passed passou, $failed falhou."
if ($failed -gt 0) { exit 1 }
Write-Host 'ANTIGRAVITY_PUBLIC_REVIEW_SELFTEST_OK'
