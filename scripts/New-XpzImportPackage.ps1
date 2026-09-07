#requires -Version 7.4
<#
.SYNOPSIS
    Cria um import_file.xml a partir de uma frente local da pasta paralela da KB.

.DESCRIPTION
    Wrapper fino para scripts\New-XpzImportPackage.py. Mantem um ponto de entrada
    PowerShell curto para allowlist local, deixando a montagem XML no motor Python.
    Quando -ReportPath e informado, publica um relatorio atomico e fail-closed da
    execucao e endurece o pos-inventario (FailOnDeltaMismatch + FailOnUnknownTypes);
    o relatorio nao e prova de importacao, build ou evidencia da IDE.

.PARAMETER RepoRoot
    Raiz da pasta paralela da KB.

.PARAMETER FrontName
    Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD.

.PARAMETER NN
    Rodada curta do pacote. Default: 01.

.PARAMETER TemplatePackagePath
    Pacote import_file.xml ou XPZ real comparavel para clonar KMW, Source,
    Dependencies e ObjectsIdentityMapping.

.PARAMETER AcervoPath
    Caminho para a pasta do acervo oficial. Quando omitido, resolve
    <RepoRoot>\ObjetosDaKbEmXml.

.PARAMETER ReportPath
    Caminho absoluto, novo e terminado em .json para o relatorio de execucao.
    A pasta pai deve existir e nao pode ser area de fonte, acervo, script,
    inteligencia, historico, PacotesGeradosParaImportacaoNaKbNoGenexus
    ou artefato do pacote.
    Com ReportPath valido, o pos-inventario do wrapper liga FailOnDeltaMismatch
    e FailOnUnknownTypes; inventoryExitCode diferente de 0 pode marcar
    status=bloqueado no stdout e alterar o exit do empacotamento. Sem ReportPath,
    o inventario corre em modo informativo e nao promove esse exit.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [string]$AcervoPath,

    [string]$ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:reportContext = $null
$script:reportEnabled = -not [string]::IsNullOrWhiteSpace($ReportPath)
$script:activeChildProcess = $null
$script:activeChildStdoutTask = $null
$script:activeChildStderrTask = $null
$script:preserveRunningReport = $false
$script:stdoutNoiseDetected = $false
$script:lastChildStderr = ''
$script:lastChildStderrTruncated = $false

$reportSupportPath = Join-Path $PSScriptRoot 'XpzExecutionReportSupport.ps1'
if (-not (Test-Path -LiteralPath $reportSupportPath -PathType Leaf)) {
    throw "suporte do relatorio de execucao nao encontrado: $reportSupportPath"
}
. $reportSupportPath

function ConvertTo-XpzPackageJson {
    param([Parameter(Mandatory = $true)][object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 12)
}

function Get-XpzPropertyValue {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $InputObject) { return $Default }
    if ($InputObject -is [Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-XpzCappedText {
    param(
        [AllowNull()][string]$Text,
        [int]$Maximum = 32768
    )

    if ($null -eq $Text) { return [pscustomobject]@{ text = ''; truncated = $false } }
    if ($Text.Length -le $Maximum) { return [pscustomobject]@{ text = $Text; truncated = $false } }
    return [pscustomobject]@{ text = $Text.Substring($Text.Length - $Maximum); truncated = $true }
}

function Stop-XpzActiveChild {
    param([switch]$Kill)

    $process = $script:activeChildProcess
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited -and $Kill) { $process.Kill($true) }
        } catch { }
        try { [void]$process.WaitForExit(5000) } catch { }
    }
    foreach ($task in @($script:activeChildStdoutTask, $script:activeChildStderrTask)) {
        if ($null -ne $task) { try { [void]$task.Wait(5000) } catch { } }
    }
}

function Invoke-XpzChildProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [scriptblock]$OnHeartbeat,
        [int]$HeartbeatSeconds = 5
    )

    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    foreach ($argument in $Arguments) { [void]$psi.ArgumentList.Add([string]$argument) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $script:activeChildProcess = $process
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $script:activeChildStdoutTask = $stdoutTask
        $script:activeChildStderrTask = $stderrTask
        $nextHeartbeat = [DateTime]::UtcNow.AddSeconds($HeartbeatSeconds)
        while (-not $process.WaitForExit(250)) {
            if ($null -ne $OnHeartbeat -and [DateTime]::UtcNow -ge $nextHeartbeat) {
                [void](& $OnHeartbeat)
                $nextHeartbeat = [DateTime]::UtcNow.AddSeconds($HeartbeatSeconds)
            }
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        return [pscustomobject]@{ exitCode = $process.ExitCode; stdout = $stdout; stderr = $stderr; timedOut = $false }
    } finally {
        $script:activeChildProcess = $null
        $script:activeChildStdoutTask = $null
        $script:activeChildStderrTask = $null
        $process.Dispose()
    }
}

