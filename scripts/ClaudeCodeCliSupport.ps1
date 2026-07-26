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
    # sao removidos antes de qualquer decisao. Ver historico/IdeiasImplementadas_202607.md,
    # «Capturar a recusa real de workspace nao confiavel do Claude Code».
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

Quando ha limite de turnos, a primeira chamada de ferramenta pode consumir o unico turno e nao sobrar turno para responder. Os adapters deste repositorio NAO passam mais --max-turns (a CLI 2.1.215 removeu a flag do --help), entao um limite ativo vem da propria CLI ou de configuracao externa: investigue de onde. Alternativa imediata: rodar sem ferramentas quando a consulta nao precisar ler o workspace. Isto NAO e problema de confianca de workspace nem indisponibilidade do modelo.

--- EVIDENCIA (stdout + stderr, sem ruido de ambiente) ---
$evidence
--- FIM EVIDENCIA ---
"@.Trim()
}

function Test-ClaudeCodeMaxTurnsExhausted {
    param([AllowNull()] [string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    # `Reached max turns` e o texto do modo --output-format text; `error_max_turns` e o subtype do
    # evento final do stream-json (medido em 2026-07-25, claude 2.1.220).
    return ($Text -match '(?i)(reached\s+max\s+turns|\berror_max_turns\b)')
}

<#
.SYNOPSIS
    Extrai o texto de erro de um evento do stream JSONL (`--output-format stream-json`).
.DESCRIPTION
    O desfecho do stream nao vem em um evento `type=error`: medido em 2026-07-25 (claude 2.1.220),
    a ultima linha e `type=result` com `subtype` (`success`, `error_max_turns`, ...) e `is_error`.
    Observar apenas `type=error` deixava o esgotamento de turno e a falha de execucao invisiveis
    para o caminho assincrono. Devolve string vazia quando o evento nao carrega falha.

    A mensagem legivel NAO esta garantida em `result`: no evento de esgotamento de turno medido
    (`subtype=error_max_turns`) o campo `result` nem existe, e o texto vive em `errors[]`
    («Reached maximum number of turns (1)»), com `terminal_reason=max_turns` ao lado. Por isso a
    extracao le os quatro campos: sem `errors[]` a evidencia preservada era so o subtype.
#>
function Get-ClaudeCodeStreamEventErrorText {
    param([AllowNull()] $StreamEvent)

    if ($null -eq $StreamEvent) { return '' }
    $props = $StreamEvent.PSObject.Properties

    $type = ''
    if ($props['type']) { $type = [string]$props['type'].Value }

    if ($type -eq 'error') { return ($StreamEvent | ConvertTo-Json -Compress -Depth 10) }
    if ($type -ne 'result') { return '' }

    $isError = $false
    if ($props['is_error']) { $isError = [bool]$props['is_error'].Value }
    if (-not $isError) { return '' }

    $subtype = ''
    if ($props['subtype']) { $subtype = [string]$props['subtype'].Value }
    $terminalReason = ''
    if ($props['terminal_reason']) { $terminalReason = [string]$props['terminal_reason'].Value }
    $resultText = ''
    if ($props['result']) { $resultText = [string]$props['result'].Value }
    $errorsText = ''
    if ($props['errors']) {
        $errorsText = ((@($props['errors'].Value) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() }) -join ' | ')
    }

    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($subtype)) { $parts += "subtype=$subtype" }
    if (-not [string]::IsNullOrWhiteSpace($terminalReason)) { $parts += "terminal_reason=$terminalReason" }
    if (-not [string]::IsNullOrWhiteSpace($resultText)) { $parts += $resultText.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($errorsText)) { $parts += $errorsText }
    if ($parts.Count -eq 0) { return ($StreamEvent | ConvertTo-Json -Compress -Depth 10) }
    return ($parts -join ': ')
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

# O erro do stream passa pelos mesmos detectores do caminho sincrono: sem isto, o job assincrono
# devolvia texto cru e nunca emitia os codigos canonicos que a doc promete.
function Resolve-ClaudeCodeStreamErrorClassification {
    param([AllowNull()] [string] $StreamError)

    if (Test-ClaudeCodeMaxTurnsExhausted -Text $StreamError) {
        return [pscustomobject]@{
            status = 'error'
            error  = (New-ClaudeCodeMaxTurnsExhaustedEvidenceMessage -EvidenceText $StreamError)
        }
    }
    if (Test-ClaudeCodeWorkspaceNotTrusted -Text $StreamError) {
        return [pscustomobject]@{
            status = 'unavailable'
            error  = (New-ClaudeCodeWorkspaceNotTrustedEvidenceMessage -StderrText $StreamError)
        }
    }
    return [pscustomobject]@{ status = 'error'; error = $StreamError }
}

<#
.SYNOPSIS
    Classifica o desfecho de um job assincrono do Claude Code.
.DESCRIPTION
    Resposta final manda: texto produzido continua `completed`. Mas o esgotamento de turno PODE
    chegar depois de ja haver texto — medido em 2026-07-25 nos dois modos: um ensaio cortou com o
    turno gasto so em `tool_use` (sem texto), outro com o assistente ja tendo emitido uma frase
    antes da ferramenta. No segundo caso, descartar o erro mascararia resposta truncada como
    resposta boa; no primeiro, `FinalText` fica vazio e o desfecho e `error` normal. O erro
    observado depois do texto vai em `failureAfterText`, sem mudar `status`/`error`: quem decide se
    um parecer truncado vale e o orquestrador do painel, na reclassificacao pos-hoc do `15`.
    Todos os retornos tem o mesmo shape (`status`, `error`, `failureAfterText`).
#>
function Resolve-ClaudeCodeJobStatus {
    param([string]$FinalText, [string]$StreamError, [string]$Stderr)
    if (-not [string]::IsNullOrWhiteSpace($FinalText)) {
        $failureAfterText = $null
        if (-not [string]::IsNullOrWhiteSpace($StreamError)) {
            $failureAfterText = (Resolve-ClaudeCodeStreamErrorClassification -StreamError $StreamError).error
        }
        return [pscustomobject]@{ status = 'completed'; error = $null; failureAfterText = $failureAfterText }
    }
    if (-not [string]::IsNullOrWhiteSpace($StreamError)) {
        $classified = Resolve-ClaudeCodeStreamErrorClassification -StreamError $StreamError
        return [pscustomobject]@{ status = $classified.status; error = $classified.error; failureAfterText = $null }
    }
    $errMsg = Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText $Stderr
    if ($errMsg) {
        if ($errMsg -match '(?i)\bworkspace-not-trusted\b') {
            return [pscustomobject]@{ status = 'unavailable'; error = $errMsg; failureAfterText = $null }
        }
        return [pscustomobject]@{ status = 'error'; error = $errMsg; failureAfterText = $null }
    }
    return [pscustomobject]@{
        status           = 'sem-texto'
        error            = 'Claude Code encerrou sem resposta final.'
        failureAfterText = $null
    }
}
