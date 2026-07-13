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

function Split-KnownGeneXusStderrNoise {
    param([AllowNull()][string]$Text)

    $pattern = '^context \[anonymous\] \d+:\d+ attribute component isn''t defined$'
    $lines = if ([string]::IsNullOrEmpty($Text)) { @() } else { @($Text -split "`r?`n") }
    return [ordered]@{
        noise = @($lines | Where-Object { $_ -match $pattern })
        content = @($lines | Where-Object { $_ -notmatch $pattern } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
}

$noise = "context [anonymous] 1:12 attribute component isn't defined"
foreach ($count in 1, 2, 3, 4) {
    foreach ($separator in "`n", "`r`n") {
        $noiseLines = @()
        foreach ($index in 1..$count) {
            $noiseLines += $noise
        }
        $result = Split-KnownGeneXusStderrNoise -Text ($noiseLines -join $separator)
        Assert-True -Condition ($result.noise.Count -eq $count) -Message "Esperava $count linhas de ruido filtradas."
        Assert-True -Condition ($result.content.Count -eq 0) -Message 'Ruido conhecido isolado nao pode permanecer em stderrContent.'
    }
}

$withoutFinalNewline = Split-KnownGeneXusStderrNoise -Text ($noise + "`n" + $noise)
Assert-True -Condition ($withoutFinalNewline.noise.Count -eq 2) -Message 'Ausencia de newline final nao pode alterar a filtragem.'

$mixed = Split-KnownGeneXusStderrNoise -Text ($noise + "`r`nERRO REAL: detalhe preservado`r`n" + $noise)
Assert-True -Condition ($mixed.noise.Count -eq 2) -Message 'Stderr misto deveria separar as duas linhas conhecidas.'
Assert-True -Condition ($mixed.content.Count -eq 1 -and $mixed.content[0] -eq 'ERRO REAL: detalhe preservado') -Message 'Linha adicional real deve permanecer no stderrContent.'

$containsOnly = Split-KnownGeneXusStderrNoise -Text ('prefixo ' + $noise)
Assert-True -Condition ($containsOnly.noise.Count -eq 0 -and $containsOnly.content.Count -eq 1) -Message 'Filtro full-line nao pode remover mensagem maior que apenas contenha a frase.'

$scripts = @(
    [ordered]@{ Path = (Join-Path $PSScriptRoot 'Invoke-GeneXusKbBuildAll.ps1'); SubState = 'operationalSubStateBuild' },
    [ordered]@{ Path = (Join-Path $PSScriptRoot 'Invoke-GeneXusKbSpecifyGenerate.ps1'); SubState = 'operationalSubStateSpecify' }
)

foreach ($scriptUnderTest in $scripts) {
    $path = $scriptUnderTest['Path']
    $subState = $scriptUnderTest['SubState']
    Assert-True -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Wrapper ausente: $path"
    $source = Get-Content -LiteralPath $path -Raw
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
    Assert-True -Condition ($errors.Count -eq 0) -Message "Parse PowerShell falhou em $path"

    $timingStartIndex = $source.IndexOf("`$script:TimingLog['scriptStart']")
    Assert-True -Condition ($timingStartIndex -ge 0) -Message 'Marco de inicio do try externo ausente.'
    $outerTryIndex = $source.IndexOf('try {', $timingStartIndex)
    Assert-True -Condition ($outerTryIndex -ge 0) -Message 'Try externo ausente apos o marco de inicio.'
    $postProcessingErrorDefaultIndex = $source.IndexOf('$postProcessingError = $null')
    Assert-True -Condition ($postProcessingErrorDefaultIndex -ge 0 -and $postProcessingErrorDefaultIndex -lt $outerTryIndex) -Message 'postProcessingError deve ser inicializado antes do try externo para o recovery funcionar sob StrictMode.'
    $msBuildExitCodeDefaultIndex = $source.IndexOf('$msBuildExitCode = $null')
    Assert-True -Condition ($msBuildExitCodeDefaultIndex -ge 0 -and $msBuildExitCodeDefaultIndex -lt $outerTryIndex) -Message 'msBuildExitCode deve ser inicializado antes do try externo para o recovery funcionar sob StrictMode.'

    Assert-True -Condition ($source -match ("\$" + [regex]::Escape($subState) + ' = \$null')) -Message "Default seguro ausente para $subState."
    Assert-True -Condition ($source -match '\$msBuildCategoryBBlocked = \$false') -Message 'Default seguro ausente para msBuildCategoryBBlocked.'
    Assert-True -Condition ($source -match '\$outerCatchError = \$_\.Exception\.Message') -Message 'Outer catch deve capturar o erro original imediatamente.'
    Assert-True -Condition ($source -match 'postProcessingError\s*= \$postProcessingError') -Message 'Recovery deve reutilizar postProcessingError capturado.'
    Assert-True -Condition ($source -match 'if \(\$null -ne \$msBuildExitCode\) \{') -Message 'Recovery externo deve preservar qualquer resultado conhecido do MSBuild, inclusive não-zero.'
    Assert-True -Condition ($source -notmatch 'if \(\(\$null -ne \$msBuildExitCode\) -and \(\$msBuildExitCode -eq 0\)\) \{') -Message 'Recovery externo não pode ignorar resultado MSBuild não-zero.'
    Assert-True -Condition ($source -match '\$recoveryBuildStatus = \$buildStatus') -Message 'Recovery deve partir da classificação já calculada.'
    Assert-True -Condition ($source -match '\$recoveryExitCode = \[int\]\$recoveryBuildStatus\.ExitCode') -Message 'Recovery deve preservar o exitCode da classificação.'
    Assert-True -Condition ($source -match 'wrapperExitCode = \$recoveryExitCode') -Message 'executionEvidence deve repetir o exitCode preservado.'
    Assert-True -Condition ($source -match 'exit \$recoveryExitCode') -Message 'Processo deve sair com o exitCode preservado pelo recovery.'
    Assert-True -Condition ($source -match [regex]::Escape('^context \[anonymous\] \d+:\d+ attribute component')) -Message 'Filtro stderr full-line ausente.'
    Assert-True -Condition ($source -match 'stderrFilteredNoise\s*= \@\(\$recoveryStdErrFilteredNoise') -Message 'Recovery deve expor stderrFilteredNoise.'

    if ($subState -eq 'operationalSubStateBuild') {
        Assert-True -Condition ($source -match '\$recoveryStatus -eq ''compilou limpo''') -Message 'BuildAll deve exigir status limpo anterior para promover recovery limpo.'
        Assert-True -Condition ($source -match '\$recoveryKbOpen -and \$recoveryBuildAllDone') -Message 'BuildAll deve exigir KB aberta e marcador BuildAll antes de promover recovery limpo.'
    } else {
        Assert-True -Condition ($source -match '\$recoveryStatus -eq ''specify e generate concluídos''') -Message 'SpecifyGenerate deve exigir status limpo anterior para promover recovery limpo.'
        Assert-True -Condition ($source -match '\$recoverySpecifyDone -and \$recoveryGenerateDone') -Message 'SpecifyGenerate deve exigir os dois marcadores antes de promover recovery limpo.'
    }
}

Write-Output 'GENEXUS_MSBUILD_POST_PROCESSING_RESILIENCE_SELFTEST_OK'
