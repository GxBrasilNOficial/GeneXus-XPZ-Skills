#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

function Get-ArrayCount {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return 0
    }

    return @($Value).Count
}

function Remove-WrapperArtifactDirectory {
    param(
        [AllowNull()][string]$MsBuildFilePath,
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($MsBuildFilePath)) {
        return
    }

    $artifactDirectory = Split-Path -Parent $MsBuildFilePath
    $allowedRoot = Join-Path $RepositoryRoot 'Temp\xpz-msbuild-build'
    $resolvedArtifactDirectory = [System.IO.Path]::GetFullPath($artifactDirectory)
    $resolvedAllowedRoot = [System.IO.Path]::GetFullPath($allowedRoot).TrimEnd('\\')
    $relative = [System.IO.Path]::GetRelativePath($resolvedAllowedRoot, $resolvedArtifactDirectory)

    if ($relative -match '^(\.\.|$)' -or (Split-Path -Leaf $resolvedArtifactDirectory) -notmatch '^gx-specifygenerate-[0-9a-f]{32}$') {
        throw "Recusa de limpeza fora do artefato SpecifyGenerate do self-test: $resolvedArtifactDirectory"
    }

    if (Test-Path -LiteralPath $resolvedArtifactDirectory -PathType Container) {
        Remove-Item -LiteralPath $resolvedArtifactDirectory -Recurse -Force
    }
}

