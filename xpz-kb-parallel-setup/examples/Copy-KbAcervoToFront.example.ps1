#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para copiar XMLs do acervo para a frente, com bump de lastUpdate.

.DESCRIPTION
Chama o script compartilhado Copy-GeneXusAcervoToFront.ps1 para copiar XMLs de
ObjetosDaKbEmXml para a pasta da frente, com bump automático de lastUpdate.
Resolve o anti-padrao "editar acervo esperando que o pacote pegue": em vez de
editar o acervo, copia a versão mais recente para a frente e bumpa o lastUpdate.
Se frente e acervo compartilharem o mesmo guid com Object/@type divergente, a
copia automatica e bloqueada; a resolucao exige decisao humana antes de
autocopiar ou fazer bump.
Quando ObjectList, ObjectNames ou ObjectGuids e informado e o objeto ainda não existe na frente,
faz seed inicial desse objeto a partir do acervo. Seed nunca ocorre sem alvo explicito.

.PARAMETER FrontName
Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD, conforme devolvido por
New-KbFront.ps1. A frente deve ter sido aberta antes (New-KbFront -ReuseIfExists para
retomar); este wrapper apenas popula uma frente existente, não cria a pasta.

.PARAMETER ObjectList
Nome canonico da selecao de objeto por nome. Aceita nomes simples ou entradas
`Tipo:Nome`; o wrapper repassa apenas o nome ao motor de copia. Quando omitido
(junto com -ObjectNames/-ObjectGuids), copia todos com drift. Para seed inicial,
deve identificar um único XML no acervo.

.PARAMETER ObjectNames
Sinonimo aceito de -ObjectList (mesma semantica de selecao por nome), mantido por
retrocompatibilidade. Itens de -ObjectNames e -ObjectList são combinados.

.PARAMETER ObjectGuids
GUIDs de objetos a copiar (opcional). Quando omitido, copia todos com drift.
Para seed inicial, deve identificar um único XML no acervo.

.PARAMETER DryRun
Mostra o que seria copiado sem gravar.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada GeneXus-XPZ-Skills.

.EXAMPLE
# Fluxo de 2 passos. O nome da frente (NomeCurto_GUID_YYYYMMDD) NÃO é inventado: ele é
# gerado/retomado pelo passo 1. Nunca crie a pasta da frente manualmente.
# Passo 1 - abrir/retomar a frente (devolve frontDir = ...\NomeCurto_GUID_YYYYMMDD):
.\New-KbFront.ps1 -NomeCurto GtaP3 -ReuseIfExists
# Passo 2 - popular a frente, usando o nome da subpasta devolvida pelo passo 1 como -FrontName:
.\Copy-KbAcervoToFront.ps1 -FrontName GtaP3_c34f_20260528

.EXAMPLE
# Seed inicial de objetos específicos do acervo para a frente (ainda não existem nela).
# Seed só ocorre com alvo explicito; sem -ObjectList/-ObjectNames/-ObjectGuids nada e
# semeado e objectsScanned:0 / 'not-applicable' e o resultado esperado, não um erro.
.\Copy-KbAcervoToFront.ps1 -FrontName GtaP3_c34f_20260528 -ObjectList 'Procedure:PReabastecerEstoque','SDT_Item'
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string[]]$ObjectNames,

    [string[]]$ObjectList,

    [string[]]$ObjectGuids,

    [switch]$DryRun,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $SharedSkillsRoot "scripts\Copy-GeneXusAcervoToFront.ps1"

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Shared script not found: $scriptPath"
}

$frontFolder = Join-Path $repoRoot "ObjetosGeradosParaImportacaoNaKbNoGenexus" $FrontName
$acervoFolder = Join-Path $repoRoot "ObjetosDaKbEmXml"

$argsForScript = @{
    FrontFolder = $frontFolder
    AcervoFolder = $acervoFolder
}

if ($DryRun) {
    $argsForScript.DryRun = $true
}

if ($null -ne $ObjectNames -and $ObjectNames.Count -gt 0) {
    $argsForScript.ObjectNames = $ObjectNames
}

if ($null -ne $ObjectList -and $ObjectList.Count -gt 0) {
    $objectListNames = @($ObjectList | ForEach-Object {
        $item = [string]$_
        if ($item -match '^[^:]+:(?<name>.+)$') { $Matches['name'] } else { $item }
    })
    $argsForScript.ObjectNames = @($argsForScript.ObjectNames) + $objectListNames
}

if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) {
    $argsForScript.ObjectGuids = $ObjectGuids
}

& $scriptPath @argsForScript
