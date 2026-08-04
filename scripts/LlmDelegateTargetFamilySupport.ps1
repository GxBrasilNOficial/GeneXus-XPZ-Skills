#requires -Version 7.4
<#
.SYNOPSIS
    Resolve a familia de modelos (provider de destino) para avaliacao do piso de diversidade.
.DESCRIPTION
    Extrai a familia estrutural do targetModelKey. Modelos sob o servico Antigravity (antigravity/*)
    sao dinamica e conservadoramente resolvidos para a familia do modelo subjacente:
      - antigravity/claude-* -> anthropic
      - antigravity/gpt-*    -> openai
      - antigravity/gemini-* ou modelo padrao -> google
#>

function Get-LlmDelegateTargetFamily {
    [CmdletBinding()]
    param(
        [string]$TargetModelKey
    )
    Set-StrictMode -Version Latest
    if ([string]::IsNullOrWhiteSpace($TargetModelKey) -or $TargetModelKey -notmatch '/') { return $null }

    $parts = @($TargetModelKey -split '/', 2)
    $fam = $parts[0].Trim()
    $modelId = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

    if ($fam -ieq 'antigravity') {
        if ($modelId -ilike 'claude-*') { return 'anthropic' }
        if ($modelId -ilike 'gpt-*')    { return 'openai' }
        return 'google'
    }
    return $fam
}