function ConvertFrom-XpzStrictJson {
    param(
        [AllowNull()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Producer
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { throw "$Producer nao produziu JSON em stdout" }
    try { return ($Text | ConvertFrom-Json -ErrorAction Stop) }
    catch {
        $script:stdoutNoiseDetected = $true
        throw "$Producer produziu stdout que nao e um unico JSON: $($_.Exception.Message)"
    }
}

function Write-XpzChildStderr {
    param([AllowNull()][string]$Text)

    if (-not [string]::IsNullOrEmpty($Text)) {
        [Console]::Error.Write($Text)
        if (-not $Text.EndsWith("`n")) { [Console]::Error.WriteLine() }
    }
}

function Complete-XpzReportFromResult {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [int]$ProcessExitCode
    )

    if ($null -eq $script:reportContext -or $script:preserveRunningReport) { return }

    $existingReport = Get-XpzExecutionReportSnapshot -Context $script:reportContext
    if ($null -ne (Get-XpzPropertyValue -InputObject $existingReport -Name 'completedAtUtc')) {
        return
    }

    $status = [string](Get-XpzPropertyValue -InputObject $InputObject -Name 'status' -Default 'erro')
    $rejected = Get-XpzPropertyValue -InputObject $InputObject -Name 'rejectedPath'
    $output = Get-XpzPropertyValue -InputObject $InputObject -Name 'outputPath'
    $packageState = 'not-written'
    if (-not [string]::IsNullOrWhiteSpace([string]$rejected)) { $packageState = 'rejected' }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$output)) { $packageState = 'candidate' }
    $executionState = 'completed'
    if ($ExitCode -ne 0) {
        if ($status -eq 'bloqueado') { $executionState = 'blocked' } else { $executionState = 'error' }
    }
    $stage = [string](Get-XpzPropertyValue -InputObject $InputObject -Name 'stage' -Default 'completed')
    $stderrText = [string](Get-XpzPropertyValue -InputObject $InputObject -Name 'stderrTail' -Default $script:lastChildStderr)
    $stderrWasTruncated = [bool](Get-XpzPropertyValue -InputObject $InputObject -Name 'stderrTruncated' -Default $script:lastChildStderrTruncated)
    $warnings = @((Get-XpzPropertyValue -InputObject $InputObject -Name 'warnings' -Default @()))
    $errors = @((Get-XpzPropertyValue -InputObject $InputObject -Name 'errors' -Default @()))
    if ($ExitCode -ne 0) {
        $errors = @($errors + @((Get-XpzPropertyValue -InputObject $InputObject -Name 'blockingReasons' -Default @())))
    }
    $values = @{
        rejectedPath = $rejected
        packageWritten = (-not [string]::IsNullOrWhiteSpace([string]$output) -or -not [string]::IsNullOrWhiteSpace([string]$rejected))
        stdoutNoiseDetected = $script:stdoutNoiseDetected
        stderrTail = $stderrText
        stderrTruncated = $stderrWasTruncated
        warnings = $warnings
        errors = $errors
    }
    try {
        Complete-XpzExecutionReport -Context $script:reportContext -ExecutionState $executionState -Stage $stage -ResultExitCode $ExitCode -ProcessExitCode $ProcessExitCode -PackageState $packageState -Values $values
    } catch {
        $script:reportContext = $null
        throw "publicacao do relatorio falhou: $($_.Exception.Message)"
    }
}

function Write-XpzPackageJsonAndExit {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [int]$ProcessExitCode
    )

    $result = $InputObject
    try { Complete-XpzReportFromResult -InputObject $result -ExitCode $ExitCode -ProcessExitCode $ProcessExitCode }
    catch {
        $result = [ordered]@{
            status = 'erro'
            exitCode = 90
            stage = 'execution-report'
            blockingReasons = @($_.Exception.Message)
            reportPublicationBlocked = $true
            warnings = @()
        }
        $ExitCode = 90
    }
    ConvertTo-XpzPackageJson -InputObject $result
    exit $ExitCode
}

