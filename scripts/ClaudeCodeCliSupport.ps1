#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend claude-code da skill xpz-llm-delegate.
.DESCRIPTION
    Resolve o claude.exe, valida o contrato minimo de flags usado pelos adapters e extrai
    mensagens de erro de saidas do Claude Code. Sem rede por conta propria, exceto quando
    Resolve-ClaudeCodeExe precisa chamar `claude --version` / `claude --help` no candidato.
#>

Set-StrictMode -Version Latest

function ConvertFrom-ClaudeCodeVersionText {
    param([string]$Text)
    $m = [regex]::Match([string]$Text, '(\d+)\.(\d+)\.(\d+)')
    if (-not $m.Success) { return $null }
    return [version]::new([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
}

function Get-ClaudeCodeErrorMessage {
    param([string]$StdoutText, [string]$StderrText)
    $combined = @($StderrText, $StdoutText) -join "`n"
    if ([string]::IsNullOrWhiteSpace($combined)) { return $null }

    if (Test-ClaudeCodeWorkspaceNotTrusted -Text $StderrText) {
        return 'Claude Code workspace-not-trusted: este workspace ainda nao foi marcado como confiavel no ambiente do Claude Code. Abra o workspace no Claude Code e confirme a confianca, ou use outro backend/fallback.'
    }

    $lines = @($combined -split "`r?`n")
    $interesting = @($lines | Where-Object {
        $_ -match '(?i)\b(error|failed|unauthorized|forbidden|not\s+available|requires|login|auth)\b'
    })
    if ($interesting.Count -gt 0) {
        return (($interesting | Select-Object -First 8) -join "`n").Trim()
    }
    return $null
}

function Test-ClaudeCodeWorkspaceNotTrusted {
    param([AllowNull()] [string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return (
        $Text -match '(?i)workspace.{0,80}\b(not|nao|não)\b.{0,80}(trusted|confiavel|confiável)' -or
        $Text -match '(?i)\b(not|nao|não)\b.{0,80}(trusted|confiavel|confiável).{0,80}workspace' -or
        $Text -match '(?i)mark(ed)? this workspace as trusted' -or
        $Text -match '(?i)marc(ar|ado).{0,80}workspace.{0,80}confi'
    )
}

function Test-ClaudeCodeHelpSupportsContract {
    param([string]$HelpText)
    $required = @(
        '--model',
        '--print',
        '--output-format',
        '--no-session-persistence',
        '--permission-mode',
        '--tools'
    )
    foreach ($flag in $required) {
        if ($HelpText -notmatch [regex]::Escape($flag)) { return $false }
    }
    return $true
}

function Resolve-ClaudeCodeExe {
    param(
        [string]$Override,
        [version]$MinimumVersion = ([version]'2.1.118'),
        [switch]$SkipContractCheck
    )

    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            throw "BLOCK: claude.exe informado em -ClaudeExe nao existe: $Override"
        }
        $exe = (Resolve-Path -LiteralPath $Override).Path
    } else {
        $cmd = Get-Command claude -ErrorAction SilentlyContinue
        if (-not $cmd -or -not $cmd.Source) {
            throw 'BLOCK: claude.exe nao encontrado no PATH. Instale/autentique o Claude Code ou passe -ClaudeExe.'
        }
        $exe = $cmd.Source
    }

    $versionText = ''
    try { $versionText = (& $exe --version 2>&1 | Out-String).Trim() } catch { $versionText = '' }
    $version = ConvertFrom-ClaudeCodeVersionText $versionText
    if ($null -eq $version) {
        throw "BLOCK: nao foi possivel ler a versao do Claude Code em $exe. Saida: $versionText"
    }
    if ($version -lt $MinimumVersion) {
        throw "BLOCK: Claude Code $version e anterior ao minimo validado $MinimumVersion para este adapter."
    }

    if (-not $SkipContractCheck) {
        $helpText = ''
        try { $helpText = (& $exe --help 2>&1 | Out-String) } catch { $helpText = '' }
        if (-not (Test-ClaudeCodeHelpSupportsContract -HelpText $helpText)) {
            throw 'BLOCK: Claude Code encontrado, mas nao expoe as flags exigidas pelo adapter (--model, -p, --output-format, --no-session-persistence, --permission-mode, --tools).'
        }
    }

    return $exe
}

function Resolve-ClaudeCodeJobStatus {
    param([string]$FinalText, [string]$StreamError, [string]$Stderr)
    if (-not [string]::IsNullOrWhiteSpace($FinalText)) {
        return [pscustomobject]@{ status = 'completed'; error = $null }
    }
    if (-not [string]::IsNullOrWhiteSpace($StreamError)) {
        return [pscustomobject]@{ status = 'error'; error = $StreamError }
    }
    $errMsg = Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText $Stderr
    if ($errMsg) {
        if (Test-ClaudeCodeWorkspaceNotTrusted -Text $errMsg) {
            return [pscustomobject]@{ status = 'unavailable'; error = $errMsg }
        }
        return [pscustomobject]@{ status = 'error'; error = $errMsg }
    }
    return [pscustomobject]@{ status = 'sem-texto'; error = 'Claude Code encerrou sem resposta final.' }
}
