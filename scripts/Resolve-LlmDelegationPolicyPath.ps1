#requires -Version 7.4

<#
.SYNOPSIS
    Resolve o caminho efetivo do arquivo de politica de delegacao a LLM na raiz de uma
    pasta paralela de KB, com fallback do nome canonico para o nome legado.
.DESCRIPTION
    Nucleo backend-agnostico da skill xpz-llm-delegate. O nome canonico do arquivo de
    politica e 'llm-delegation-policy.json'. O nome legado 'opencode-delegation-policy.json'
    (herdado de quando so existia o backend opencode) permanece suportado indefinidamente
    para retrocompatibilidade: o arquivo governa todos os backends por chave de DESTINO,
    nunca por backend, entao o nome de um backend especifico no arquivo e enganoso.

    Regra de resolucao, dada a raiz da pasta paralela:
      - existe so o canonico   -> status 'new'    (path = canonico)
      - existe so o legado     -> status 'legacy' (path = legado; deprecatedNameInUse=true)
      - existem ambos          -> status 'both'   (path = canonico; legado sinalizado)
      - nenhum                 -> status 'none'   (path = caminho do canonico, p/ gravacao futura)

    Saida: objeto JSON de maquina no stdout. Nao le nem grava o arquivo de politica; so
    resolve o caminho.
.PARAMETER ParallelKbRoot
    Raiz da pasta paralela de KB onde o arquivo de politica vive (ou viveria).
.EXAMPLE
    .\Resolve-LlmDelegationPolicyPath.ps1 -ParallelKbRoot C:\Dev\Prod\MinhaKb
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $ParallelKbRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonicalName = 'llm-delegation-policy.json'
$legacyName    = 'opencode-delegation-policy.json'

if (-not (Test-Path -LiteralPath $ParallelKbRoot -PathType Container)) {
    throw "BLOCK: ParallelKbRoot nao e um diretorio existente: $ParallelKbRoot"
}
$root = (Resolve-Path -LiteralPath $ParallelKbRoot).Path

$canonicalPath = Join-Path $root $canonicalName
$legacyPath    = Join-Path $root $legacyName
$hasCanonical  = Test-Path -LiteralPath $canonicalPath -PathType Leaf
$hasLegacy     = Test-Path -LiteralPath $legacyPath -PathType Leaf

if ($hasCanonical -and $hasLegacy) {
    $status = 'both'; $path = $canonicalPath; $fileName = $canonicalName; $deprecated = $true
    $reason = "ambos os nomes presentes; usando o canonico '$canonicalName'. Remova o legado '$legacyName' apos confirmar a migracao."
} elseif ($hasCanonical) {
    $status = 'new'; $path = $canonicalPath; $fileName = $canonicalName; $deprecated = $false
    $reason = "politica encontrada com o nome canonico '$canonicalName'."
} elseif ($hasLegacy) {
    $status = 'legacy'; $path = $legacyPath; $fileName = $legacyName; $deprecated = $true
    $reason = "politica encontrada com o nome legado '$legacyName'; considere renomear para '$canonicalName'."
} else {
    $status = 'none'; $path = $canonicalPath; $fileName = $canonicalName; $deprecated = $false
    $reason = "nenhum arquivo de politica na raiz; caminho canonico para gravacao futura e '$canonicalName'."
}

[pscustomobject]@{
    parallelKbRoot      = $root
    path                = $path
    fileName            = $fileName
    status              = $status
    exists              = ($status -ne 'none')
    deprecatedNameInUse = $deprecated
    canonicalName       = $canonicalName
    legacyName          = $legacyName
    reason              = $reason
} | ConvertTo-Json -Compress
