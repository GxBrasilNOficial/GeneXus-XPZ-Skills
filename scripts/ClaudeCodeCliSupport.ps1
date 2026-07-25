#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend claude-code da skill xpz-llm-delegate.
.DESCRIPTION
    Resolve o claude.exe, valida o contrato minimo de flags usado pelos adapters e extrai
    mensagens de erro de saidas do Claude Code. Antes de classificar, descarta avisos de
    ambiente que o Claude Code emite em stderr mesmo quando a chamada da certo. Sem rede por
    conta propria, exceto quando Resolve-ClaudeCodeExe precisa chamar `claude --version` /
    `claude --help` no candidato.
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

    # O Claude Code emite em stderr avisos de ambiente que aparecem INCLUSIVE quando a chamada
    # termina com exit 0 e resposta valida (medido em 2026-07-25: mesmo stderr, byte a byte, em
    # execucao bem-sucedida e em execucao falha). Por isso eles nao podem classificar falha:
    # sao removidos antes de qualquer decisao. Ver 999-ideias-pendentes.md
    # «Revisor Claude Code falha por MaxTurns=1 assim que usa uma ferramenta».
    $cleanStderr = Remove-ClaudeCodeEnvironmentNoise -Text $StderrText
    $combined = @($cleanStderr, $StdoutText) -join "`n"
    if ([string]::IsNullOrWhiteSpace($combined)) { return $null }

    # Falha real observada empiricamente; precede o detector heuristico de confianca.
    if (Test-ClaudeCodeMaxTurnsExhausted -Text $combined) {
        return New-ClaudeCodeMaxTurnsExhaustedEvidenceMessage -EvidenceText $combined
    }

    if (Test-ClaudeCodeWorkspaceNotTrusted -Text $StderrText) {
        return New-ClaudeCodeWorkspaceNotTrustedEvidenceMessage -StderrText $StderrText
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

function New-ClaudeCodeWorkspaceNotTrustedEvidenceMessage {
    param([AllowNull()] [string] $StderrText)

    $rawStderr = ([string]$StderrText).Trim()
    return @"
Claude Code workspace-not-trusted: este workspace ainda nao foi marcado como confiavel no ambiente do Claude Code.

Para melhorar a compatibilidade da skill, informe ao usuario que nao marque a confianca automaticamente. Peça que ele envie ao mantenedor: (1) o stderr bruto abaixo, após remover qualquer segredo; (2) a saida de `claude --version`; e (3) se a recusa ocorreu no Claude Code Desktop ou na CLI.

--- STDERR BRUTO DO CLAUDE CODE ---
$rawStderr
--- FIM STDERR BRUTO DO CLAUDE CODE ---
"@.Trim()
}

function New-ClaudeCodeMaxTurnsExhaustedEvidenceMessage {
    param([AllowNull()] [string] $EvidenceText)

    $evidence = ([string]$EvidenceText).Trim()
    return @"
Claude Code max-turns-exhausted: a chamada gastou todos os turnos agenticos antes de produzir resposta.

Causa tipica: com --max-turns 1, a primeira chamada de ferramenta consome o unico turno e nao sobra turno para responder. Correcao: aumentar -MaxTurns, ou rodar sem ferramentas quando a consulta nao precisar ler o workspace. Isto NAO e problema de confianca de workspace nem indisponibilidade do modelo.

--- EVIDENCIA (stdout + stderr, sem ruido de ambiente) ---
$evidence
--- FIM EVIDENCIA ---
"@.Trim()
}

function Test-ClaudeCodeMaxTurnsExhausted {
    param([AllowNull()] [string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return ($Text -match '(?i)reached\s+max\s+turns')
}

# Avisos de ambiente do Claude Code: aparecem em stderr independentemente do desfecho da chamada
# (inclusive em exit 0 com resposta valida), portanto nao sao evidencia de falha.
function Test-ClaudeCodeEnvironmentNoiseLine {
    param([AllowNull()] [string] $Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $false }
    return (
        $Line -match '(?i)^\s*ignoring\s+\d+\s+permissions\.allow\s+entries\b' -or
        $Line -match '(?i)^\s*permission\s+allow\s+rule\s*\('
    )
}

function Remove-ClaudeCodeEnvironmentNoise {
    param([AllowNull()] [string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $kept = @(@([string]$Text -split "`r?`n") | Where-Object { -not (Test-ClaudeCodeEnvironmentNoiseLine -Line $_) })
    return (($kept -join "`n").Trim())
}

function Test-ClaudeCodeWorkspaceNotTrusted {
    param([AllowNull()] [string] $Text)
    # Detecta apenas RECUSA de execucao. O aviso "this workspace has not been trusted" que
    # acompanha o descarte de regras allow e ruido de ambiente e nao pode disparar este detector.
    $Text = Remove-ClaudeCodeEnvironmentNoise -Text $Text
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
        if ($errMsg -match '(?i)\bworkspace-not-trusted\b') {
            return [pscustomobject]@{ status = 'unavailable'; error = $errMsg }
        }
        return [pscustomobject]@{ status = 'error'; error = $errMsg }
    }
    return [pscustomobject]@{ status = 'sem-texto'; error = 'Claude Code encerrou sem resposta final.' }
}
