#requires -Version 7.4

<#
.SYNOPSIS
    Self-test das funcoes puras de CopilotCliSupport.ps1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CopilotCliSupport.ps1')

$fail = 0
function Assert-Equal {
    param([string]$Label, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Label) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0} -> '{1}' (esperado '{2}')" -f $Label, $Got, $Expected) -ForegroundColor Red
    }
}

Assert-Equal 'parse versao' (ConvertFrom-CopilotVersionText 'copilot 1.0.12') ([version]'1.0.12')
Assert-Equal 'parse invalido -> null' (ConvertFrom-CopilotVersionText 'sem versao') $null

$helpOk = @'
--prompt
--output-format
--stream
--no-custom-instructions
--disable-builtin-mcps
--available-tools
--allow-all-tools
--model
'@
Assert-Equal 'help com flags exigidas' (Test-CopilotHelpSupportsContract $helpOk) $true
Assert-Equal 'help incompleto' (Test-CopilotHelpSupportsContract '--prompt --model') $false

$lines = @(
    '{"type":"assistant.message","data":{"content":"primeira"}}',
    '{"type":"tool.call","data":{}}',
    'linha-nao-json',
    '{"type":"assistant.message","data":{"content":"final"}}',
    '{"type":"result","exitCode":0}'
)
Assert-Equal 'jsonl ultima assistant.message manda' (Get-CopilotJsonlFinalText -Lines $lines) 'final'
Assert-Equal 'jsonl exitCode do evento result' (Get-CopilotJsonlExitCode -Lines $lines) 0

$linesSemResposta = @('{"type":"tool.call","data":{}}', 'ruido')
Assert-Equal 'jsonl sem assistant.message -> vazio' (Get-CopilotJsonlFinalText -Lines $linesSemResposta) ''
Assert-Equal 'jsonl sem result -> null' (Get-CopilotJsonlExitCode -Lines $linesSemResposta) $null

$linesErroExit = @('{"type":"result","exitCode":2}')
Assert-Equal 'jsonl exitCode nao-zero' (Get-CopilotJsonlExitCode -Lines $linesErroExit) 2

$err = Get-CopilotErrorMessage -StdoutText '' -StderrText 'Error: not available'
Assert-Equal 'extrai erro simples' $err 'Error: not available'
$semErr = Get-CopilotErrorMessage -StdoutText 'tudo certo' -StderrText ''
Assert-Equal 'sem erro -> null' $semErr $null

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-CopilotCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-CopilotCliSupportSelfTest.ps1' -ForegroundColor Cyan
