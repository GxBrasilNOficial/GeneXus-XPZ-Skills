#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend antigravity da skill xpz-llm-delegate.
.DESCRIPTION
    Resolve o executavel agy.exe, valida o contrato minimo de flags usado pelo adapter e extrai
    mensagens de erro da saida do Antigravity CLI.
#>

Set-StrictMode -Version Latest

$quotaFailurePattern = '(?i)\b(quota|rate\s*limit|exhausted|too\s*many\s*requests|429|resource_exhausted)\b'

function Test-AntigravityHelpSupportsContract {
    param([string]$HelpText)
    if ([string]::IsNullOrWhiteSpace($HelpText)) { return $false }
    $hasPrint = $HelpText -match '(?i)--print|-p|--prompt'
    $hasMode = $HelpText -match '(?i)--mode'
    return ($hasPrint -and $hasMode)
}

function Resolve-AntigravityExe {
    param(
        [string]$Override,
        [switch]$SkipContractCheck
    )

    $exe = $null
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            throw "BLOCK: agy informado em -AntigravityExe nao existe: $Override"
        }
        $exe = (Resolve-Path -LiteralPath $Override).Path
    } else {
        $cmd = Get-Command agy -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            $exe = $cmd.Source
        } else {
            $defaultPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'agy\bin\agy.exe'
            if (Test-Path -LiteralPath $defaultPath -PathType Leaf) {
                $exe = (Resolve-Path -LiteralPath $defaultPath).Path
            }
        }
    }

    if (-not $exe) {
        throw 'BLOCK: Antigravity CLI (agy) nao encontrado no PATH nem em %LOCALAPPDATA%\agy\bin\agy.exe. Instale o agy ou passe -AntigravityExe.'
    }

    if (-not $SkipContractCheck) {
        $helpText = ''
        try { $helpText = (& $exe --help 2>&1 | Out-String) } catch { $helpText = '' }
        if (-not (Test-AntigravityHelpSupportsContract -HelpText $helpText)) {
            throw "BLOCK: Antigravity CLI em '$exe' nao expoe as flags exigidas (--print/--prompt e --mode)."
        }
    }

    return $exe
}

function Get-AntigravityErrorMessage {
    param([string]$StdoutText, [string]$StderrText)
    $combined = @($StderrText, $StdoutText) -join "`n"
    if ([string]::IsNullOrWhiteSpace($combined)) { return $null }
    $lines = @($combined -split "`r?`n")
    $interesting = @($lines | Where-Object {
        $_ -match '(?i)\b(error|failed|unauthorized|forbidden|not\s+available|requires|login|auth|invalid|quota|rate\s*limit)\b'
    })
    if ($interesting.Count -gt 0) {
        return (($interesting | Select-Object -First 8) -join "`n").Trim()
    }
    return $null
}
