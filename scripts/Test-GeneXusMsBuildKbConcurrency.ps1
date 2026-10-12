#requires -Version 7.4

<#
.SYNOPSIS
Verifica se já existe MSBuild.exe em execução para a mesma KB GeneXus.

.DESCRIPTION
Executa um bloqueio preventivo simples para wrappers MSBuild headless. O script
lista processos MSBuild.exe, tenta reconciliar cada processo com o arquivo
O arquivo .msbuild informado na linha de comando e compara o KBPath encontrado com a KB
solicitada.

Bloqueia apenas quando a mesma KB e confirmada. Processos MSBuild sem projeto
ou sem KBPath reconciliavel são reportados como aviso, mas não bloqueiam.

.PARAMETER KbPath
Caminho da KB GeneXus que o chamador pretende abrir via MSBuild.

.PARAMETER ExcludeProcessId
PID opcional a ignorar. Default: processo atual.

.PARAMETER AsJson
Mantido por compatibilidade com os demais scripts de diagnostico; a saida e
sempre JSON.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [int]$ExcludeProcessId = $PID,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildConcurrencySupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "Concurrency support script not found: $supportPath"
}
. $supportPath

$diagnostic = Invoke-GeneXusMsBuildKbConcurrencyCheck -KbPath $KbPath -ExcludeProcessId $ExcludeProcessId
$json = ($diagnostic | ConvertTo-Json -Depth 12)
Write-Output $json
exit ([int]$diagnostic.exitCode)