function Invoke-SpecifyGenerateScenario {
    param(
        [string]$ScenarioRoot,
        [string[]]$StdErrLines,
        # Leituras de GetActiveEnvironment na ordem do .msbuild: abertura (antes dos Set) e efetiva (depois).
        [string[]]$ContextLines = @(
            "echo The active environment is 'TestEnvironment'",
            "echo The active environment is 'TestEnvironment'"
        ),
        [int]$FakeExitCode = 0,
        # Parametros extras do wrapper (ex.: ParallelKbRoot), em hashtable para splat nomeado. Vazio preserva a chamada original.
        [hashtable]$ExtraWrapperParams = @{}
    )

    $fakeGeneXusDirectory = Join-Path $ScenarioRoot 'GeneXus'
    $fakeKbDirectory = Join-Path $ScenarioRoot 'Kb'
    $workingDirectory = Join-Path $ScenarioRoot 'work'
    $logPath = Join-Path $ScenarioRoot 'result.json'
    $fakeMsBuildPath = Join-Path $ScenarioRoot 'fake-msbuild.cmd'

    foreach ($directory in @($fakeGeneXusDirectory, $fakeKbDirectory, $workingDirectory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    [System.IO.File]::WriteAllText(
        (Join-Path $fakeGeneXusDirectory 'Genexus.Tasks.targets'),
        '<Project />',
        [System.Text.UTF8Encoding]::new($false))

    $cmdLines = @(
        '@echo off',
        'echo __KB_OPEN__=true'
    )
    $cmdLines += $ContextLines
    if ($FakeExitCode -eq 0) {
        $cmdLines += @(
            'echo __SPECIFY_DONE__=true',
            'echo __GENERATE_DONE__=true'
        )
    }
    foreach ($line in $StdErrLines) {
        $cmdLines += ('1>&2 echo ' + $line)
    }
    $cmdLines += ('exit /b {0}' -f $FakeExitCode)
    [System.IO.File]::WriteAllText(
        $fakeMsBuildPath,
        ($cmdLines -join "`r`n") + "`r`n",
        [System.Text.Encoding]::ASCII)

    $wrapperPath = Join-Path $PSScriptRoot 'Invoke-GeneXusKbSpecifyGenerate.ps1'
    $wrapperOutput = & $wrapperPath `
        -KbPath $fakeKbDirectory `
        -WorkingDirectory $workingDirectory `
        -LogPath $logPath `
        -GeneXusDir $fakeGeneXusDirectory `
        -MsBuildPath $fakeMsBuildPath `
        -EnvironmentName 'TestEnvironment' `
        @ExtraWrapperParams
    $wrapperExitCode = $LASTEXITCODE
    $jsonText = @($wrapperOutput) -join [Environment]::NewLine

    return [ordered]@{
        ExitCode = $wrapperExitCode
        Diagnostic = ($jsonText | ConvertFrom-Json -Depth 16)
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-specifygenerate-e2e-selftest-' + [System.Guid]::NewGuid().ToString('N'))
$noise = "context [anonymous] 1:12 attribute component isn't defined"
$artifactDirectories = New-Object System.Collections.Generic.List[string]

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

    $noiseOnly = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'noise-only') -StdErrLines @($noise, $noise, $noise)
    $noiseOnlyArtifact = [string]$noiseOnly.Diagnostic.artifacts.MsBuildFilePath
    $artifactDirectories.Add($noiseOnlyArtifact)

    Assert-True -Condition ($noiseOnly.ExitCode -eq 0) -Message ("SpecifyGenerate com ruido conhecido deveria encerrar com exit 0; recebeu exit {0}, status '{1}', resumo '{2}'." -f $noiseOnly.ExitCode, $noiseOnly.Diagnostic.status, $noiseOnly.Diagnostic.summary)
    Assert-True -Condition ($noiseOnly.Diagnostic.executionEvidence.msBuildExitCode -eq 0) -Message 'executionEvidence.msBuildExitCode deveria ser 0.'
    Assert-True -Condition ($noiseOnly.Diagnostic.observedContext.SpecifyDone -eq $true) -Message 'SpecifyDone deveria ser true.'
    Assert-True -Condition ($noiseOnly.Diagnostic.observedContext.GenerateDone -eq $true) -Message 'GenerateDone deveria ser true.'
    Assert-True -Condition ($noiseOnly.Diagnostic.postProcessingFailed -eq $false) -Message ("postProcessingFailed deveria ser false; erro: {0}" -f $noiseOnly.Diagnostic.postProcessingError)
    Assert-True -Condition ((Get-ArrayCount -Value $noiseOnly.Diagnostic.stderrFilteredNoise) -eq 3) -Message 'As tres linhas de ruido conhecido deveriam permanecer em stderrFilteredNoise.'
    Assert-True -Condition ((Get-ArrayCount -Value $noiseOnly.Diagnostic.stderrContent) -eq 0) -Message 'stderrContent deveria ficar vazio quando stderr contem somente ruido conhecido.'
    Assert-True -Condition ($noiseOnly.Diagnostic.status -eq 'specify e generate concluídos') -Message 'Ruido conhecido isolado nao pode degradar a classificacao operacional.'
    Assert-True -Condition ($noiseOnly.Diagnostic.exitCode -eq 0 -and -not $noiseOnly.Diagnostic.msBuildCategoryBBlocked) -Message 'Cenario de ruido conhecido deveria permanecer como sucesso operacional.'

    $mixed = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'mixed') -StdErrLines @($noise, $noise, $noise, 'ERRO REAL: detalhe preservado')
    $mixedArtifact = [string]$mixed.Diagnostic.artifacts.MsBuildFilePath
    $artifactDirectories.Add($mixedArtifact)

    Assert-True -Condition ($mixed.ExitCode -eq 0) -Message 'Stderr misto nao deve alterar o exitCode classificado do wrapper neste cenario.'
    Assert-True -Condition ($mixed.Diagnostic.executionEvidence.msBuildExitCode -eq 0) -Message 'Stderr misto deveria preservar msBuildExitCode 0.'
    Assert-True -Condition ($mixed.Diagnostic.observedContext.SpecifyDone -eq $true -and $mixed.Diagnostic.observedContext.GenerateDone -eq $true) -Message 'Stderr misto deveria preservar os sinais de conclusao operacional.'
    Assert-True -Condition ((Get-ArrayCount -Value $mixed.Diagnostic.stderrFilteredNoise) -eq 3) -Message 'Stderr misto deveria manter as tres linhas conhecidas em stderrFilteredNoise.'
    Assert-True -Condition ((Get-ArrayCount -Value $mixed.Diagnostic.stderrContent) -eq 1) -Message 'Stderr misto deveria preservar uma linha real em stderrContent.'
    Assert-True -Condition ([string]$mixed.Diagnostic.stderrContent[0] -eq 'ERRO REAL: detalhe preservado') -Message 'A linha real do stderr misto foi perdida ou alterada.'
    Assert-True -Condition ($mixed.Diagnostic.status -eq 'operação concluída, pendente de confirmação funcional') -Message 'Stderr misto deveria rebaixar a classificacao conforme o contrato do wrapper.'
    Assert-True -Condition ($mixed.Diagnostic.exitCode -eq 0 -and -not $mixed.Diagnostic.msBuildCategoryBBlocked) -Message 'Stderr misto deveria manter exit 0 sem declarar sucesso limpo.'

    # Troca de environment bem-sucedida: efetivo = leitura posterior ao Set; abertura preservada a parte.
    $switched = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'environment-switch') -StdErrLines @() -ContextLines @(
        "echo The active environment is '.Net Environment'",
        'echo ^> Set Active Environment Sucesso',
        "echo The active environment is 'TestEnvironment'"
    )
    $artifactDirectories.Add([string]$switched.Diagnostic.artifacts.MsBuildFilePath)

    Assert-True -Condition ($switched.ExitCode -eq 0) -Message ("Troca de environment deveria encerrar com exit 0; recebeu exit {0}, status '{1}'." -f $switched.ExitCode, $switched.Diagnostic.status)
    Assert-True -Condition ([string]$switched.Diagnostic.observedContext.ActiveEnvironment -eq 'TestEnvironment') -Message ("ActiveEnvironment deveria ser o environment efetivo apos SetActiveEnvironment; recebeu '{0}'." -f $switched.Diagnostic.observedContext.ActiveEnvironment)
    Assert-True -Condition ([string]$switched.Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq '.Net Environment') -Message ("ActiveEnvironmentAtOpen deveria preservar o environment de abertura; recebeu '{0}'." -f $switched.Diagnostic.observedContext.ActiveEnvironmentAtOpen)
    Assert-True -Condition (@($switched.Diagnostic.warnings | Where-Object { [string]$_ -match 'GetActiveEnvironment' }).Count -eq 0) -Message 'Troca bem-sucedida com leitura posterior nao deveria gerar aviso de leitura ausente.'

    # O .msbuild gerado precisa ler o environment antes e depois do SetActiveEnvironment, e so entao especificar.
    $msBuildText = [System.IO.File]::ReadAllText([string]$switched.Diagnostic.artifacts.MsBuildFilePath)
    $firstGetEnvironment = $msBuildText.IndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $setEnvironment = $msBuildText.IndexOf('<SetActiveEnvironment', [System.StringComparison]::Ordinal)
    $lastGetEnvironment = $msBuildText.LastIndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $specifyAll = $msBuildText.IndexOf('<SpecifyAll', [System.StringComparison]::Ordinal)
    Assert-True -Condition ($firstGetEnvironment -ge 0 -and $firstGetEnvironment -lt $setEnvironment -and $setEnvironment -lt $lastGetEnvironment -and $lastGetEnvironment -lt $specifyAll) -Message 'O .msbuild deveria ter GetActiveEnvironment antes e depois de SetActiveEnvironment, ambos antes de SpecifyAll.'

    # SetActiveEnvironment falhou: antes o bloqueio citava '(desconhecido)' porque so havia leitura apos o Set.
    $setFailed = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'environment-set-failed') -StdErrLines @() -FakeExitCode 1 -ContextLines @(
        "echo The active environment is '.Net Environment'",
        "echo Ambiente 'TestEnvironment' nao existe",
        'echo Set Active Environment falhou'
    )
    $artifactDirectories.Add([string]$setFailed.Diagnostic.artifacts.MsBuildFilePath)

    $setFailedReason = @($setFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveEnvironment falhou' })
    Assert-True -Condition ($setFailedReason.Count -eq 1) -Message 'Falha de SetActiveEnvironment deveria gerar um blockingReason especifico.'
    Assert-True -Condition ([string]$setFailedReason[0] -match "momento da abertura era '\.Net Environment'") -Message ("O blockingReason deveria citar o environment de abertura; recebeu '{0}'." -f $setFailedReason[0])
    Assert-True -Condition ([string]$setFailed.Diagnostic.observedContext.ActiveEnvironment -eq '.Net Environment') -Message 'Com SetActiveEnvironment falho, o environment efetivo continua sendo o de abertura.'

    # --- Eventos pos-build: paridade com o BuildAll (cenario dedicado, com -ParallelKbRoot) ---
    . (Join-Path $PSScriptRoot 'GeneXusMsBuildPostBuildEventsSupport.ps1')

    function ConvertTo-CmdEchoLine {
        param([Parameter(Mandatory = $true)][string]$Line)

        $escaped = $Line.
            Replace('^', '^^').
            Replace('&', '^&').
            Replace('|', '^|').
            Replace('<', '^<').
            Replace('>', '^>').
            Replace('(', '^(').
            Replace(')', '^)')
        return ('echo {0}' -f $escaped)
    }

    function New-SpecifyPostBuildContextLines {
        param([string[]]$Events)

        $lines = New-Object System.Collections.Generic.List[string]
        [void]$lines.Add("echo The active environment is 'TestEnvironment'")
        [void]$lines.Add("echo The active environment is 'TestEnvironment'")
        [void]$lines.Add((ConvertTo-CmdEchoLine -Line 'Executando eventos pos-construcao ...'))
        foreach ($event in $Events) {
            [void]$lines.Add((ConvertTo-CmdEchoLine -Line $event))
        }
        [void]$lines.Add((ConvertTo-CmdEchoLine -Line '========== fim dos eventos pos-construcao =========='))
        return @($lines)
    }

    $sgA1 = '[APLICADO] .js varridos=2966 | arquivos com chave negativa em gx.domain=1 | chaves corrigidas=1'
    $sgB1 = 'Verify-GxJs: verificados 2176 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2237 ms'
    $sgC1 = 'CommonRspHealth: OK - genexus.programs.common.rsp ok (439 itens, 221 dominios); 218 gxdomain*.cs no disco'
    $sgA2 = '[APLICADO] .js varridos=2977 | arquivos com chave negativa em gx.domain=4 | chaves corrigidas=5'
    $sgB2 = 'Verify-GxJs: verificados 2190 .js (modulos pulados: 391 | placeholders pulados: 0) | invalidos: 0 | tempo: 9 ms'
    $sgC2 = 'CommonRspHealth: OK - genexus.programs.common.rsp ok (450 itens, 230 dominios); 220 gxdomain*.cs no disco'

    $sgParallelRoot = Join-Path $testRoot 'sg-parallel'
    [System.IO.Directory]::CreateDirectory($sgParallelRoot) | Out-Null
    $sgHashes = (@($sgA1, $sgB1, $sgC1) | ForEach-Object { Get-GeneXusPostBuildEventFamilyHash -Line $_ }) -join ','
    $sgMetadataText = @(
        '---'
        'deployment_environment_name: TestEnvironment'
        'deployment_hosting_kind: dotnet-core-self-host'
        'kb_environment_count: 1'
        'kb_environment_names: TestEnvironment'
        "kb_environment_post_build_event_hashes: TestEnvironment=$sgHashes"
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $sgParallelRoot 'kb-source-metadata.md'), $sgMetadataText, [System.Text.UTF8Encoding]::new($false))

    # SG1: com registro das contagens do dia anterior, contagens novas -> esperado, sem rebaixar.
    $sgRegistered = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'sg-registered') -StdErrLines @() -ContextLines (New-SpecifyPostBuildContextLines -Events @($sgA2, $sgB2, $sgC2)) -ExtraWrapperParams @{ ParallelKbRoot = $sgParallelRoot }
    $artifactDirectories.Add([string]$sgRegistered.Diagnostic.artifacts.MsBuildFilePath)
    $sgClassification = $sgRegistered.Diagnostic.stdoutSignals.postBuildEventClassification
    Assert-True -Condition ([string]$sgClassification.registryStatus.state -eq 'available') -Message ("SG1 registryStatus.state deveria ser available; recebeu '{0}'." -f $sgClassification.registryStatus.state)
    Assert-True -Condition (@($sgClassification.expected).Count -eq 3 -and -not $sgClassification.shouldDowngrade) -Message 'SG1 deveria ter 3 eventos esperados e nao rebaixar.'
    Assert-True -Condition ($sgRegistered.ExitCode -eq 0 -and [string]$sgRegistered.Diagnostic.status -notmatch 'pendente de confirma') -Message ("SG1 deveria sair sem pendencia de pos-build com registro; exit {0}, status '{1}'." -f $sgRegistered.ExitCode, $sgRegistered.Diagnostic.status)

    # SG2: sem -ParallelKbRoot -> o registro nao e consultado; pendente e aviso explicito.
    $sgNoMetadata = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'sg-no-metadata') -StdErrLines @() -ContextLines (New-SpecifyPostBuildContextLines -Events @($sgA1, $sgB1, $sgC1))
    $artifactDirectories.Add([string]$sgNoMetadata.Diagnostic.artifacts.MsBuildFilePath)
    Assert-True -Condition ([string]$sgNoMetadata.Diagnostic.stdoutSignals.postBuildEventClassification.registryStatus.state -eq 'metadataNotProvided') -Message 'SG2 registryStatus.state deveria ser metadataNotProvided.'
    Assert-True -Condition ([string]$sgNoMetadata.Diagnostic.status -match 'pendente de confirma') -Message ("SG2 deveria ficar pendente sem consulta ao registro; status '{0}'." -f $sgNoMetadata.Diagnostic.status)
    Assert-True -Condition (@($sgNoMetadata.Diagnostic.warnings | Where-Object { [string]$_ -match 'Registro de eventos pos-build nao consultado' }).Count -eq 1) -Message 'SG2 deveria avisar que o registro nao foi consultado.'
    Assert-True -Condition ($null -eq $sgClassification.nextStep) -Message 'SG1 nao deveria ter nextStep com o registro completo.'
    Assert-True -Condition ($null -eq $sgNoMetadata.Diagnostic.stdoutSignals.postBuildEventClassification.nextStep) -Message 'SG2 nao deveria ter nextStep quando o registro nao foi consultado.'

    # SG3: metadata sem entrada para o environment -> nextStep aponta para a auditoria de setup, sem script de registro.
    $sgEmptyRoot = Join-Path $testRoot 'sg-parallel-empty'
    [System.IO.Directory]::CreateDirectory($sgEmptyRoot) | Out-Null
    $sgEmptyMetadata = @(
        '---'
        'deployment_environment_name: TestEnvironment'
        'deployment_hosting_kind: dotnet-core-self-host'
        'kb_environment_count: 1'
        'kb_environment_names: TestEnvironment'
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $sgEmptyRoot 'kb-source-metadata.md'), $sgEmptyMetadata, [System.Text.UTF8Encoding]::new($false))
    $sgNoEntry = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'sg-no-entry') -StdErrLines @() -ContextLines (New-SpecifyPostBuildContextLines -Events @($sgA1, $sgB1, $sgC1)) -ExtraWrapperParams @{ ParallelKbRoot = $sgEmptyRoot }
    $artifactDirectories.Add([string]$sgNoEntry.Diagnostic.artifacts.MsBuildFilePath)
    $sgNoEntryNextStep = [string]$sgNoEntry.Diagnostic.stdoutSignals.postBuildEventClassification.nextStep
    Assert-True -Condition ([string]$sgNoEntry.Diagnostic.stdoutSignals.postBuildEventClassification.registryStatus.state -eq 'noEntryForEnvironment') -Message 'SG3 registryStatus.state deveria ser noEntryForEnvironment.'
    Assert-True -Condition ($sgNoEntryNextStep -match 'xpz-kb-parallel-setup' -and $sgNoEntryNextStep -match 'auditoria de setup' -and $sgNoEntryNextStep -notmatch 'Register-') -Message ("SG3 nextStep deveria apontar para a auditoria de setup sem citar script de registro; recebeu '{0}'." -f $sgNoEntryNextStep)
    Assert-True -Condition (@($sgNoEntry.Diagnostic.warnings | Where-Object { [string]$_ -match 'Register-GeneXusKbPostBuildEvents' }).Count -eq 0) -Message 'SG3 nao deveria citar o script de registro nos avisos do build.'

    # SG4: environment ja registrado, evento novo (invalidos 1 fora da familia) -> pendente so por evento. O summary do
    # SpecifyGenerate e generico; o veredito de base decide por pendingCauses e precisa aceitar este build.
    $sgBNew = 'Verify-GxJs: verificados 2190 .js (modulos pulados: 391 | placeholders pulados: 0) | invalidos: 1 | tempo: 9 ms'
    $sgNewEvent = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'sg-new-event') -StdErrLines @() -ContextLines (New-SpecifyPostBuildContextLines -Events @($sgA2, $sgBNew, $sgC2)) -ExtraWrapperParams @{ ParallelKbRoot = $sgParallelRoot }
    $artifactDirectories.Add([string]$sgNewEvent.Diagnostic.artifacts.MsBuildFilePath)
    Assert-True -Condition ([string]$sgNewEvent.Diagnostic.status -match 'pendente de confirma') -Message ("SG4 deveria ficar pendente com evento novo; status '{0}'." -f $sgNewEvent.Diagnostic.status)
    Assert-True -Condition ((@($sgNewEvent.Diagnostic.pendingCauses) -join ',') -eq 'postBuildEvent') -Message ("SG4 pendingCauses deveria ser so postBuildEvent; recebeu '{0}'." -f (@($sgNewEvent.Diagnostic.pendingCauses) -join ', '))
    $sgNewEventVerdict = Get-GeneXusPostBuildBaseVerdict -Facts (Get-GeneXusPostBuildBaseFacts -BuildJson $sgNewEvent.Diagnostic)
    Assert-True -Condition ([bool]$sgNewEventVerdict.ok) -Message ("SG4: o veredito de base deveria aceitar a saida real do SpecifyGenerate pendente so por evento; obtido ok={0} ({1})." -f $sgNewEventVerdict.ok, $sgNewEventVerdict.reason)

    # SG5: o mesmo evento novo com stderr nao vazio -> a pendencia tem outra causa e o build nao serve de base.
    $sgNewEventStderr = Invoke-SpecifyGenerateScenario -ScenarioRoot (Join-Path $testRoot 'sg-new-event-stderr') -StdErrLines @('falha qualquer no stderr') -ContextLines (New-SpecifyPostBuildContextLines -Events @($sgA2, $sgBNew, $sgC2)) -ExtraWrapperParams @{ ParallelKbRoot = $sgParallelRoot }
    $artifactDirectories.Add([string]$sgNewEventStderr.Diagnostic.artifacts.MsBuildFilePath)
    Assert-True -Condition (@($sgNewEventStderr.Diagnostic.pendingCauses) -contains 'stderr' -and @($sgNewEventStderr.Diagnostic.pendingCauses) -contains 'postBuildEvent') -Message ("SG5 pendingCauses deveria conter stderr e postBuildEvent; recebeu '{0}'." -f (@($sgNewEventStderr.Diagnostic.pendingCauses) -join ', '))
    $sgNewEventStderrVerdict = Get-GeneXusPostBuildBaseVerdict -Facts (Get-GeneXusPostBuildBaseFacts -BuildJson $sgNewEventStderr.Diagnostic)
    Assert-True -Condition (-not [bool]$sgNewEventStderrVerdict.ok) -Message ("SG5: o veredito de base nao deveria aceitar pendencia com stderr; obtido ok={0} ({1})." -f $sgNewEventStderrVerdict.ok, $sgNewEventStderrVerdict.reason)

    # SG1 (registro completo) segue sem causa de pendencia.
    Assert-True -Condition (@($sgRegistered.Diagnostic.pendingCauses).Count -eq 0) -Message ("SG1 nao deveria ter pendingCauses; recebeu '{0}'." -f (@($sgRegistered.Diagnostic.pendingCauses) -join ', '))

    # Copia do diagnostico no Temp\ da pasta paralela (onde a auditoria de setup procura o build mais recente):
    # com -ParallelKbRoot o wrapper grava a copia e cita o caminho; sem ele (SG2), nao grava nem cita.
    foreach ($sgCopyCase in @(@{ Name = 'SG3'; Diagnostic = $sgNoEntry.Diagnostic; Root = $sgEmptyRoot }, @{ Name = 'SG4'; Diagnostic = $sgNewEvent.Diagnostic; Root = $sgParallelRoot })) {
        $sgCopyPath = [string]$sgCopyCase.Diagnostic.artifacts.ParallelKbDiagnosticCopyPath
        $sgCopyRoot = Join-Path (Join-Path $sgCopyCase.Root 'Temp') 'xpz-msbuild-build'
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($sgCopyPath)) -Message ("{0} deveria citar artifacts.ParallelKbDiagnosticCopyPath com -ParallelKbRoot." -f $sgCopyCase.Name)
        Assert-True -Condition ((Split-Path -Parent $sgCopyPath) -eq $sgCopyRoot -and (Split-Path -Leaf $sgCopyPath) -match '^specifygenerate-\d{8}-\d{6}-[0-9a-f]{8}\.json$') -Message ("{0}: copia fora de <ParallelKbRoot>\Temp\xpz-msbuild-build\specifygenerate-*.json: '{1}'." -f $sgCopyCase.Name, $sgCopyPath)
        Assert-True -Condition (Test-Path -LiteralPath $sgCopyPath -PathType Leaf) -Message ("{0}: copia do diagnostico nao gravada em '{1}'." -f $sgCopyCase.Name, $sgCopyPath)
        $sgCopyDoc = Get-Content -LiteralPath $sgCopyPath -Raw | ConvertFrom-Json
        Assert-True -Condition ($sgCopyDoc.status -eq $sgCopyCase.Diagnostic.status -and [string]$sgCopyDoc.observedContext.ActiveEnvironment -eq 'TestEnvironment' -and [string]$sgCopyDoc.artifacts.ParallelKbDiagnosticCopyPath -eq $sgCopyPath) -Message ("{0}: a copia deveria ser o mesmo diagnostico emitido (status, ActiveEnvironment e o proprio caminho)." -f $sgCopyCase.Name)
    }
    Assert-True -Condition ($null -eq $sgNoMetadata.Diagnostic.artifacts.PSObject.Properties['ParallelKbDiagnosticCopyPath']) -Message 'SG2 (sem -ParallelKbRoot) nao deveria citar nem gravar copia do diagnostico.'
}
finally {
    foreach ($msBuildFilePath in $artifactDirectories) {
        try {
            Remove-WrapperArtifactDirectory -MsBuildFilePath $msBuildFilePath -RepositoryRoot $repositoryRoot
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }

    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Output 'GENEXUS_MSBUILD_SPECIFYGENERATE_E2E_SELFTEST_OK'
