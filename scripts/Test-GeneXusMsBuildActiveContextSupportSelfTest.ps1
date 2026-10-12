#requires -Version 7.4

<#
.SYNOPSIS
    Self-test da folha GeneXusMsBuildActiveContextSupport.ps1.

.DESCRIPTION
    Cobre: (1) ciclo folha <-> suporte de deploy (folha nao cita deploy/hosting; deploy carrega
    a folha); (2) guarda de dupla definicao (carga idempotente); (3) semantica do marcador de
    falha (Loose vs ErrorSeverity, nunca PascalCase); (4) politica de fonte stdout/stderr;
    (5) matriz do classificador de exit do OpenHeadless (0/20/21/22/25 e reservados 23/24).
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

$scriptDirectory = $PSScriptRoot
$leafPath = Join-Path $scriptDirectory 'GeneXusMsBuildActiveContextSupport.ps1'
$deployPath = Join-Path $scriptDirectory 'GeneXusKbDeploymentEnvironmentSupport.ps1'

foreach ($required in @($leafPath, $deployPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Arquivo ausente para o self-test: $required"
    }
}

# (1) Ciclo: a folha nao cita deploy/hosting; o suporte de deploy carrega a folha.
$leafText = [System.IO.File]::ReadAllText($leafPath)
$deployText = [System.IO.File]::ReadAllText($deployPath)

foreach ($forbidden in @('GeneXusKbDeploymentEnvironmentSupport', 'GeneXusKbHostingKindSupport')) {
    Assert-True -Condition ($leafText -notmatch [regex]::Escape($forbidden)) -Message "A folha nao pode citar '$forbidden' (ciclo folha -> deploy)."
}
Assert-True -Condition ($deployText -match 'GeneXusMsBuildActiveContextSupport\.ps1') -Message 'O suporte de deploy deve dot-source a folha GeneXusMsBuildActiveContextSupport.ps1.'

# Reservados: a folha nunca pode devolver 23/24 como ramo.
Assert-True -Condition ($leafText -notmatch '(?<![A-Za-z])return\s+23\b') -Message 'A folha nao pode ter return 23 (reservado).'
Assert-True -Condition ($leafText -notmatch '(?<![A-Za-z])return\s+24\b') -Message 'A folha nao pode ter return 24 (reservado).'

# (1b) Grafo de carga: os 4 alvos carregam so o leve; os wrappers de build seguem no de deploy.
$lightConsumers = @('Invoke-GeneXusXpzExport.ps1', 'Invoke-GeneXusXpzImport.ps1', 'Test-GeneXusXpzImportPreview.ps1', 'Open-GeneXusKbHeadless.ps1')
foreach ($consumer in $lightConsumers) {
    $consumerText = [System.IO.File]::ReadAllText((Join-Path $scriptDirectory $consumer))
    Assert-True -Condition ($consumerText -match 'GeneXusMsBuildActiveContextSupport\.ps1') -Message "$consumer deveria carregar a folha GeneXusMsBuildActiveContextSupport.ps1."
    Assert-True -Condition ($consumerText -notmatch 'GeneXusKbDeploymentEnvironmentSupport\.ps1') -Message "$consumer nao deveria carregar o suporte de deploy (traz GeneXusKbHostingKindSupport junto)."
}
foreach ($buildWrapper in @('Invoke-GeneXusKbBuildAll.ps1', 'Invoke-GeneXusKbSpecifyGenerate.ps1')) {
    $buildText = [System.IO.File]::ReadAllText((Join-Path $scriptDirectory $buildWrapper))
    Assert-True -Condition ($buildText -match 'GeneXusKbDeploymentEnvironmentSupport\.ps1') -Message "$buildWrapper deveria carregar o suporte de deploy (transitivamente a folha)."
}

# (2) Carga da folha + guarda de dupla definicao (idempotencia).
. $leafPath
. $leafPath
foreach ($fn in @('Resolve-GeneXusKbActiveContextReadings', 'Resolve-GeneXusMsBuildFailureMarker', 'Get-GeneXusMsBuildOperationExitCode', 'Resolve-GeneXusMsBuildDiagnosticSource')) {
    Assert-True -Condition ([bool](Get-Command -Name $fn -CommandType Function -ErrorAction SilentlyContinue)) -Message "Funcao ausente apos carregar a folha: $fn"
}

# (3) Semantica do marcador de falha.
$setVersionErrorLine = '(32,5): error : > Set Active Version falhou'
$setVersionBareLine = 'Set Active Version falhou'
$setVersionSuccess = '> Set Active Version Sucesso'
$pascalCase = 'SetActiveVersion failed'

$markers = Resolve-GeneXusMsBuildFailureMarker -Text $setVersionErrorLine
Assert-True -Condition ($markers['SetVersion'].Loose) -Message 'Loose deveria casar a linha de falha de Set Active Version.'
Assert-True -Condition ($markers['SetVersion'].ErrorSeverity) -Message 'ErrorSeverity deveria casar a linha com error : de Set Active Version.'

