#requires -Version 7.4

<#
.SYNOPSIS
    Round-trip do registro de eventos pos-build: registrar -> ler -> classificar.

.DESCRIPTION
    Registra eventos a partir de um JSON de build sintetico, confirma que o campo de hashes
    e o espelho legivel são gravados, que a classificação subsequente não rebaixa, e que
    registrar um segundo environment preserva o primeiro (campo e espelho).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'GeneXusMsBuildPostBuildEventsSupport.ps1')
. (Join-Path $scriptDir 'GeneXusKbDeploymentEnvironmentSupport.ps1')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function New-BuildJson {
    param([string]$EnvName, [string[]]$Events, [string]$Path)
    # Build apto como base do registro: exitCode e msBuildExitCode 0, sem msBuildFailed, status compilou limpo.
    $obj = [ordered]@{
        exitCode          = 0
        status            = 'compilou limpo'
        executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
        observedContext   = [ordered]@{ ActiveEnvironment = $EnvName }
        stdoutSignals     = [ordered]@{ postBuildEvents = @($Events) }
    }
    [System.IO.File]::WriteAllText($Path, ($obj | ConvertTo-Json -Depth 8), (Get-Utf8NoBomEncoding))
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-pbe-reg-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $metadataPath = Join-Path $tempRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'deployment_environment_name: NETPostgreSQL'
        'deployment_hosting_kind: dotnet-core-self-host'
        'kb_environment_count: 2'
        'kb_environment_names: NETFramework, NETPostgreSQL'
        '---'
        ''
        '## Outra secao'
        ''
        'conteudo preexistente'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata, (Get-Utf8NoBomEncoding))

    $registerScript = Join-Path $scriptDir 'Register-GeneXusKbPostBuildEvents.ps1'

    $sino    = 'start "" powershell -NoProfile -WindowStyle Hidden -Command "(New-Object System.Media.SoundPlayer ''c:\temp\sino.wav'').PlaySync()"'
    $deploy1 = 'start "" /D "c:\Dropbox\AplicativosFrigobyte\AtualizacaoDoDeploy" "AtualizaDeployFB18PgNetCore.Bat"'
    $deploy2 = 'start "" /D "c:\Dropbox\AplicativosFrigobyte\AtualizacaoDoDeploy" "AtualizaDeployFB18.Bat"'

    # --- Registro do environment 1 ---
    $json1 = Join-Path $tempRoot 'build1.json'
    New-BuildJson -EnvName 'NETPostgreSQL' -Events @($sino, $deploy1) -Path $json1
    & $registerScript -BuildResultJsonPath $json1 -EnvironmentName 'NETPostgreSQL' -MetadataPath $metadataPath -ConfirmRegistration -AsJson | Out-Null

    $hashes1 = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment -MetadataPath $metadataPath -EnvironmentName 'NETPostgreSQL'
    if (@($hashes1).Count -ne 2) { throw "ASSERT_FAILED: env1 deveria ter 2 hashes, atual=$(@($hashes1).Count)" }

    $class1 = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($sino, $deploy1) -RegisteredHashes $hashes1
    if ($class1.shouldDowngrade) { throw 'ASSERT_FAILED: apos registro, env1 nao deveria rebaixar' }

    $text1 = [System.IO.File]::ReadAllText($metadataPath)
    if ($text1 -notmatch '## Eventos pos-build registrados') { throw 'ASSERT_FAILED: secao-espelho ausente' }
    if ($text1 -notmatch '### env: NETPostgreSQL') { throw 'ASSERT_FAILED: subsecao env1 ausente no espelho' }
    if ($text1 -notmatch 'AtualizaDeployFB18PgNetCore\.Bat') { throw 'ASSERT_FAILED: linha crua do deploy1 ausente no espelho' }
    if ($text1 -notmatch 'conteudo preexistente') { throw 'ASSERT_FAILED: conteudo preexistente do arquivo foi perdido' }
    # Higiene de fim de arquivo: uma unica quebra final, sem linha em branco (git diff --check).
    if ($text1 -match "`n`n$") { throw 'ASSERT_FAILED: o registro deixou linha em branco no fim do arquivo' }
    if ($text1 -notmatch "[^`n]`n$") { throw 'ASSERT_FAILED: o arquivo deveria terminar com uma unica quebra de linha' }

    # --- Registro do environment 2: preserva o 1 ---
    $json2 = Join-Path $tempRoot 'build2.json'
    New-BuildJson -EnvName 'NETFramework' -Events @($sino, $deploy2) -Path $json2
    & $registerScript -BuildResultJsonPath $json2 -EnvironmentName 'NETFramework' -MetadataPath $metadataPath -ConfirmRegistration -AsJson | Out-Null

    $hashes1After = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment -MetadataPath $metadataPath -EnvironmentName 'NETPostgreSQL'
    $hashes2 = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment -MetadataPath $metadataPath -EnvironmentName 'NETFramework'
    if (@($hashes1After).Count -ne 2) { throw "ASSERT_FAILED: env1 deveria continuar com 2 hashes apos registrar env2, atual=$(@($hashes1After).Count)" }
    if (@($hashes2).Count -ne 2) { throw "ASSERT_FAILED: env2 deveria ter 2 hashes, atual=$(@($hashes2).Count)" }

    $text2 = [System.IO.File]::ReadAllText($metadataPath)
    if ($text2 -notmatch '### env: NETPostgreSQL') { throw 'ASSERT_FAILED: subsecao env1 perdida apos registrar env2' }
    if ($text2 -notmatch '### env: NETFramework') { throw 'ASSERT_FAILED: subsecao env2 ausente' }
    if ($text2 -notmatch 'AtualizaDeployFB18PgNetCore\.Bat') { throw 'ASSERT_FAILED: linha crua do deploy1 perdida apos registrar env2' }
    if ($text2 -notmatch 'AtualizaDeployFB18\.Bat') { throw 'ASSERT_FAILED: linha crua do deploy2 ausente' }
    if ($text2 -match "`n`n$") { throw 'ASSERT_FAILED: o segundo registro deixou linha em branco no fim do arquivo' }

    # Re-registro do mesmo environment substitui (não duplica) a subsecao.
    & $registerScript -BuildResultJsonPath $json1 -EnvironmentName 'NETPostgreSQL' -MetadataPath $metadataPath -ConfirmRegistration -AsJson | Out-Null
    $text3 = [System.IO.File]::ReadAllText($metadataPath)
    $occurrences = ([regex]::Matches($text3, '### env: NETPostgreSQL')).Count
    if ($occurrences -ne 1) { throw "ASSERT_FAILED: re-registro deveria manter 1 subsecao env1, atual=$occurrences" }

    # --- Forma nova: registro com fingerprint de familia; contagem nova no build seguinte -> esperado ---
    $famX = '[APLICADO] .js varridos=2966 | arquivos com chave negativa em gx.domain=1 | chaves corrigidas=1'
    $famY = '[APLICADO] .js varridos=2999 | arquivos com chave negativa em gx.domain=2 | chaves corrigidas=2'
    $json4 = Join-Path $tempRoot 'build4.json'
    New-BuildJson -EnvName 'NETFramework' -Events @($sino, $famX) -Path $json4
    $reg4 = (& $registerScript -BuildResultJsonPath $json4 -EnvironmentName 'NETFramework' -MetadataPath $metadataPath -ConfirmRegistration -AsJson) -join "`n" | ConvertFrom-Json
    # NETFramework tinha (sino, deploy2); o novo conjunto mantem o sino e tira o deploy2.
    if ([int]$reg4.removedHashCount -ne 1) { throw "ASSERT_FAILED: removedHashCount deveria ser 1; atual=$($reg4.removedHashCount)" }
    $hashes4 = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment -MetadataPath $metadataPath -EnvironmentName 'NETFramework'
    $c4 = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($sino, $famY) -RegisteredHashes $hashes4
    if ($c4.shouldDowngrade -or $c4.expected.Count -ne 2) { throw 'ASSERT_FAILED: registro de familia seguido de contagem nova deveria ser esperado' }

    # Um fingerprint por hash: duas linhas de familia com contagens diferentes viram um evento registrado.
    $json5 = Join-Path $tempRoot 'build5.json'
    New-BuildJson -EnvName 'NETPostgreSQL' -Events @($famX, $famY) -Path $json5
    $reg5 = (& $registerScript -BuildResultJsonPath $json5 -EnvironmentName 'NETPostgreSQL' -MetadataPath $metadataPath -ConfirmRegistration -AsJson) -join "`n" | ConvertFrom-Json
    if ([int]$reg5.registeredEventCount -ne 1 -or @($reg5.registeredHashes).Count -ne 1) { throw 'ASSERT_FAILED: duas linhas de familia com contagens diferentes deveriam virar um hash' }
    if ([int]$reg5.removedHashCount -ne 2) { throw "ASSERT_FAILED: NETPostgreSQL deveria remover 2 hashes anteriores; atual=$($reg5.removedHashCount)" }
    $text5 = [System.IO.File]::ReadAllText($metadataPath)
    if ($text5 -notmatch 'as linhas cruas abaixo sao a evidencia de forma') { throw 'ASSERT_FAILED: frase-guia do espelho ausente' }

    # Registro legado (hash da forma antiga, contagens X) com contagens Y -> inesperado; com X -> esperado.
    $legacyX = Get-GeneXusPostBuildEventNormalizedHash -Line $famX
    $c6 = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($famY) -RegisteredHashes @($legacyX)
    if (-not $c6.shouldDowngrade -or $c6.legacyMatchCount -ne 0) { throw 'ASSERT_FAILED: registro legado com contagem diferente deveria ser inesperado (exige re-registro)' }
    $c7 = Get-GeneXusPostBuildEventClassification -PostBuildEventLines @($famX) -RegisteredHashes @($legacyX)
    if ($c7.shouldDowngrade -or $c7.legacyMatchCount -ne 1) { throw 'ASSERT_FAILED: registro legado com a mesma contagem deveria ser aceito com legacyMatchCount=1' }

    # Sucesso do SpecifyGenerate ("specify e generate concluidos") tambem e base apta para o registro.
    $specifyObj = [ordered]@{
        exitCode          = 0
        status            = 'specify e generate conclu' + [char]0x00ED + 'dos'
        executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
        observedContext   = [ordered]@{ ActiveEnvironment = 'NETSpecifyGenerate' }
        stdoutSignals     = [ordered]@{ postBuildEvents = @($sino) }
    }
    $jsonSg = Join-Path $tempRoot 'build-specify.json'
    [System.IO.File]::WriteAllText($jsonSg, ($specifyObj | ConvertTo-Json -Depth 8), (Get-Utf8NoBomEncoding))
    & $registerScript -BuildResultJsonPath $jsonSg -EnvironmentName 'NETSpecifyGenerate' -MetadataPath $metadataPath -ConfirmRegistration -AsJson | Out-Null
    $hashesSg = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment -MetadataPath $metadataPath -EnvironmentName 'NETSpecifyGenerate'
    if (@($hashesSg).Count -ne 1) { throw "ASSERT_FAILED: build de SpecifyGenerate apto deveria registrar 1 hash; atual=$(@($hashesSg).Count)" }

    # Base do registro: o Register recusa build nao apto (BLOCK) e nao grava nada.
    $textBeforeRefusal = [System.IO.File]::ReadAllText($metadataPath)
    $nonBaseCases = @(
        @{ Name = 'exitCode 1';              Mutate = { param($o) $o['exitCode'] = 1 };                                            Match = 'exitCode' }
        @{ Name = 'msBuildExitCode ausente'; Mutate = { param($o) $o.Remove('executionEvidence') };                                Match = 'msBuildExitCode' }
        @{ Name = 'msBuildFailed verdadeiro'; Mutate = { param($o) $o['executionEvidence'] = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $true } }; Match = 'msBuildFailed' }
        @{ Name = 'status nao previsto';     Mutate = { param($o) $o['status'] = 'falhou' };                                       Match = 'status nao previsto' }
        @{ Name = 'pendente sem registryStatus'; Mutate = { param($o) $o['status'] = 'operacao concluida, pendente de confirmacao funcional' }; Match = 'sem registryStatus' }
    )
    foreach ($case in $nonBaseCases) {
        $obj = [ordered]@{
            exitCode          = 0
            status            = 'compilou limpo'
            executionEvidence = [ordered]@{ msBuildExitCode = 0; msBuildFailed = $false }
            observedContext   = [ordered]@{ ActiveEnvironment = 'NETPostgreSQL' }
            stdoutSignals     = [ordered]@{ postBuildEvents = @($sino, $deploy1) }
        }
        & $case.Mutate $obj
        $jsonNb = Join-Path $tempRoot ('nonbase-' + [guid]::NewGuid().ToString('N') + '.json')
        [System.IO.File]::WriteAllText($jsonNb, ($obj | ConvertTo-Json -Depth 8), (Get-Utf8NoBomEncoding))
        $refusal = $null
        try {
            & $registerScript -BuildResultJsonPath $jsonNb -EnvironmentName 'NETPostgreSQL' -MetadataPath $metadataPath -ConfirmRegistration -AsJson | Out-Null
        } catch {
            $refusal = $_.Exception.Message
        }
        if ($null -eq $refusal -or $refusal -notmatch 'BLOCK: build nao apto') { throw "ASSERT_FAILED: build nao apto ($($case.Name)) deveria ser recusado com BLOCK; obtido='$refusal'" }
        if ($refusal -notmatch $case.Match) { throw "ASSERT_FAILED: recusa de '$($case.Name)' deveria citar '$($case.Match)'; obtido='$refusal'" }
    }
    if ([System.IO.File]::ReadAllText($metadataPath) -ne $textBeforeRefusal) { throw 'ASSERT_FAILED: recusa por build nao apto nao deveria alterar o metadata' }

    # Estados do registro, com precedencia metadataNotProvided -> environmentNameUnavailable -> noEntryForEnvironment -> available.
    $st1 = Get-GeneXusPostBuildEventRegistryState -MetadataPath '' -EnvironmentName ''
    if ($st1.state -ne 'metadataNotProvided') { throw "ASSERT_FAILED: estado deveria ser metadataNotProvided; atual=$($st1.state)" }
    $st2 = Get-GeneXusPostBuildEventRegistryState -MetadataPath $metadataPath -EnvironmentName ''
    if ($st2.state -ne 'environmentNameUnavailable') { throw "ASSERT_FAILED: estado deveria ser environmentNameUnavailable; atual=$($st2.state)" }
    $st3 = Get-GeneXusPostBuildEventRegistryState -MetadataPath $metadataPath -EnvironmentName 'AmbienteInexistente'
    if ($st3.state -ne 'noEntryForEnvironment' -or @($st3.hashes).Count -ne 0) { throw "ASSERT_FAILED: environment sem entrada deveria ser noEntryForEnvironment; atual=$($st3.state)" }
    $st3b = Get-GeneXusPostBuildEventRegistryState -MetadataPath (Join-Path $tempRoot 'inexistente.md') -EnvironmentName 'NETPostgreSQL'
    if ($st3b.state -ne 'noEntryForEnvironment') { throw "ASSERT_FAILED: arquivo ausente deveria ser noEntryForEnvironment; atual=$($st3b.state)" }
    $st4 = Get-GeneXusPostBuildEventRegistryState -MetadataPath $metadataPath -EnvironmentName 'netpostgresql'
    if ($st4.state -ne 'available' -or @($st4.hashes).Count -ne 1) { throw "ASSERT_FAILED: environment registrado deveria ser available com 1 hash; atual=$($st4.state)" }

    'GENEXUS_KB_POST_BUILD_EVENTS_REGISTRATION_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