trap {
    $hadActiveChild = $null -ne $script:activeChildProcess
    if ($hadActiveChild) {
        Stop-XpzActiveChild -Kill
        $script:preserveRunningReport = $true
    }
    $failure = [ordered]@{
        status = 'erro'
        exitCode = 90
        stage = 'powershell-wrapper'
        blockingReasons = @($_.Exception.Message)
        warnings = @()
    }
    try { Write-XpzPackageJsonAndExit -InputObject $failure -ExitCode 90 }
    catch {
        $failure.blockingReasons += $_.Exception.Message
        ConvertTo-XpzPackageJson -InputObject $failure
        exit 90
    }
}

$repoCanonical = [IO.Path]::GetFullPath($RepoRoot)
$roundText = $null
if ($script:reportEnabled) {
    if ([string]::IsNullOrWhiteSpace($FrontName) -or $FrontName -match '[\\/:*?"<>|]' -or $FrontName -in @('.', '..')) {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'validate-input'; blockingReasons = @('FrontName invalido para modo de relatorio'); warnings = @() }) -ExitCode 20
    }
    if ($NN -notmatch '^\d+$') {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'validate-input'; blockingReasons = @('NN invalido; use apenas digitos'); warnings = @() }) -ExitCode 20
    }
    $nnNumber = [int]$NN
    $nnWidth = [Math]::Max($NN.Length, 2)
    $roundText = $nnNumber.ToString("D$nnWidth", [Globalization.CultureInfo]::InvariantCulture)
    $expectedPackagePath = Join-Path (Join-Path $repoCanonical 'PacotesGeradosParaImportacaoNaKbNoGenexus') "$FrontName`_$roundText.import_file.xml"
    $reportCheck = Test-XpzReportPathSafety -ReportPath $ReportPath -RepoRoot $repoCanonical -ExpectedPackagePath $expectedPackagePath
    if (-not $reportCheck.valid) {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'validate-report-path'; reportPath = $ReportPath; blockingReasons = @($reportCheck.reason); warnings = @() }) -ExitCode 20
    }
    $runId = [Guid]::NewGuid().ToString('D').ToLowerInvariant()
    $script:reportContext = New-XpzExecutionReportContext -ReportPath $ReportPath -RepoRoot $repoCanonical -FrontName $FrontName -NN $roundText -ExpectedPackagePath $expectedPackagePath -RunId $runId
    Update-XpzExecutionReport -Context $script:reportContext -Stage 'preflight' -Writer 'powershell' -Note 'validacao inicial concluida'
}

$enginePath = Join-Path $PSScriptRoot 'New-XpzImportPackage.py'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'preflight'; blockingReasons = @("motor Python nao encontrado: $enginePath"); warnings = @() }) -ExitCode 20
}
if ($null -ne $script:reportContext) { Update-XpzExecutionReport -Context $script:reportContext -Stage 'resolve-acervo' -Writer 'powershell' -Note 'resolvendo acervo oficial' }

$acervoResolvedBy = $null
$acervoEffective = $null
if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
    $acervoEffective = (Resolve-Path -LiteralPath $AcervoPath -ErrorAction Stop).Path
    $acervoResolvedBy = 'explicit'
} else {
    $conventionAcervo = Join-Path $RepoRoot 'ObjetosDaKbEmXml'
    if (Test-Path -LiteralPath $conventionAcervo -PathType Container) {
        $acervoEffective = (Resolve-Path -LiteralPath $conventionAcervo).Path
        $acervoResolvedBy = 'convention'
    } else {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'front-acervo-drift'; repoRoot = $RepoRoot; frontName = $FrontName; acervoResolvedBy = $null; blockingReasons = @("Acervo nao informado e acervo canonico ausente em '$conventionAcervo'. O gate de drift de lastUpdate nao pode ser pulado por omissao: informe -AcervoPath apontando para ObjetosDaKbEmXml. Footgun: import com lastUpdate menor ou igual ao objeto vivo na KB passa em silencio (exitCode 0, sem efeito) e desperdica um ciclo import+build."); warnings = @() }) -ExitCode 20
    }
}

