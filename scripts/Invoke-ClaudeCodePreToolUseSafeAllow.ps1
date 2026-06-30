# Invoke-ClaudeCodePreToolUseSafeAllow.ps1 - decisor do hook PreToolUse do CLAUDE CODE (auto-allow).
# Solucao especifica do Claude Code (hook PreToolUse + permissionDecision); nao se aplica a
# Codex/Cursor/OpenCode. Le o JSON do hook no stdin (ou -InputJson para teste) e emite em JSON:
#   {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow|defer",...}}
# NUNCA emite 'deny'. Fail-closed: qualquer erro -> 'defer'.
# Ver claude-code-pretooluse-auto-allow-design.md.
[CmdletBinding()]
param(
    [switch] $Observe,
    [string] $InputJson,
    [string] $LogPath
)

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowSupport.ps1')

function Get-PtuProp {
    param($Obj, [string] $Name)
    if ($Obj -and ($null -ne $Obj.PSObject.Properties[$Name])) { return $Obj.$Name }  # indexer: StrictMode-safe p/ objeto vazio (vs .Properties.Name -contains, que lanca)
    return $null
}

function Get-PtuHookOutput {
    param([string] $Decision, [string] $Reason)
    $payload = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $Decision
            permissionDecisionReason = $Reason
        }
    }
    return ($payload | ConvertTo-Json -Compress -Depth 6)
}

function Get-PtuPythonExe {
    $cmd = Get-Command -Name python -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cmd = Get-Command -Name python3 -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$decision = 'defer'
$reason = "ptu v$script:PtuSafeAllowVersion fail-closed"

try {
    if ([string]::IsNullOrWhiteSpace($InputJson)) { $InputJson = [Console]::In.ReadToEnd() }
    $hook = $InputJson | ConvertFrom-Json

    $toolName = [string](Get-PtuProp $hook 'tool_name')
    $cwd = [string](Get-PtuProp $hook 'cwd')
    $toolInput = Get-PtuProp $hook 'tool_input'
    $command = [string](Get-PtuProp $toolInput 'command')

    $roots = Get-PtuRoots
    $pythonExe = Get-PtuPythonExe
    $helperPath = Join-Path $PSScriptRoot 'Get-ClaudeCodeBashSafeSegments.py'

    $computed = Get-PtuDecision -ToolName $toolName -Command $command -Cwd $cwd -Roots $roots -PythonExe $pythonExe -HelperPath $helperPath

    if ($Observe) {
        # Observa: nunca muda nada (sempre 'defer'); registra o que TERIA decidido.
        $logFile = $LogPath
        if ([string]::IsNullOrWhiteSpace($logFile)) { $logFile = Join-Path $env:LOCALAPPDATA 'xpz-pretooluse-observe.log' }
        try {
            $entry = [ordered]@{ ts = (Get-Date).ToString('o'); tool = $toolName; wouldDecision = $computed; command = $command }
            Add-Content -LiteralPath $logFile -Value ($entry | ConvertTo-Json -Compress -Depth 6)
        }
        catch { }
        $decision = 'defer'
        $reason = "ptu-observe v$script:PtuSafeAllowVersion would=$computed"
    }
    else {
        $decision = $computed
        $reason = "ptu v$script:PtuSafeAllowVersion"
    }
}
catch {
    $decision = 'defer'
    $reason = "ptu v$script:PtuSafeAllowVersion fail-closed"
}

Get-PtuHookOutput -Decision $decision -Reason $reason
