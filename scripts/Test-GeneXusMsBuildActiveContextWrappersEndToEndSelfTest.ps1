#requires -Version 7.4

<#
.SYNOPSIS
    E2E in-repo dos wrappers Export/Import/Preview com MSBuild falso, GeneXusDir falso e
    assembly sintetica minima (fixtures/msbuild-e2e/SyntheticGeneXusMsBuildTasks.cs).

.DESCRIPTION
    Passa pelo probe real e pela reflexao de Genexus.MsBuild.Tasks.dll (dai a assembly sintetica).
    Cobre: teste decisivo dos sinais (observedContext = compactSignals = arquivo de sinais; uma
    leitura + troca pedida + sem falha de Set => efetivo nulo), troca bem-sucedida, Set falho com
    bloqueio citando a abertura, exits preservados (41/31) e assercao estrutural no .msbuild.
    Cobre tambem o default ExportKbInfo=true do Export: origem (default/caller), valor efetivo,
    rebaixamento com aviso quando a task nao expoe ExportKBInfo (variantes da assembly em
    processo filho) e exit 34 apenas para true explicito sem nenhuma das propriedades.
#>

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

$fixtureSourcePath = Join-Path $PSScriptRoot 'fixtures\msbuild-e2e\SyntheticGeneXusMsBuildTasks.cs'
if (-not (Test-Path -LiteralPath $fixtureSourcePath -PathType Leaf)) {
    throw "Fixture C# nao encontrada: $fixtureSourcePath"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-wrappers-e2e-selftest-' + [System.Guid]::NewGuid().ToString('N'))
$syntheticDllPath = Join-Path $testRoot 'Genexus.MsBuild.Tasks.dll'

function Invoke-WrapperScenario {
    param(
        [ValidateSet('Export', 'Import', 'Preview')][string]$Wrapper,
        [string]$ScenarioRoot,
        [string[]]$StdOutCmdLines = @(),
        [string[]]$StdErrCmdLines = @(),
        [int]$FakeExitCode = 0,
        [string]$EnvironmentName,
        [hashtable]$Selection,
        [string]$FullExportCatalogOverridePath,
        # Variante da assembly sintetica (ex.: sem ExportKBInfo). Exige -InChildProcess:
        # o wrapper le a assembly por LoadFrom e, no mesmo processo, a identidade ja
        # carregada pelos cenarios anteriores prevaleceria.
        [string]$TasksDllPath,
        [switch]$InChildProcess,
        [hashtable]$ExtraArgs
    )

    $fakeGeneXusDirectory = Join-Path $ScenarioRoot 'GeneXus'
    $fakeKbDirectory = Join-Path $ScenarioRoot 'Kb'
    $workingDirectory = Join-Path $ScenarioRoot 'work'
    $logPath = Join-Path $ScenarioRoot 'result.json'
    $fakeMsBuildPath = Join-Path $ScenarioRoot 'fake-msbuild.cmd'

    foreach ($directory in @($fakeGeneXusDirectory, $fakeKbDirectory, $workingDirectory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    [System.IO.File]::WriteAllText((Join-Path $fakeGeneXusDirectory 'Genexus.Tasks.targets'), '<Project />', [System.Text.UTF8Encoding]::new($false))
    $sourceDllPath = $syntheticDllPath
    if (-not [string]::IsNullOrWhiteSpace($TasksDllPath)) {
        if (-not $InChildProcess) { throw 'TasksDllPath exige -InChildProcess.' }
        $sourceDllPath = $TasksDllPath
    }
    Copy-Item -LiteralPath $sourceDllPath -Destination (Join-Path $fakeGeneXusDirectory 'Genexus.MsBuild.Tasks.dll') -Force

    $cmdLines = @('@echo off') + $StdOutCmdLines + $StdErrCmdLines + @('exit /b {0}' -f $FakeExitCode)
    [System.IO.File]::WriteAllText($fakeMsBuildPath, ($cmdLines -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)

    # Pacote de entrada (Import/Preview) e/ou saida previa (Export) existente.
    $xpzPath = Join-Path $workingDirectory 'pkg.xpz'
    [System.IO.File]::WriteAllText($xpzPath, 'dummy', [System.Text.UTF8Encoding]::new($false))

    $wrapperArgs = @{
        KbPath           = $fakeKbDirectory
        WorkingDirectory = $workingDirectory
        LogPath          = $logPath
        GeneXusDir       = $fakeGeneXusDirectory
        MsBuildPath      = $fakeMsBuildPath
    }
    switch ($Wrapper) {
        'Export' {
            $wrapperPath = Join-Path $PSScriptRoot 'Invoke-GeneXusXpzExport.ps1'
            $wrapperArgs.XpzPath = $xpzPath
            $wrapperArgs.ExportAll = 'true'
        }
        'Import' {
            $wrapperPath = Join-Path $PSScriptRoot 'Invoke-GeneXusXpzImport.ps1'
            $wrapperArgs.InputPath = $xpzPath
        }
        'Preview' {
            $wrapperPath = Join-Path $PSScriptRoot 'Test-GeneXusXpzImportPreview.ps1'
            $wrapperArgs.InputPath = $xpzPath
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) { $wrapperArgs.EnvironmentName = $EnvironmentName }
    if (-not [string]::IsNullOrWhiteSpace($FullExportCatalogOverridePath)) { $wrapperArgs.CatalogOverridePath = $FullExportCatalogOverridePath }

    if ($null -ne $Selection) {
        if ($Wrapper -eq 'Export') {
            $wrapperArgs.ExportAll = 'false'
            $wrapperArgs.ObjectList = 'Procedure:Demo'
        } else {
            $wrapperArgs.IncludeItems = 'Procedure:Demo'
        }
        foreach ($key in $Selection.Keys) {
            $wrapperArgs[$key] = $Selection[$key]
        }
    }

    if ($null -ne $ExtraArgs) {
        foreach ($key in $ExtraArgs.Keys) {
            $wrapperArgs[$key] = $ExtraArgs[$key]
        }
    }

    if ($InChildProcess) {
        $childArgs = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $wrapperArgs.Keys) {
            $childArgs.Add("-$key")
            $childArgs.Add([string]$wrapperArgs[$key])
        }
        $wrapperOutput = & $script:PwshPath -NoProfile -File $wrapperPath @childArgs
        $wrapperExitCode = $LASTEXITCODE
    } else {
        $wrapperOutput = & $wrapperPath @wrapperArgs
        $wrapperExitCode = $LASTEXITCODE
    }
    $jsonText = @($wrapperOutput) -join [Environment]::NewLine

    return [ordered]@{
        ExitCode   = $wrapperExitCode
        Diagnostic = ($jsonText | ConvertFrom-Json -Depth 20)
    }
}

function Get-SignalsFilePath {
    param($Diagnostic, [string]$Wrapper)
    if ($Wrapper -eq 'Export') { return [string]$Diagnostic.artifacts.ExportSignalsPath }
    return [string]$Diagnostic.artifacts.SignalsPath
}

function Get-CompactSignals {
    # Export expoe compactSignals no topo; Import/Preview o aninham em stdoutSignals.compactSignals.
    param($Diagnostic, [string]$Wrapper)
    if ($Diagnostic.PSObject.Properties['compactSignals'] -and $null -ne $Diagnostic.compactSignals) { return $Diagnostic.compactSignals }
    if ($Diagnostic.PSObject.Properties['stdoutSignals'] -and $Diagnostic.stdoutSignals.PSObject.Properties['compactSignals'] -and $null -ne $Diagnostic.stdoutSignals.compactSignals) { return $Diagnostic.stdoutSignals.compactSignals }
    throw "[$Wrapper] compactSignals nao encontrado no diagnostico."
}

function Assert-DecisiveSignals {
    param($Diagnostic, [string]$Wrapper, [string]$ExpectedAtOpen)

    Assert-True -Condition ($null -eq $Diagnostic.observedContext.ActiveEnvironment) -Message ("[$Wrapper] observedContext.ActiveEnvironment deveria ser nulo (troca sem leitura posterior); recebeu '{0}'." -f $Diagnostic.observedContext.ActiveEnvironment)
    Assert-True -Condition ([string]$Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq $ExpectedAtOpen) -Message ("[$Wrapper] observedContext.ActiveEnvironmentAtOpen deveria ser '{0}'." -f $ExpectedAtOpen)

    $compactSignals = Get-CompactSignals -Diagnostic $Diagnostic -Wrapper $Wrapper
    Assert-True -Condition ($null -eq $compactSignals.activeEnvironment) -Message ("[$Wrapper] compactSignals.activeEnvironment deveria ser nulo." -f $compactSignals.activeEnvironment)
    Assert-True -Condition ([string]$compactSignals.activeEnvironmentAtOpen -eq $ExpectedAtOpen) -Message ("[$Wrapper] compactSignals.activeEnvironmentAtOpen deveria ser '{0}'." -f $ExpectedAtOpen)

    $signalsFilePath = Get-SignalsFilePath -Diagnostic $Diagnostic -Wrapper $Wrapper
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($signalsFilePath) -and (Test-Path -LiteralPath $signalsFilePath -PathType Leaf)) -Message ("[$Wrapper] arquivo de sinais ausente: {0}" -f $signalsFilePath)
    $fileSignals = [System.IO.File]::ReadAllText($signalsFilePath) | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($null -eq $fileSignals.activeEnvironment) -Message "[$Wrapper] arquivo de sinais: activeEnvironment deveria ser nulo."
    Assert-True -Condition ([string]$fileSignals.activeEnvironmentAtOpen -eq $ExpectedAtOpen) -Message ("[$Wrapper] arquivo de sinais: activeEnvironmentAtOpen deveria ser '{0}'." -f $ExpectedAtOpen)
}

$script:PwshPath = (Get-Process -Id $PID).Path

function New-SyntheticTasksVariant {
    # Compila, em processo filho, uma variante da fixture com a propriedade ExportKBInfo
    # trocada (ou removida). O filho evita carregar no processo do teste uma segunda
    # assembly com a mesma identidade.
    param([string]$Name, [string]$Replacement)

    $propertyLine = 'public string ExportKBInfo { get; set; }'
    $source = [System.IO.File]::ReadAllText($fixtureSourcePath)
    if (-not $source.Contains($propertyLine)) {
        throw "Fixture sem a linha esperada: $propertyLine"
    }
    $variantDirectory = Join-Path $testRoot ('tasks-' + $Name)
    [System.IO.Directory]::CreateDirectory($variantDirectory) | Out-Null
    $variantSourcePath = Join-Path $variantDirectory 'SyntheticGeneXusMsBuildTasks.cs'
    $variantDllPath = Join-Path $variantDirectory 'Genexus.MsBuild.Tasks.dll'
    [System.IO.File]::WriteAllText($variantSourcePath, $source.Replace($propertyLine, $Replacement), [System.Text.UTF8Encoding]::new($false))
    $compileCommand = "Add-Type -TypeDefinition ([System.IO.File]::ReadAllText('$variantSourcePath')) -OutputAssembly '$variantDllPath'"
    & $script:PwshPath -NoProfile -Command $compileCommand
    Assert-True (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $variantDllPath -PathType Leaf)) "Falha ao compilar a variante '$Name' da assembly sintetica."
    return $variantDllPath
}

function Assert-ExportKbInfo {
    # Confere requestedContext, strategyTrace e o .msbuild gerado para ExportKbInfo.
    param(
        $Result,
        [string]$Label,
        [int]$ExpectedExit = 0,
        [string]$Requested,
        [string]$Source,
        [string]$Effective,
        [string]$EmittedProperty,
        [bool]$ExpectDowngradeWarning = $false
    )

    $diagnostic = $Result.Diagnostic
    Assert-True ($Result.ExitCode -eq $ExpectedExit) ("[$Label] exit esperado {0}; recebeu {1} ({2})." -f $ExpectedExit, $Result.ExitCode, $diagnostic.summary)
    $context = $diagnostic.requestedContext
    Assert-True ([string]$context.ExportKbInfo -eq $Requested) ("[$Label] requestedContext.ExportKbInfo esperado '{0}'; recebeu '{1}'." -f $Requested, $context.ExportKbInfo)
    Assert-True ([string]$context.ExportKbInfoSource -eq $Source) ("[$Label] ExportKbInfoSource esperado '{0}'; recebeu '{1}'." -f $Source, $context.ExportKbInfoSource)
    Assert-True ([string]$context.ExportKbInfoEffective -eq $Effective) ("[$Label] ExportKbInfoEffective esperado '{0}'; recebeu '{1}'." -f $Effective, $context.ExportKbInfoEffective)

    $traceLine = 'ExportKbInfo: pedido={0}; origem={1}; efetivo={2};' -f $Requested, $Source, $Effective
    $traceHits = @($diagnostic.strategyTrace | Where-Object { ([string]$_).StartsWith($traceLine, [System.StringComparison]::Ordinal) })
    Assert-True ($traceHits.Count -eq 1) ("[$Label] strategyTrace deveria ter uma linha iniciando com '{0}'." -f $traceLine)

    $downgradeWarnings = @($diagnostic.warnings | Where-Object { ([string]$_) -match '^ExportKbInfo: default true rebaixado' })
    if ($ExpectDowngradeWarning) {
        Assert-True ($downgradeWarnings.Count -eq 1) "[$Label] aviso de rebaixamento esperado em warnings."
    } else {
        Assert-True ($downgradeWarnings.Count -eq 0) "[$Label] aviso de rebaixamento inesperado em warnings."
    }

    if ($ExpectedExit -ne 0) { return }
    $msBuildText = [System.IO.File]::ReadAllText([string]$diagnostic.artifacts.MsBuildFilePath)
    Assert-True ($msBuildText.Contains("<ExportKbInfo>$Effective</ExportKbInfo>")) "[$Label] .msbuild deveria declarar <ExportKbInfo>$Effective</ExportKbInfo>."
    foreach ($propertyName in @('ExportKBInfo', 'ExportKBProperties')) {
        $attribute = $propertyName + '="$(ExportKbInfo)"'
        $shouldEmit = ($propertyName -eq $EmittedProperty)
        Assert-True ($msBuildText.Contains($attribute) -eq $shouldEmit) ("[$Label] atributo {0} no .msbuild: esperado presente={1}." -f $propertyName, $shouldEmit)
    }
}

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
    Add-Type -TypeDefinition ([System.IO.File]::ReadAllText($fixtureSourcePath)) -OutputAssembly $syntheticDllPath

    $decisiveLines = @("echo The active environment is 'EnvOpen'")

    # Teste decisivo dos sinais nos tres wrappers.
    foreach ($wrapper in @('Export', 'Import', 'Preview')) {
        $result = Invoke-WrapperScenario -Wrapper $wrapper -ScenarioRoot (Join-Path $testRoot ("decisive-" + $wrapper.ToLower())) -EnvironmentName 'EnvRequested' -StdOutCmdLines $decisiveLines
        Assert-True -Condition ($result.ExitCode -eq 0) -Message ("[$wrapper] decisivo deveria dar exit 0; recebeu {0} ({1})." -f $result.ExitCode, $result.Diagnostic.summary)
        Assert-DecisiveSignals -Diagnostic $result.Diagnostic -Wrapper $wrapper -ExpectedAtOpen 'EnvOpen'
    }

    $sourceRoot = Join-Path $testRoot 'ObjetosDaKbEmXml'
    [void][IO.Directory]::CreateDirectory($sourceRoot)
    $indexPath = Join-Path $testRoot 'index.sqlite'
    $indexOutput = & python (Join-Path $PSScriptRoot 'Build-KbIntelligenceIndex.py') --source-root $sourceRoot --output-path $indexPath
    Assert-True ($LASTEXITCODE -eq 0) "Falha ao criar índice sintético: $indexOutput"
    $missingOverride = Join-Path $testRoot 'missing-override.json'

    foreach ($wrapper in @('Export', 'Import', 'Preview')) {
        $expectedStage = if ($wrapper -eq 'Export') { 'pre-export-identity' } else { 'pre-import-identity' }
        foreach ($withIndex in @($false, $true)) {
            $scenarioRoot = Join-Path $testRoot "$wrapper-selective-index-$withIndex"
            $selection = @{ CatalogOverridePath = $missingOverride }
            if ($withIndex) { $selection.IndexPath = $indexPath }
            $blocked = Invoke-WrapperScenario -Wrapper $wrapper -ScenarioRoot $scenarioRoot `
                -Selection $selection -FakeExitCode 99 -StdOutCmdLines @(
                    'echo task-started> "%~dp0task-started.txt"'
                )
            Assert-True ($blocked.ExitCode -eq 35 -and $blocked.Diagnostic.exitCode -eq 35 -and $blocked.Diagnostic.stage -eq $expectedStage) "[$wrapper] esperado exit 35 em $expectedStage (índice=$withIndex): $($blocked.Diagnostic.summary)"
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $scenarioRoot 'task-started.txt'))) "[$wrapper] MSBuild não deve iniciar após bloqueio seletivo."
            if ($wrapper -eq 'Export') {
                $blockedContext = $blocked.Diagnostic.requestedContext
                Assert-True ([string]$blockedContext.ExportKbInfo -eq 'true' -and [string]$blockedContext.ExportKbInfoSource -eq 'default') "[Export] bloqueio $expectedStage deve registrar ExportKbInfo pedido e origem."
                Assert-True ($null -ne $blockedContext.PSObject.Properties['ExportKbInfoEffective'] -and $null -eq $blockedContext.ExportKbInfoEffective) "[Export] bloqueio $expectedStage deve registrar ExportKbInfoEffective nulo (anterior à checagem de suporte)."
            }
            $preflight = $blocked.Diagnostic.objectListPreflight
            Assert-True ($preflight.preflightEnabled -and -not $preflight.preflightSkipped -and $preflight.items.Count -eq 0) "[$wrapper] envelope de pré-validação incorreto."
            $diagnostic = $preflight.PSObject.Properties['catalogOverrideDiagnostic']
            if ($withIndex) {
                Assert-True ($diagnostic.Value.reason -eq 'override-path-unavailable' -and $null -ne $preflight.lastIndexBuildAt) "[$wrapper] diagnóstico de catálogo ou timestamp ausente."
            } else {
                Assert-True ($null -eq $diagnostic -and $null -eq $preflight.lastIndexBuildAt) "[$wrapper] ausência de índice deve ter prioridade."
            }
        }
    }

    $allowed = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'selective-ready') `
        -Selection @{ IndexPath = $indexPath } -EnvironmentName 'EnvRequested' -StdOutCmdLines $decisiveLines
    $allowedPreflight = $allowed.Diagnostic.objectListPreflight
    Assert-True ($allowed.ExitCode -eq 0 -and $allowedPreflight.items[0].status -eq 'not_in_index') 'Índice válido deve permitir pré-validação com aviso.'
    Assert-True ($null -eq $allowedPreflight.PSObject.Properties['catalogOverrideDiagnostic']) 'Pré-validação concluída deve omitir diagnóstico de catálogo.'
    Assert-True ($null -eq $allowed.Diagnostic.requestedContext.PSObject.Properties['CatalogOverridePath']) 'Seleção sem override explícito deve omitir o campo.'

    $validOverride = Join-Path $testRoot 'valid-override.json'
    [IO.File]::WriteAllText($validOverride, '{"types":{}}')
    $relativeOverride = [IO.Path]::GetRelativePath((Get-Location).Path, $validOverride)
    $explicit = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'selective-explicit') `
        -Selection @{ IndexPath = $indexPath; CatalogOverridePath = $relativeOverride } -StdOutCmdLines $decisiveLines
    Assert-True ($explicit.ExitCode -eq 0 -and $explicit.Diagnostic.requestedContext.CatalogOverridePath -eq $validOverride) 'Seleção deve registrar o caminho absoluto do override explícito.'
    $fullWithOverride = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'full-explicit') `
        -FullExportCatalogOverridePath $validOverride -StdOutCmdLines $decisiveLines
    Assert-True ($fullWithOverride.ExitCode -eq 0 -and $null -eq $fullWithOverride.Diagnostic.requestedContext.PSObject.Properties['CatalogOverridePath']) 'Export completo deve omitir o campo.'

    # ExportKbInfo: default true na seletiva e na completa; false explicito respeitado.
    Assert-ExportKbInfo -Result $allowed -Label 'ExportKbInfo seletiva default' -Requested 'true' -Source 'default' -Effective 'true' -EmittedProperty 'ExportKBInfo'
    Assert-ExportKbInfo -Result $fullWithOverride -Label 'ExportKbInfo completa default' -Requested 'true' -Source 'default' -Effective 'true' -EmittedProperty 'ExportKBInfo'
    $selectiveFalse = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-selective-false') `
        -Selection @{ IndexPath = $indexPath; ExportKbInfo = 'false' } -StdOutCmdLines $decisiveLines
    Assert-ExportKbInfo -Result $selectiveFalse -Label 'ExportKbInfo seletiva false explicito' -Requested 'false' -Source 'caller' -Effective 'false' -EmittedProperty 'ExportKBInfo'

    # Bloqueio pre-validate (diretorio pai do XPZ inexistente): campos registrados, efetivo nulo.
    $preValidate = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-pre-validate') `
        -ExtraArgs @{ XpzPath = (Join-Path $testRoot 'kbinfo-pre-validate\missing-dir\pkg.xpz') } -StdOutCmdLines $decisiveLines
    Assert-True ($preValidate.ExitCode -eq 33 -and [string]$preValidate.Diagnostic.stage -eq 'pre-validate') ("[ExportKbInfo pre-validate] esperado exit 33 em pre-validate; recebeu {0} em '{1}'." -f $preValidate.ExitCode, $preValidate.Diagnostic.stage)
    $preValidateContext = $preValidate.Diagnostic.requestedContext
    Assert-True ([string]$preValidateContext.ExportKbInfo -eq 'true' -and [string]$preValidateContext.ExportKbInfoSource -eq 'default') '[ExportKbInfo pre-validate] deve registrar ExportKbInfo pedido e origem.'
    Assert-True ($null -ne $preValidateContext.PSObject.Properties['ExportKbInfoEffective'] -and $null -eq $preValidateContext.ExportKbInfoEffective) '[ExportKbInfo pre-validate] deve registrar ExportKbInfoEffective nulo.'

    # Task sem ExportKBInfo: variantes da assembly, cada cenario em processo filho.
    $noPropertyDll = New-SyntheticTasksVariant -Name 'no-kbinfo' -Replacement ''
    $propertiesOnlyDll = New-SyntheticTasksVariant -Name 'kbproperties-only' -Replacement 'public string ExportKBProperties { get; set; }'

    $noPropertyDefault = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-noprop-default') `
        -TasksDllPath $noPropertyDll -InChildProcess -StdOutCmdLines $decisiveLines
    Assert-ExportKbInfo -Result $noPropertyDefault -Label 'ExportKbInfo sem suporte default' -Requested 'true' -Source 'default' -Effective 'false' -EmittedProperty '' -ExpectDowngradeWarning $true

    $noPropertyFalse = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-noprop-false') `
        -TasksDllPath $noPropertyDll -InChildProcess -ExtraArgs @{ ExportKbInfo = 'false' } -StdOutCmdLines $decisiveLines
    Assert-ExportKbInfo -Result $noPropertyFalse -Label 'ExportKbInfo sem suporte false explicito' -Requested 'false' -Source 'caller' -Effective 'false' -EmittedProperty ''

    $noPropertyTrue = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-noprop-true') `
        -TasksDllPath $noPropertyDll -InChildProcess -ExtraArgs @{ ExportKbInfo = 'true' } -StdOutCmdLines $decisiveLines
    Assert-ExportKbInfo -Result $noPropertyTrue -Label 'ExportKbInfo sem suporte true explicito' -ExpectedExit 34 -Requested 'true' -Source 'caller' -Effective 'true'
    Assert-True ([string]$noPropertyTrue.Diagnostic.stage -eq 'task-support') '[ExportKbInfo sem suporte true explicito] stage esperado task-support.'

    $propertiesOnlyDefault = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-propsonly-default') `
        -TasksDllPath $propertiesOnlyDll -InChildProcess -StdOutCmdLines $decisiveLines
    Assert-ExportKbInfo -Result $propertiesOnlyDefault -Label 'ExportKbInfo so ExportKBProperties default' -Requested 'true' -Source 'default' -Effective 'false' -EmittedProperty 'ExportKBProperties' -ExpectDowngradeWarning $true

    $propertiesOnlyTrue = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'kbinfo-propsonly-true') `
        -TasksDllPath $propertiesOnlyDll -InChildProcess -ExtraArgs @{ ExportKbInfo = 'true' } -StdOutCmdLines $decisiveLines
    Assert-ExportKbInfo -Result $propertiesOnlyTrue -Label 'ExportKbInfo so ExportKBProperties true explicito' -Requested 'true' -Source 'caller' -Effective 'true' -EmittedProperty 'ExportKBProperties'

    $invalidOverride = Join-Path $testRoot 'invalid-override.json'
    [IO.File]::WriteAllText($invalidOverride, '{"upstreamPending":"invalid"}')
    foreach ($wrapper in @('Export', 'Import', 'Preview')) {
        $invalid = Invoke-WrapperScenario -Wrapper $wrapper -ScenarioRoot (Join-Path $testRoot "$wrapper-invalid-override") `
            -Selection @{ IndexPath = $indexPath; CatalogOverridePath = $invalidOverride }
        Assert-True ($invalid.ExitCode -eq 90) "[$wrapper] conteúdo de override inválido deve preservar exit 90."
    }

    # Troca bem-sucedida (Export): efetivo = leitura posterior; AtOpen = abertura.
    $exportSwap = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'swap-export') -EnvironmentName 'EnvB' -StdOutCmdLines @(
        "echo The active environment is 'EnvA'",
        'echo ^> Set Active Environment Sucesso',
        "echo The active environment is 'EnvB'"
    )
    Assert-True -Condition ($exportSwap.ExitCode -eq 0) -Message ("[Export] troca OK deveria dar exit 0; recebeu {0}." -f $exportSwap.ExitCode)
    Assert-True -Condition ([string]$exportSwap.Diagnostic.observedContext.ActiveEnvironment -eq 'EnvB') -Message ("[Export] ActiveEnvironment deveria ser 'EnvB'.")
    Assert-True -Condition ([string]$exportSwap.Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq 'EnvA') -Message "[Export] ActiveEnvironmentAtOpen deveria ser 'EnvA'."

    # Estrutural no .msbuild do Export: Get(AtOpen) antes do Set; Set antes do Get efetivo.
    $exportMsBuild = [System.IO.File]::ReadAllText([string]$exportSwap.Diagnostic.artifacts.MsBuildFilePath)
    $firstGet = $exportMsBuild.IndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $set = $exportMsBuild.IndexOf('<SetActiveEnvironment', [System.StringComparison]::Ordinal)
    $lastGet = $exportMsBuild.LastIndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    Assert-True -Condition ($firstGet -ge 0 -and $firstGet -lt $set -and $set -lt $lastGet) -Message '[Export] ordem Get -> Set -> Get esperada no .msbuild.'

    # Set falho: bloqueio cita a abertura; exits preservados (41 Export / 31 Import-Preview).
    $exportSetFailed = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'set-failed-export') -EnvironmentName 'EnvRequested' -FakeExitCode 1 -StdOutCmdLines @(
        "echo The active environment is 'EnvOpen'",
        "echo Ambiente 'EnvRequested' nao existe",
        'echo error : ^> Set Active Environment falhou'
    )
    Assert-True -Condition ($exportSetFailed.ExitCode -eq 41) -Message ("[Export] Set falho + MSBuild != 0 deveria preservar exit 41; recebeu {0}." -f $exportSetFailed.ExitCode)
    $exportReason = @($exportSetFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveEnvironment falhou' })
    Assert-True -Condition ($exportReason.Count -eq 1 -and $exportReason[0] -match "abertura era 'EnvOpen'") -Message ("[Export] bloqueio deveria citar a abertura 'EnvOpen'; recebeu '{0}'." -f ($exportReason -join ' / '))

    foreach ($wrapper in @('Import', 'Preview')) {
        $setFailed = Invoke-WrapperScenario -Wrapper $wrapper -ScenarioRoot (Join-Path $testRoot ("set-failed-" + $wrapper.ToLower())) -EnvironmentName 'EnvRequested' -FakeExitCode 1 -StdOutCmdLines @(
            "echo The active environment is 'EnvOpen'",
            "echo Ambiente 'EnvRequested' nao existe",
            'echo error : ^> Set Active Environment falhou'
        )
        Assert-True -Condition ($setFailed.ExitCode -eq 31) -Message ("[$wrapper] Set falho + MSBuild != 0 deveria preservar exit 31; recebeu {0}." -f $setFailed.ExitCode)
        $reason = @($setFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveEnvironment falhou' })
        Assert-True -Condition ($reason.Count -eq 1 -and $reason[0] -match "abertura era 'EnvOpen'") -Message ("[$wrapper] bloqueio deveria citar a abertura 'EnvOpen'; recebeu '{0}'." -f ($reason -join ' / '))
    }

    # Preview: Open SEM CaptureOutput (preservado).
    $previewOpen = [System.IO.File]::ReadAllText([string](Invoke-WrapperScenario -Wrapper 'Preview' -ScenarioRoot (Join-Path $testRoot 'preview-open') -StdOutCmdLines $decisiveLines).Diagnostic.artifacts.MsBuildFilePath)
    Assert-True -Condition ($previewOpen -match [regex]::Escape('<OpenKnowledgeBase Directory="$(KBPath)" />')) -Message '[Preview] OpenKnowledgeBase deve permanecer sem CaptureOutput.'
}
finally {
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'GENEXUS_MSBUILD_ACTIVE_CONTEXT_WRAPPERS_E2E_SELFTEST_OK'