$frontDir = Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $FrontName
if (-not (Test-Path -LiteralPath $frontDir -PathType Container)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'front-acervo-drift'; repoRoot = $RepoRoot; frontName = $FrontName; acervoResolvedBy = $acervoResolvedBy; blockingReasons = @("Pasta da frente nao encontrada: $frontDir"); warnings = @() }) -ExitCode 20
}
$driftGatePath = Join-Path $PSScriptRoot 'Test-GeneXusFrontAcervoDrift.ps1'
if (-not (Test-Path -LiteralPath $driftGatePath -PathType Leaf)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'front-acervo-drift'; repoRoot = $RepoRoot; frontName = $FrontName; acervoResolvedBy = $acervoResolvedBy; blockingReasons = @("gate de drift nao encontrado: $driftGatePath"); warnings = @() }) -ExitCode 20
}

if ($null -ne $script:reportContext) { Update-XpzExecutionReport -Context $script:reportContext -Stage 'front-acervo-drift' -Writer 'powershell' -Note 'executando gate de drift' }
$pwshCommand = Get-Command pwsh -ErrorAction Stop
$driftArgs = @('-NoProfile', '-File', $driftGatePath, '-FrontFolder', $frontDir, '-AcervoFolder', $acervoEffective, '-AsJson')
$driftChild = Invoke-XpzChildProcess -FileName $pwshCommand.Source -Arguments $driftArgs -OnHeartbeat {
    if ($null -ne $script:reportContext) { Set-XpzExecutionReportHeartbeat -Context $script:reportContext -Stage 'front-acervo-drift' -Writer 'powershell' -Progress 'gate de drift ainda em execucao' }
}
$driftStderr = Get-XpzCappedText -Text $driftChild.stderr
$script:lastChildStderr = $driftStderr.text
$script:lastChildStderrTruncated = $driftStderr.truncated
Write-XpzChildStderr -Text $driftChild.stderr
try { $driftResult = ConvertFrom-XpzStrictJson -Text $driftChild.stdout -Producer 'gate de drift' }
catch { Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'erro'; exitCode = 90; stage = 'front-acervo-drift'; blockingReasons = @($_.Exception.Message); stdoutNoiseDetected = $script:stdoutNoiseDetected; warnings = @() }) -ExitCode 90 -ProcessExitCode $driftChild.exitCode }
if ($driftResult.status -eq 'fail') {
    $failFindings = @((Get-XpzPropertyValue -InputObject $driftResult -Name 'findings' -Default @()) | Where-Object { $_.severity -eq 'fail' })
    $blockMsgs = @($failFindings | ForEach-Object { $_.message })
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'front-acervo-drift'; repoRoot = $RepoRoot; frontName = $FrontName; acervoResolvedBy = $acervoResolvedBy; driftStatus = $driftResult.status; driftFindings = $driftResult.findings; driftObjectsScanned = $driftResult.objectsScanned; blockingReasons = @("gate de drift frente-vs-acervo falhou ($($blockMsgs.Count) finding(s) fatal(is)): $($blockMsgs -join '; ')"); warnings = @() }) -ExitCode 20 -ProcessExitCode $driftChild.exitCode
}
if ($driftResult.status -eq 'alert') {
    $warnFindings = @((Get-XpzPropertyValue -InputObject $driftResult -Name 'findings' -Default @()) | Where-Object { $_.severity -eq 'warn' })
    $warnMsgs = @($warnFindings | ForEach-Object { $_.message })
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'front-acervo-drift'; repoRoot = $RepoRoot; frontName = $FrontName; acervoResolvedBy = $acervoResolvedBy; driftStatus = $driftResult.status; driftFindings = $driftResult.findings; driftObjectsScanned = $driftResult.objectsScanned; blockingReasons = @("gate de drift frente-vs-acervo retornou alerta ($($warnMsgs.Count) finding(s) warn): confirmacao explicita ou resolucao manual requerida antes de empacotar. $($warnMsgs -join '; ')"); warnings = @($warnMsgs) }) -ExitCode 20 -ProcessExitCode $driftChild.exitCode
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'bloqueado'; exitCode = 20; stage = 'preflight'; blockingReasons = @('python nao encontrado no PATH para executar New-XpzImportPackage.py'); warnings = @() }) -ExitCode 20
}
if ($null -ne $script:reportContext) { Update-XpzExecutionReport -Context $script:reportContext -Stage 'python-engine' -Writer 'powershell' -Note 'iniciando motor Python' }
$engineArgs = @($enginePath, '--repo-root', $RepoRoot, '--front-name', $FrontName, '--nn', $NN)
if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) { $engineArgs += @('--template-package-path', $TemplatePackagePath) }
if ($null -ne $script:reportContext) { $engineArgs += @('--execution-report-path', $script:reportContext.Path, '--run-id', $script:reportContext.RunId) }
$engineChild = Invoke-XpzChildProcess -FileName $pythonCommand.Source -Arguments $engineArgs
$engineStderr = Get-XpzCappedText -Text $engineChild.stderr
$script:lastChildStderr = $engineStderr.text
$script:lastChildStderrTruncated = $engineStderr.truncated
Write-XpzChildStderr -Text $engineChild.stderr
$engineExitCode = $engineChild.exitCode
try { $result = ConvertFrom-XpzStrictJson -Text $engineChild.stdout -Producer 'motor Python' }
catch { Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'erro'; exitCode = 90; stage = 'python-engine'; blockingReasons = @($_.Exception.Message); rawOutput = $engineChild.stdout; stdoutNoiseDetected = $script:stdoutNoiseDetected; warnings = @() }) -ExitCode 90 -ProcessExitCode $engineExitCode }
if ($null -ne $script:reportContext) {
    try { [void](Get-XpzExecutionReportSnapshot -Context $script:reportContext) }
    catch { Write-XpzPackageJsonAndExit -InputObject ([ordered]@{ status = 'erro'; exitCode = 90; stage = 'python-engine'; blockingReasons = @("handoff do relatorio falhou: $($_.Exception.Message)"); packageWritten = $false; warnings = @() }) -ExitCode 90 -ProcessExitCode $engineExitCode }
}
if ($engineExitCode -ne 0) {
    if ($null -eq (Get-XpzPropertyValue -InputObject $result -Name 'exitCode')) { $result | Add-Member -NotePropertyName exitCode -NotePropertyValue $engineExitCode -Force }
    if ($null -eq (Get-XpzPropertyValue -InputObject $result -Name 'stage')) { $result | Add-Member -NotePropertyName stage -NotePropertyValue 'python-engine' -Force }
    Write-XpzPackageJsonAndExit -InputObject $result -ExitCode $engineExitCode -ProcessExitCode $engineExitCode
}

