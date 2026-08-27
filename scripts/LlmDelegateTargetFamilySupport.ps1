#requires -Version 7.4
<#
.SYNOPSIS
    Resolve o Criador do Modelo (familia estrutural de fundacao) para avaliacao do piso de diversidade.
.DESCRIPTION
    Extrai o Criador do Modelo (familia estrutural) do targetModelKey.

    Modelos sob provedores agregadores colapsam no Criador do Modelo:
      - nvidia/<criador>/<modelo> (3 niveis) -> resolve o 2o segmento (<criador>) com normalizacao canonica
        (ex.: deepseek-ai -> deepseek, mistralai -> mistral, qwen -> alibaba, meta-llama/facebook -> meta,
        thudm/glm -> z-ai, minimax/minimaxai -> minimaxai, moonshotai -> moonshot; desconhecido -> 2o segmento as-is).
      - nvidia/<modelo> (2 niveis) -> nemotron-* -> nvidia, llama-* -> meta, fallback -> nvidia.
      - antigravity/* (2 niveis) -> antigravity/claude-* -> anthropic, antigravity/gpt-* -> openai,
        antigravity/gemini-* ou modelo padrao -> google.

    Para agregadores de 2 niveis sem criador no path (ex.: ollama-cloud/*, opencode-go/*), retorna o prefixo
    do provedor (limite conhecido documentado para preservacao dos semaforos de concorrencia do dispatcher).

    Chaves sem barra (ex: 'unknown', 'gpt-5') preservam a própria chave como familia.

    Test-LlmDelegateFamilyKnown: allowlist versionada de criadores que contam no piso de diversidade.
    Familia derivada fora da lista e unknown para o piso (nao colapsa no helper Get-*).
#>

# Lista normativa inicial (case-insensitive). Ampliar so com decisao humana + docs.
$script:LlmDelegateKnownFamilies = @(
    'openai', 'anthropic', 'google', 'moonshot', 'z-ai', 'deepseek', 'mistral', 'alibaba',
    'meta', 'minimaxai', 'nvidia', 'ollama-cloud', 'opencode-go', 'atlas-cloud',
    'github-copilot', 'microsoft'
)

function Test-LlmDelegateFamilyKnown {
    [CmdletBinding()]
    param(
        [string]$Family
    )
    Set-StrictMode -Version Latest
    if ([string]::IsNullOrWhiteSpace($Family)) { return $false }
    $trim = $Family.Trim()
    foreach ($f in $script:LlmDelegateKnownFamilies) {
        if ($f.Equals($trim, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-LlmDelegateTargetFamily {
    [CmdletBinding()]
    param(
        [string]$TargetModelKey
    )
    Set-StrictMode -Version Latest
    if ([string]::IsNullOrWhiteSpace($TargetModelKey)) { return $null }

    $trimmed = $TargetModelKey.Trim()
    if ($trimmed -notmatch '/') { return $trimmed }

    $parts = @($trimmed -split '/')
    $fam = $parts[0].Trim()

    if ($fam -ieq 'antigravity') {
        $modelId = if ($parts.Count -gt 1) { ($parts[1..($parts.Count - 1)] -join '/').Trim() } else { '' }
        if ($modelId -ilike 'claude-*') { return 'anthropic' }
        if ($modelId -ilike 'gpt-*')    { return 'openai' }
        return 'google'
    }

    if ($fam -ieq 'nvidia') {
        if ($parts.Count -ge 3) {
            $creatorRaw = $parts[1].Trim().ToLowerInvariant()
            # Os slugs canonicos adotados refletem a convencao oficial do catalogo de modelos
            switch ($creatorRaw) {
                'deepseek-ai' { return 'deepseek' }
                'mistralai'   { return 'mistral' }
                'qwen'        { return 'alibaba' }
                'meta-llama'  { return 'meta' }
                'facebook'    { return 'meta' }
                'thudm'       { return 'z-ai' }
                'glm'         { return 'z-ai' }
                'minimax'     { return 'minimaxai' }
                'moonshotai'  { return 'moonshot' }
                default {
                    if (-not [string]::IsNullOrWhiteSpace($creatorRaw)) { return $creatorRaw }
                    return 'nvidia'
                }
            }
        }
        elseif ($parts.Count -eq 2) {
            $modelId = $parts[1].Trim()
            if ($modelId -ilike 'nemotron-*') { return 'nvidia' }
            if ($modelId -ilike 'llama-*')    { return 'meta' }
            return 'nvidia'
        }
        return 'nvidia'
    }

    return $fam
}
