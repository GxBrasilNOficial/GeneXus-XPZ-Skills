#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas para descobrir e validar o opencode CLI.
.DESCRIPTION
    Usado pelos adapters opencode da skill xpz-llm-delegate. A descoberta nao presume
    instalacao via npm: aceita override explicito, PATH (WinGet/Scoop/binario direto) e,
    por retrocompatibilidade, a instalacao npm em %APPDATA%\npm.
#>

Set-StrictMode -Version Latest

function Get-OpenCodeExeVersion {
    param([Parameter(Mandatory)] [string] $ExePath)
    try {
        $raw = & $ExePath --version 2>$null
        $line = ([string](@($raw) | Select-Object -First 1)).Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return $null }
        return $line
    } catch {
        return $null
    }
}

function Resolve-OpenCodeExe {
    param([string] $Override)

    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            throw "BLOCK: -OpenCodeExe informado nao existe: $Override"
        }
        $version = Get-OpenCodeExeVersion -ExePath $Override
        if ([string]::IsNullOrWhiteSpace($version)) {
            throw "BLOCK: -OpenCodeExe nao respondeu a 'opencode --version': $Override"
        }
        return $Override
    }

    $candidates = [System.Collections.Generic.List[string]]::new()

    try {
        $cmds = @(Get-Command opencode -All -ErrorAction SilentlyContinue)
        foreach ($cmd in $cmds) {
            if ($cmd.Source -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)) {
                if (-not $candidates.Contains($cmd.Source)) { $candidates.Add($cmd.Source) }
            }
        }
    } catch { }

    $npmRoot = Join-Path $env:APPDATA 'npm\node_modules\opencode-ai'
    if (Test-Path -LiteralPath $npmRoot -PathType Container) {
        $npmCandidates = @(Get-ChildItem -LiteralPath $npmRoot -Recurse -Filter 'opencode.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*windows-x64\bin\opencode.exe' } |
            Select-Object -ExpandProperty FullName)
        foreach ($c in $npmCandidates) {
            if (-not $candidates.Contains($c)) { $candidates.Add($c) }
        }
    }

    foreach ($c in $candidates) {
        $version = Get-OpenCodeExeVersion -ExePath $c
        if (-not [string]::IsNullOrWhiteSpace($version)) { return $c }
    }

    $searched = @('PATH via Get-Command opencode', $npmRoot) -join '; '
    throw "BLOCK: opencode.exe nao encontrado ou nao funcional. Locais verificados: $searched. Instale o opencode CLI ou informe -OpenCodeExe <caminho>."
}
