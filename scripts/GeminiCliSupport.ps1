#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend gemini da skill xpz-llm-delegate.
.DESCRIPTION
    Resolve o comando gemini, valida o contrato minimo de flags usado pelo adapter e extrai
    mensagens de erro da saida do Gemini CLI.
#>

Set-StrictMode -Version Latest

function ConvertFrom-GeminiVersionText {
    param([string]$Text)
    $m = [regex]::Match([string]$Text, '(\d+)\.(\d+)\.(\d+)')
    if (-not $m.Success) { return $null }
    return [version]::new([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
}

function Test-GeminiHelpSupportsContract {
    param([string]$HelpText)
    $required = @(
        '--prompt',
        '--approval-mode',
        '--output-format',
        '--model'
    )
    foreach ($flag in $required) {
        if ($HelpText -notmatch [regex]::Escape($flag)) { return $false }
    }
    return $true
}

function Resolve-GeminiExe {
    param(
        [string]$Override,
        [version]$MinimumVersion = ([version]'0.35.3'),
        [switch]$SkipContractCheck
    )

    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            throw "BLOCK: gemini informado em -GeminiExe nao existe: $Override"
        }
        $exe = (Resolve-Path -LiteralPath $Override).Path
    } else {
        $cmd = Get-Command gemini -ErrorAction SilentlyContinue
        if (-not $cmd -or -not $cmd.Source) {
            throw 'BLOCK: gemini CLI nao encontrado no PATH. Instale/autentique Gemini CLI ou passe -GeminiExe.'
        }
        $exe = $cmd.Source
    }

    $versionText = ''
    try { $versionText = (& $exe --version 2>&1 | Out-String).Trim() } catch { $versionText = '' }
    $version = ConvertFrom-GeminiVersionText $versionText
    if ($null -eq $version) {
        throw "BLOCK: nao foi possivel ler a versao do Gemini CLI em $exe. Saida: $versionText"
    }
    if ($version -lt $MinimumVersion) {
        throw "BLOCK: Gemini CLI $version e anterior ao minimo validado $MinimumVersion para este adapter."
    }

    if (-not $SkipContractCheck) {
        $helpText = ''
        try { $helpText = (& $exe --help 2>&1 | Out-String) } catch { $helpText = '' }
        if (-not (Test-GeminiHelpSupportsContract -HelpText $helpText)) {
            throw 'BLOCK: Gemini CLI encontrado, mas nao expoe as flags exigidas pelo adapter.'
        }
    }

    return $exe
}

function Get-GeminiErrorMessage {
    param([string]$StdoutText, [string]$StderrText)
    $combined = @($StderrText, $StdoutText) -join "`n"
    if ([string]::IsNullOrWhiteSpace($combined)) { return $null }
    $lines = @($combined -split "`r?`n")
    # `auth` estava so na forma isolada (\bauth\b) e NAO casava "authentication"/"authenticating" -
    # exatamente as palavras das duas falhas reais medidas em 2026-08-06: o prompt interativo
    # "Opening authentication page in your browser..." (stdout, exit 0) e o
    # "Error authenticating: IneligibleTierError..." (stderr, exit 1). Sem as formas flexionadas,
    # o extrator devolvia $null e o adapter perdia o motivo. `credential` fica FORA de proposito:
    # o CLI emite "Loaded cached credentials" como linha informativa em execucao normal, e
    # inclui-la traria ruido para dentro da mensagem de erro.
    $interesting = @($lines | Where-Object {
        $_ -match '(?i)\b(error|failed|unauthorized|forbidden|not\s+available|requires|login|sign\s*in|auth|authenticat\w*|authoriz\w*|invalid)\b'
    })
    if ($interesting.Count -gt 0) {
        return (($interesting | Select-Object -First 8) -join "`n").Trim()
    }
    return $null
}
