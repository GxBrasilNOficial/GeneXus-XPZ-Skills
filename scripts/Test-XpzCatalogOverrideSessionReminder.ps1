#requires -Version 7.4
<#
.SYNOPSIS
    Emite lembrete de sessao quando gx-object-type-catalog.override.json estiver ativo.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela da KB.

.PARAMETER CatalogOverridePath
    Caminho opcional do override.

.PARAMETER AsJson
    Saida JSON (recomendado para agentes).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ParallelKbRoot,

    [string]$CatalogOverridePath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1')

$resolvedKbRoot = (Resolve-Path -LiteralPath $ParallelKbRoot).Path
$reminder = Get-GeneXusCatalogOverrideSessionReminder -ParallelKbRoot $resolvedKbRoot -CatalogOverridePath $CatalogOverridePath

$result = [pscustomobject]@{
    status                   = $reminder.status
    parallelKbRoot           = $resolvedKbRoot
    reminderRequired         = $reminder.reminderRequired
    noticeRequired           = $reminder.noticeRequired
    cleanupRecommended       = $reminder.cleanupRecommended
    blocked                  = $reminder.blocked
    overrideActive           = $reminder.overrideActive
    upstreamPending          = $reminder.upstreamPending
    declaredUpstreamPending  = $reminder.declaredUpstreamPending
    effectiveUpstreamPending = $reminder.effectiveUpstreamPending
    reason                   = $reminder.reason
    diagnosticReason         = $reminder.diagnosticReason
    fieldPath                = $reminder.fieldPath
    overridePath             = $reminder.overridePath
    pendingTypeNames         = $reminder.pendingTypeNames
    pendingTypeGuids         = $reminder.pendingTypeGuids
    redundantTypeNames       = $reminder.redundantTypeNames
    redundantTypeGuids       = $reminder.redundantTypeGuids
    divergentTypeNames       = $reminder.divergentTypeNames
    divergentTypeGuids       = $reminder.divergentTypeGuids
    blockedTypeNames         = $reminder.blockedTypeNames
    blockedTypeGuids         = $reminder.blockedTypeGuids
    classificationEntries    = $reminder.classificationEntries
    message                  = $reminder.message
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    if ($reminder.reminderRequired) {
        Write-Output $reminder.message
    } elseif ($reminder.cleanupRecommended) {
        $names = @($reminder.redundantTypeNames) -join ', '
        if ([string]::IsNullOrWhiteSpace($names)) {
            Write-Output 'CLEANUP_RECOMMENDED: override local ativo sem pendencia efetiva; remocao local aprovada e recomendada se nao houver entradas de tipo.'
        } else {
            Write-Output ("CLEANUP_RECOMMENDED: override local redundante para: {0}. Remocao local aprovada e recomendada; nao ha pendencia global efetiva." -f $names)
        }
    } elseif ($reminder.overrideActive) {
        Write-Output ("{0}: override local ativo sem lembrete pendente." -f $reminder.status)
    } else {
        Write-Output 'OK: nenhum override local de catalogo ativo.'
    }
}

exit $(if ($reminder.status -in @('REMINDER_REQUIRED', 'INVALID_OVERRIDE_SHAPE', 'OVERRIDE_RESOLUTION_BLOCKED')) { 2 } else { 0 })