$markers = Resolve-GeneXusMsBuildFailureMarker -Text $setVersionBareLine
Assert-True -Condition ($markers['SetVersion'].Loose) -Message 'Loose deveria casar a linha crua (compatibilidade com o legado).'
Assert-True -Condition (-not $markers['SetVersion'].ErrorSeverity) -Message 'ErrorSeverity NAO deveria casar a linha crua sem error :.'

$markers = Resolve-GeneXusMsBuildFailureMarker -Text $setVersionSuccess
Assert-True -Condition (-not $markers['SetVersion'].Loose) -Message 'Linha de sucesso nao pode casar como falha (Loose).'

$markers = Resolve-GeneXusMsBuildFailureMarker -Text $pascalCase
Assert-True -Condition (-not $markers['SetVersion'].Loose -and -not $markers['SetVersion'].ErrorSeverity) -Message 'PascalCase nunca pode casar o marcador.'

# Open/Close com Task opcional.
$openWithTask = 'error : > Open Knowledge Base Task falhou'
$markers = Resolve-GeneXusMsBuildFailureMarker -Text $openWithTask
Assert-True -Condition ($markers['Open'].ErrorSeverity) -Message 'ErrorSeverity deveria casar Open Knowledge Base Task falhou.'

$closeError = 'error : > Close Knowledge Base falhou'
$markers = Resolve-GeneXusMsBuildFailureMarker -Text $closeError
Assert-True -Condition ($markers['Close'].ErrorSeverity) -Message 'ErrorSeverity deveria casar Close Knowledge Base falhou.'

# (4) Politica de fonte stdout/stderr.
$source = Resolve-GeneXusMsBuildDiagnosticSource -StdOutText $setVersionErrorLine -StdErrFilteredText ''
Assert-True -Condition ($source.Source -eq 'stdout') -Message 'stdout com marcador error deve ser selecionado.'

$source = Resolve-GeneXusMsBuildDiagnosticSource -StdOutText 'sem marcador' -StdErrFilteredText $setVersionErrorLine
Assert-True -Condition ($source.Source -eq 'stderr') -Message 'stderr filtrado com marcador error deve ser selecionado quando o stdout nao tem marcador.'

$source = Resolve-GeneXusMsBuildDiagnosticSource -StdOutText $setVersionErrorLine -StdErrFilteredText $closeError
Assert-True -Condition ($source.Source -eq 'stdout') -Message 'Em conflito, stdout vence.'

$source = Resolve-GeneXusMsBuildDiagnosticSource -StdOutText 'apenas ruido' -StdErrFilteredText 'apenas ruido'
Assert-True -Condition ($source.Source -eq 'stdout') -Message 'Sem marcador error, stdout e o default.'

# (5) Matriz do classificador de exit.
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 0 -StdOutText $setVersionErrorLine -StdErrFilteredText '') -eq 0) -Message 'MsBuildExitCode 0 deve classificar como 0 mesmo com marcadores.'

Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText $setVersionErrorLine -StdErrFilteredText '') -eq 21) -Message 'Set Active Version falho deve classificar 21.'
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText 'error : > Set Active Environment falhou' -StdErrFilteredText '') -eq 22) -Message 'Set Active Environment falho deve classificar 22.'
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText $openWithTask -StdErrFilteredText '') -eq 20) -Message 'Open Knowledge Base falho deve classificar 20.'
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText $closeError -StdErrFilteredText '') -eq 25) -Message 'Close Knowledge Base falho (primario) deve classificar 25.'
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText 'falha sem marcador mapeado' -StdErrFilteredText '') -eq 20) -Message 'Formato desconhecido deve classificar 20.'
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText '> GetActiveEnvironment Sucesso' -StdErrFilteredText '') -eq 20) -Message 'Linha de sucesso de Get nunca pode virar 23/24 (nomes PascalCase/reservados ignorados).'

# Conflito/complemento entre fontes.
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText $setVersionErrorLine -StdErrFilteredText 'error : > Set Active Environment falhou') -eq 21) -Message 'stdout (SetVersion=21) deve vencer o stderr (SetEnvironment=22).'
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText 'apenas ruido' -StdErrFilteredText $setVersionErrorLine) -eq 21) -Message 'Marcador so em stderr filtrado deve classificar a partir do stderr.'

# 25 so com Close error primario: se Open tambem falhou, Open vence (20).
Assert-True -Condition ((Get-GeneXusMsBuildOperationExitCode -MsBuildExitCode 1 -StdOutText ($openWithTask + "`n" + $closeError) -StdErrFilteredText '') -eq 20) -Message 'Com Open e Close em error, Open tem prioridade (20).'

Write-Output 'GENEXUS_MSBUILD_ACTIVE_CONTEXT_SUPPORT_SELFTEST_OK'
