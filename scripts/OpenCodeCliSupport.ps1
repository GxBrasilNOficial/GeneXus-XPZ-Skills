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

# Variantes (nomes de esforco de raciocinio, ex.: low/medium/high/max) que o catalogo do opencode
# declara para o modelo <provider>/<modelo>. Le `opencode models <provider> --verbose`, cujo formato
# e: uma linha de cabecalho com a chave completa do modelo, seguida do objeto JSON do modelo. So o
# que o catalogo declara e aplicavel via --variant; modelo sem variantes -> ok=$true, variants vazio.
# Falha de leitura/parse -> ok=$false (o chamador nao aplica o esforco e registra o motivo).
function Get-OpenCodeModelVariantNames {
    param(
        [Parameter(Mandatory)] [string] $ExePath,
        [Parameter(Mandatory)] [string] $Model
    )
    $key = $Model.Trim()
    $provider = @($key -split '/', 2)[0]
    if ([string]::IsNullOrWhiteSpace($provider) -or $key -notmatch '/') {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "modelo sem provider: '$key'" }
    }
    try {
        $raw = @(& $ExePath models $provider --verbose 2>$null)
    } catch {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "opencode models falhou: $($_.Exception.Message)" }
    }
    $lines = @($raw | ForEach-Object { [string]$_ })
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim().Equals($key, [System.StringComparison]::OrdinalIgnoreCase)) { $start = $i + 1; break }
    }
    if ($start -lt 0) {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "modelo '$key' ausente do catalogo do opencode" }
    }
    $block = [System.Collections.Generic.List[string]]::new()
    for ($j = $start; $j -lt $lines.Count; $j++) {
        # proximo cabecalho: linha sem indentacao que nao abre nem fecha objeto JSON
        if ($block.Count -gt 0 -and $lines[$j] -match '^[^\s{}\[\]]\S*$') { break }
        $block.Add($lines[$j])
    }
    try {
        $obj = ($block -join "`n") | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "JSON do modelo '$key' ilegivel no catalogo" }
    }
    $names = @()
    if ($null -ne $obj -and $obj.PSObject.Properties['variants'] -and $null -ne $obj.variants) {
        $names = @($obj.variants.PSObject.Properties | ForEach-Object { $_.Name })
    }
    return [pscustomobject]@{ ok = $true; variants = $names; reason = $null }
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
