#requires -Version 7.4

<#
.SYNOPSIS
    Self-test mínimo para Test-XpzPackageCollision.ps1.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-XpzPackageCollision.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-package-collision-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

function Invoke-CollisionScript {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & pwsh -NoProfile -File $scriptPath @Arguments 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Json = (($output | Out-String) | ConvertFrom-Json)
    }
}

try {
    $frontPrefix = 'GtaP3_c34f_20260528'
    $free = Invoke-CollisionScript -Arguments @('-FrontPrefix', $frontPrefix, '-NN', '01', '-OutputDir', $tempRoot)
    if ($free.ExitCode -ne 0 -or $free.Json.status -ne 'ok' -or $free.Json.reason -ne 'COLLISION_OK') {
        throw "Rodada livre deveria retornar ok/exit 0; obtido status=$($free.Json.status) reason=$($free.Json.reason) exit=$($free.ExitCode)"
    }

    [System.IO.File]::WriteAllText((Join-Path $tempRoot "$frontPrefix`_01.import_file.xml"), '<ExportFile />')
    [System.IO.File]::WriteAllText((Join-Path $tempRoot "$frontPrefix`_02.import_file.xml"), '<ExportFile />')

    $collision = Invoke-CollisionScript -Arguments @('-FrontPrefix', $frontPrefix, '-NN', '01', '-OutputDir', $tempRoot)
    if ($collision.ExitCode -ne 20 -or $collision.Json.status -ne 'bloqueado' -or $collision.Json.reason -ne 'PACKAGE_ROUND_COLLISION') {
        throw "Colisao deveria retornar bloqueado/exit 20; obtido status=$($collision.Json.status) reason=$($collision.Json.reason) exit=$($collision.ExitCode)"
    }
    if ($collision.Json.nextFreeNN -ne '03' -or $collision.Json.nextFreeRound -ne 3) {
        throw "Colisao deveria sugerir proximo NN 03; obtido nextFreeNN=$($collision.Json.nextFreeNN) nextFreeRound=$($collision.Json.nextFreeRound)"
    }

    $pathAlias = Invoke-CollisionScript -Arguments @('-Path', (Join-Path $tempRoot "$frontPrefix`_03.import_file.xml"))
    if ($pathAlias.ExitCode -ne 0 -or $pathAlias.Json.status -ne 'ok' -or $pathAlias.Json.requestedNN -ne '03') {
        throw "Alias -Path deveria aceitar pacote livre _03; obtido status=$($pathAlias.Json.status) nn=$($pathAlias.Json.requestedNN) exit=$($pathAlias.ExitCode)"
    }

    Write-Output 'OK: Test-XpzPackageCollisionSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
