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
# declara para o modelo <provider>/<modelo>. Le `opencode api model.list`, cujo formato e:
# {"location":{...},"data":[{"id":"...","providerID":"...","variants":[{"id":"..."},...]},...]}
# A chave do modelo e providerID + "/" + id (comparacao exata case-sensitive). Variantes sao
# comparadas case-insensitively; o nome canonico retornado e o `id` como declarado no catalogo.
# Modelo sem variantes -> ok=$true, variants vazio. Falha de leitura/parse/modelo-ausente -> ok=$false
# (o chamador nao aplica o esforco e registra o motivo).
function Get-OpenCodeModelVariantNames {
    param(
        [Parameter(Mandatory)] [string] $ExePath,
        [Parameter(Mandatory)] [string] $Model
    )
    $key = $Model.Trim()
    if ($key -notmatch '/') {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "modelo sem provider: '$key'" }
    }
    $parts = @($key -split '/', 2)
    $providerID = $parts[0]
    $modelId = $parts[1]
    if ([string]::IsNullOrWhiteSpace($providerID) -or [string]::IsNullOrWhiteSpace($modelId)) {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "modelo com provider ou id vazio: '$key'" }
    }
    try {
        $raw = @(& $ExePath api model.list 2>$null)
    } catch {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "opencode api model.list falhou: $($_.Exception.Message)" }
    }
    try {
        $parsed = ($raw -join "`n") | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "JSON de 'opencode api model.list' invalido" }
    }
    if ($null -eq $parsed -or $null -eq $parsed.PSObject.Properties['data']) {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "resposta de 'opencode api model.list' sem campo 'data'" }
    }
    $modelObj = $null
    foreach ($m in @($parsed.data)) {
        if ([string]$m.providerID -ceq $providerID -and [string]$m.id -ceq $modelId) {
            $modelObj = $m; break
        }
    }
    if ($null -eq $modelObj) {
        return [pscustomobject]@{ ok = $false; variants = @(); reason = "modelo '$key' ausente do catalogo do opencode" }
    }
    $names = @()
    if ($null -ne $modelObj.PSObject.Properties['variants'] -and $null -ne $modelObj.variants) {
        $names = @($modelObj.variants | ForEach-Object { [string]$_.id })
    }
    return [pscustomobject]@{ ok = $true; variants = $names; reason = $null }
}

# Retorna o modelo padrao do opencode no formato "providerID/id" consultando `opencode api model.default`.
# Devolve $null se o comando falhar ou a resposta for invalida.
function Get-OpenCodeDefaultModelId {
    param([Parameter(Mandatory)] [string] $ExePath)
    try {
        $raw = @(& $ExePath api model.default 2>$null)
    } catch {
        return $null
    }
    try {
        $parsed = ($raw -join "`n") | ConvertFrom-Json
    } catch {
        return $null
    }
    if ($null -eq $parsed -or $null -eq $parsed.PSObject.Properties['data']) { return $null }
    $d = $parsed.data
    if ($null -eq $d) { return $null }
    $pid2 = if ($d.PSObject.Properties['providerID']) { [string]$d.providerID } else { $null }
    $mid2 = if ($d.PSObject.Properties['id']) { [string]$d.id } else { $null }
    if ([string]::IsNullOrWhiteSpace($pid2) -or [string]::IsNullOrWhiteSpace($mid2)) { return $null }
    return "$pid2/$mid2"
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
