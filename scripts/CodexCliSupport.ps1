#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend codex da skill xpz-llm-delegate: descoberta do
    binario do Codex CLI compativel.
.DESCRIPTION
    Modulo dot-source consumido por Invoke-Codex.ps1 e Start-CodexJob.ps1. Sem efeitos
    colaterais alem de invocar `codex --version` nos candidatos.

    DESCOBERTA (fail-closed): o shim npm no PATH (Roaming\npm) pode estar antigo e e
    rejeitado pelo servidor para modelos novos. Por isso a descoberta ignora o PATH e usa
    os binarios da app desktop OpenAI Codex sob %LOCALAPPDATA%\OpenAI\Codex\bin.
    O executavel canonico bin\codex.exe prevalece quando responde a --version. Diretorios
    backup-* nunca participam. Somente quando o canonico estiver ausente ou invalido a
    descoberta recorre aos subdiretorios nao-backup e escolhe a maior versao utilizavel.
    Sem candidato utilizavel -> BLOCK com instrucao.

    Contrato validado por Test-CodexCliSupportSelfTest.ps1.
#>

Set-StrictMode -Version Latest

function Get-CodexExeVersion {
    # Le 'codex-cli X.Y.Z[-alpha.N]' e devolve [version] X.Y.Z (ignora sufixo pre-release).
    param([string]$ExePath)
    try {
        $raw = & $ExePath --version 2>$null
        $line = @($raw)[0]
        $m = [regex]::Match([string]$line, '(\d+)\.(\d+)\.(\d+)')
        if ($m.Success) {
            return [version]("{0}.{1}.{2}" -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value)
        }
    } catch { }
    return $null
}

function Get-CodexExeCandidatePaths {
    param([Parameter(Mandatory)] [string] $BasePath)

    $paths = [System.Collections.Generic.List[string]]::new()
    $canonical = Join-Path $BasePath 'codex.exe'
    if (Test-Path -LiteralPath $canonical -PathType Leaf) {
        $paths.Add($canonical)
    }

    $fallbackDirs = @(Get-ChildItem -LiteralPath $BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Name.StartsWith('backup-', [System.StringComparison]::OrdinalIgnoreCase) })
    foreach ($dir in $fallbackDirs) {
        $nested = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -Filter 'codex.exe' -File -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName)
        foreach ($candidate in $nested) {
            $paths.Add([string]$candidate)
        }
    }

    return @($paths)
}

function Resolve-CodexExe {
    # Devolve o caminho do codex.exe a usar. -Override forca um caminho explicito.
    # -BasePath e seam deterministico de self-test; adapters usam o default da app.
    param(
        [string] $Override,
        [string] $BasePath
    )

    if ($Override) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) { return $Override }
        throw "BLOCK: -CodexExe informado nao existe: $Override"
    }

    $base = if ($BasePath) { $BasePath } else { Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin' }
    if (-not (Test-Path -LiteralPath $base -PathType Container)) {
        throw "BLOCK: pasta de binarios da app OpenAI Codex nao encontrada: $base. Instale/atualize a app ou o CLI do Codex (o shim npm e rejeitado para gpt-5.5)."
    }

    $candidates = @(Get-CodexExeCandidatePaths -BasePath $base)
    if ($candidates.Count -eq 0) {
        throw "BLOCK: nenhum codex.exe encontrado sob $base. Atualize a app/CLI do Codex."
    }

    $canonical = Join-Path $base 'codex.exe'
    if ($candidates -contains $canonical) {
        $canonicalVersion = Get-CodexExeVersion $canonical
        if ($null -ne $canonicalVersion) {
            return $canonical
        }
    }

    $best = $null; $bestVer = $null
    foreach ($c in $candidates) {
        if ([string]::Equals($c, $canonical, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $v = Get-CodexExeVersion $c
        if ($null -eq $v) { continue }
        if ($null -eq $bestVer -or $v -gt $bestVer) { $bestVer = $v; $best = $c }
    }
    if (-not $best) {
        throw "BLOCK: nenhum codex.exe utilizavel respondeu a --version sob $base. Atualize a app/CLI do Codex."
    }
    return $best
}

function Get-CodexExecErrorMessage {
    # Extrai mensagem de erro do stdout/stderr do `codex exec` quando o servidor rejeita o
    # pedido (ex: modelo nao suportado). Procura linhas 'ERROR: {json}' e devolve a 'message'.
    param([string]$StdoutText, [string]$StderrText)
    $combined = @($StdoutText, $StderrText) -join "`n"
    $jsonMatches = [regex]::Matches($combined, 'ERROR:\s*(\{.*\})')
    if ($jsonMatches.Count -gt 0) {
        $jsonText = $jsonMatches[$jsonMatches.Count - 1].Groups[1].Value
        try {
            $obj = $jsonText | ConvertFrom-Json
            $msg = $null
            if ($obj.PSObject.Properties['error'] -and $obj.error.PSObject.Properties['message']) {
                $msg = [string]$obj.error.message
            }
            if (-not [string]::IsNullOrWhiteSpace($msg)) { return $msg }
        } catch { }
        return $jsonText
    }
    # Fallback: linha 'ERROR: <texto>' sem JSON balanceado
    $lineMatch = [regex]::Match($combined, 'ERROR:\s*(\S.*)')
    if ($lineMatch.Success) { return $lineMatch.Groups[1].Value.Trim() }
    return $null
}

function Resolve-CodexJobStatus {
    # Decide o status final de um job do Codex (completed | error | sem-texto).
    # A resposta final (output-last-message) e a evidencia PRIMARIA de sucesso: havendo-a, o
    # status e 'completed' mesmo que o stderr contenha texto "ERROR: {...}" — no modo async o
    # stderr do `codex exec --json` carrega logs de comandos internos do agente (grep, leitura
    # de arquivos) que podem incluir essa string sem serem erro da sessao. So SEM resposta final
    # investiga-se erro: primeiro um erro estruturado do stream ($StreamError), depois o stderr.
    param([string]$FinalText, [string]$StreamError, [string]$Stderr)
    if (-not [string]::IsNullOrWhiteSpace($FinalText)) {
        return [pscustomobject]@{ status = 'completed'; error = $null }
    }
    $err = $StreamError
    if ([string]::IsNullOrWhiteSpace($err)) {
        $err = Get-CodexExecErrorMessage -StdoutText '' -StderrText $Stderr
    }
    if (-not [string]::IsNullOrWhiteSpace($err)) {
        return [pscustomobject]@{ status = 'error'; error = $err }
    }
    return [pscustomobject]@{ status = 'sem-texto'; error = $null }
}