$resultOutputPath = [string](Get-XpzPropertyValue -InputObject $result -Name 'outputPath' -Default '')
if (-not [string]::IsNullOrWhiteSpace($resultOutputPath)) {
    if ($null -ne $script:reportContext) { Update-XpzExecutionReport -Context $script:reportContext -Stage 'post-inventory' -Writer 'powershell' -Note 'executando inventario do pacote' }
    . (Join-Path $PSScriptRoot 'GeneXusPackageInventorySupport.ps1')
    $declaredDelta = Get-DeclaredDeltaItemsFromFrontObjectXmls -FrontDir $result.sourceFolder
    $sidecarInventoryPath = $resultOutputPath + '.package-inventory.json'
    $inventoryParams = @{ InputPath = $resultOutputPath; DeclaredDeltaItems = $declaredDelta; SidecarInventoryPath = $sidecarInventoryPath }
    if ($null -ne $script:reportContext) { $inventoryParams['FailOnDeltaMismatch'] = $true; $inventoryParams['FailOnUnknownTypes'] = $true }
    $inventoryBlock = New-PackageInventoryResult @inventoryParams
    $result | Add-Member -NotePropertyName packageInventory -NotePropertyValue $inventoryBlock.packageInventory -Force
    $result | Add-Member -NotePropertyName inventoryDegraded -NotePropertyValue $inventoryBlock.inventoryDegraded -Force
    $result | Add-Member -NotePropertyName inventoryError -NotePropertyValue $inventoryBlock.inventoryError -Force
    $inventoryExitCode = [int](Get-XpzPropertyValue -InputObject $inventoryBlock -Name 'inventoryExitCode' -Default 0)
    if ($null -ne $script:reportContext) {
        $packageInventory = Get-XpzPropertyValue -InputObject $inventoryBlock -Name 'packageInventory'
        $inventoryStatus = [string](Get-XpzPropertyValue -InputObject $packageInventory -Name 'inventoryStatus' -Default 'UNKNOWN')
        $deltaStatus = [string](Get-XpzPropertyValue -InputObject $packageInventory -Name 'deltaStatus' -Default '')
        $inventoryDecision = 'accepted'
        $packageState = 'accepted'
        if ($inventoryExitCode -ne 0 -or $inventoryBlock.inventoryDegraded -or $inventoryStatus -ne 'INVENTORY_OK' -or ($deltaStatus -and $deltaStatus -ne 'MATCH')) { $inventoryDecision = 'unknown'; $packageState = 'candidate' }
        $reviewReasons = [System.Collections.Generic.List[string]]::new()
        if ($inventoryDecision -eq 'unknown') { [void]$reviewReasons.Add('inventario sem conclusao semantica suficiente') }
        if ($null -ne $packageInventory -and [bool](Get-XpzPropertyValue -InputObject $packageInventory -Name 'attributesTopLevelUnreconciled' -Default $false)) { [void]$reviewReasons.Add('atributos de topo nao reconciliados') }
        if ($null -ne $packageInventory -and @((Get-XpzPropertyValue -InputObject $packageInventory -Name 'systemObjectsPresent' -Default @())).Count -gt 0) { [void]$reviewReasons.Add('objetos de sistema presentes') }
        $reportValues = @{
            packagePath = $resultOutputPath
            packageWritten = $true
            inventoryStatus = $inventoryStatus
            deltaStatus = $deltaStatus
            inventoryDecision = $inventoryDecision
            packageState = $packageState
            contentReviewRequired = ($inventoryDecision -eq 'unknown' -or $reviewReasons.Count -gt 0)
            contentReviewReasons = @($reviewReasons)
            stderrTail = (Get-XpzCappedText -Text $engineChild.stderr).text
            stderrTruncated = (Get-XpzCappedText -Text $engineChild.stderr).truncated
            warnings = @((Get-XpzPropertyValue -InputObject $result -Name 'warnings' -Default @()))
            errors = @()
        }
        if ($inventoryExitCode -ne 0) {
            $result.status = 'bloqueado'
            $result.exitCode = $inventoryExitCode
            $result | Add-Member -NotePropertyName stage -NotePropertyValue 'post-inventory' -Force
            $existingReasons = @((Get-XpzPropertyValue -InputObject $result -Name 'blockingReasons' -Default @()))
            $result.blockingReasons = @($existingReasons + "inventario retornou exitCode $inventoryExitCode ($inventoryStatus)")
            $reportValues.errors = @($result.blockingReasons)
        }
        $reportExecutionState = 'completed'
        $reportStage = 'completed'
        if ($inventoryExitCode -ne 0) {
            $reportExecutionState = 'blocked'
            $reportStage = 'post-inventory'
        }
        Complete-XpzExecutionReport -Context $script:reportContext -ExecutionState $reportExecutionState -Stage $reportStage -ResultExitCode ([int](Get-XpzPropertyValue -InputObject $result -Name 'exitCode' -Default 0)) -ProcessExitCode $engineExitCode -PackageState $packageState -InventoryDecision $inventoryDecision -Values $reportValues
    }
}

if ($null -ne $script:reportContext -and [string]::IsNullOrWhiteSpace($resultOutputPath)) {
    Complete-XpzReportFromResult -InputObject $result -ExitCode ([int](Get-XpzPropertyValue -InputObject $result -Name 'exitCode' -Default 0)) -ProcessExitCode $engineExitCode
}

$result | Add-Member -NotePropertyName acervoResolvedBy -NotePropertyValue $acervoResolvedBy -Force
if ($null -ne $driftResult) {
    $result | Add-Member -NotePropertyName driftStatus -NotePropertyValue $driftResult.status -Force
    $result | Add-Member -NotePropertyName driftFindings -NotePropertyValue $driftResult.findings -Force
    $result | Add-Member -NotePropertyName driftObjectsScanned -NotePropertyValue $driftResult.objectsScanned -Force
}
$finalExitCode = [int](Get-XpzPropertyValue -InputObject $result -Name 'exitCode' -Default 0)
if ($finalExitCode -ne 0) { Write-XpzPackageJsonAndExit -InputObject $result -ExitCode $finalExitCode -ProcessExitCode $engineExitCode }
ConvertTo-XpzPackageJson -InputObject $result
exit 0
