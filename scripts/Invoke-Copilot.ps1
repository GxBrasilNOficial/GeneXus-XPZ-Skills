#requires -Version 7.4
<#
.SYNOPSIS
    Chama o GitHub Copilot CLI (sincrono) e devolve a resposta final em texto.
.DESCRIPTION
    Backend copilot da skill xpz-llm-delegate. Usa `copilot -p` em modo JSONL, com
    instrucoes customizadas desabilitadas, MCP embutido desabilitado e conjunto de
    ferramentas vazio. `--allow-all-tools` permanece porque o Copilot CLI exige permissao
    automatica em modo nao interativo, mas sem ferramentas disponiveis nao ha o que aprovar.

    CONFIDENCIALIDADE: este script NAO decide se o payload pode ir ao GitHub Copilot.
    Antes de enviar payload sensivel, passe por Resolve-LlmDelegateAuthorization.ps1
    -Backend copilot.
.PARAMETER Message
    Prompt a enviar ao Copilot. Exclusivo com -MessagePath.
.PARAMETER MessagePath
    Caminho de um arquivo de onde ler o prompt (UTF-8). Exclusivo com -Message. Evita
    substituicao de comando ("(Get-Content ...)") na linha de comando do chamador. ATENCAO:
    este adapter e argument-based (o prompt vai no argv via runner), entao -MessagePath NAO
    levanta o teto ~32KB do command line do Windows; um guard fail-closed (~30000 chars) recusa
    prompts grandes. So os adapters stdin-based (Codex/Claude Code/opencode) sao imunes ao teto.
.PARAMETER Model
    Modelo aceito pelo Copilot CLI. Default: auto (o proprio Copilot escolhe). Nao fixar um
    nome concreto: o catalogo do Copilot muda entre versoes do CLI e um id aposentado faz o
    CLI recusar a chamada. Medido em 2026-08-06 (Copilot CLI 1.0.78): o antigo default
    'gpt-5-mini' passou a responder «Model "gpt-5-mini" from --model flag is not available»,
    enquanto 'auto' respondeu normalmente. 'auto' e documentado no proprio --help do CLI.
.PARAMETER Cd
    Diretorio de trabalho do processo Copilot. Default: diretorio atual do chamador.
.PARAMETER CopilotExe
    Forca caminho do comando copilot.
.PARAMETER TimeoutSec
    Tempo maximo de espera.
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Inline')] [string] $Message,
    [Parameter(Mandatory, ParameterSetName = 'FromFile')] [string] $MessagePath,
    [string] $Model = 'auto',
    [string] $Cd,
    [string] $CopilotExe,
    [int] $TimeoutSec = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

. (Join-Path $PSScriptRoot 'CopilotCliSupport.ps1')

# Prompt: inline (-Message) ou de arquivo (-MessagePath, UTF-8). Le ANTES do guard de tamanho.
if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
    if (-not (Test-Path -LiteralPath $MessagePath -PathType Leaf)) {
        throw "BLOCK: -MessagePath nao encontrado: $MessagePath"
    }
    $Message = Get-Content -LiteralPath $MessagePath -Raw -Encoding utf8
}

# Guard de tamanho fail-closed (cobre -Message E -MessagePath). Este adapter e argument-based:
# o prompt vai no argv do runner, entao acima da margem o command line do Windows estoura. O
# limite e HEURISTICO em chars (UTF-16 code units), nao em bytes: margem conservadora sob o teto
# ~32767 do command line, reservando espaco para as demais flags. -MessagePath NAO levanta o teto.
$MaxArgvPromptChars = 30000
if ($Message.Length -gt $MaxArgvPromptChars) {
    throw "BLOCK: prompt com $($Message.Length) caracteres excede a margem de $MaxArgvPromptChars para o adapter argument-based Copilot (o prompt vai no argv; teto ~32767 do command line do Windows). Use prompt menor ou um backend stdin-based (Codex/Claude Code/opencode). Migracao do Copilot a stdin: follow-up em 999-ideias-pendentes.md."
}

$exe = Resolve-CopilotExe -Override $CopilotExe
$workDir = if ($Cd) { (Resolve-Path -LiteralPath $Cd).Path } else { (Get-Location).Path }

$out = New-TemporaryFile
$err = New-TemporaryFile
$req = New-TemporaryFile
$runner = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, '.ps1')
$request = [ordered]@{
    exe = $exe
    prompt = $Message
    model = $Model
    stdoutPath = $out.FullName
    stderrPath = $err.FullName
}
$request | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $req.FullName -Encoding utf8
@'
param([Parameter(Mandatory)][string]$RequestPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
$cpArgs = @(
    '-p', [string]$req.prompt,
    '--model', [string]$req.model,
    '--no-custom-instructions',
    '--disable-builtin-mcps',
    '--stream', 'off',
    '--output-format', 'json',
    '--available-tools=',
    '--allow-all-tools'
)
# stdin fechado ($null = EOF puro, sem bytes) para o copilot nao travar lendo o stdin
# herdado de uma shell headless sem TTY. Depende deste runner ser 'pwsh -File' (nao -Command).
$null | & ([string]$req.exe) @cpArgs 1> ([string]$req.stdoutPath) 2> ([string]$req.stderrPath)
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding utf8

try {
    $p = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $runner, '-RequestPath', $req.FullName) `
        -WorkingDirectory $workDir -NoNewWindow -PassThru
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        throw "BLOCK: Copilot CLI excedeu ${TimeoutSec}s e foi encerrado."
    }

    $stdoutText = Get-Content -LiteralPath $out.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $stderrText = Get-Content -LiteralPath $err.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($stdoutText)) { $lines = @($stdoutText -split "`r?`n") }
    $final = Get-CopilotJsonlFinalText -Lines $lines
    $reportedExitCode = Get-CopilotJsonlExitCode -Lines $lines

    if ($p.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($final)) {
        return $final.TrimEnd("`r", "`n")
    }

    $errMsg = Get-CopilotErrorMessage -StdoutText $stdoutText -StderrText $stderrText
    if ($errMsg) { throw "BLOCK: Copilot CLI retornou erro: $errMsg" }
    if ($null -ne $reportedExitCode -and $reportedExitCode -ne 0) {
        throw "BLOCK: Copilot CLI reportou exitCode $reportedExitCode sem resposta final."
    }
    if ($p.ExitCode -ne 0) {
        throw "BLOCK: Copilot CLI saiu com codigo $($p.ExitCode) sem resposta.`nstderr:`n$stderrText"
    }
    throw 'BLOCK: Copilot CLI nao produziu resposta final.'
}
finally {
    Remove-Item -LiteralPath $out.FullName, $err.FullName, $req.FullName, $runner -Force -ErrorAction SilentlyContinue
}
