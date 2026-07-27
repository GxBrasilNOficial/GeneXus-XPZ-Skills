#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de contrato das funcoes puras de CodexCliSupport.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Valida Get-CodexExecErrorMessage (extracao de erro do stdout/stderr), Resolve-CodexExe
    no modo -Override e a descoberta automatica deterministica com uma raiz sintetica:
    executavel canonico prevalece, diretorios backup-* ficam excluidos e o fallback e usado
    somente quando o canonico nao esta disponivel.
    Sentinela de sucesso: OK: Test-CodexCliSupportSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

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

# Get-CodexExecErrorMessage
$e1 = Get-CodexExecErrorMessage -StdoutText 'ERROR: {"type":"error","error":{"message":"boom"}}' -StderrText ''
Assert-Equal 'erro: extrai message' $e1 'boom'

$e2 = Get-CodexExecErrorMessage -StdoutText 'tudo certo, sem erro' -StderrText ''
Assert-Equal 'sem erro -> vazio' $e2 ''

$e3 = Get-CodexExecErrorMessage -StdoutText '' -StderrText 'ERROR: {"error":{"message":"The gpt-5.5 model requires a newer version of Codex."}}'
Assert-Equal 'erro no stderr (modelo novo)' $e3 'The gpt-5.5 model requires a newer version of Codex.'

$e4 = Get-CodexExecErrorMessage -StdoutText 'ERROR: {json invalido' -StderrText ''
Assert-Equal 'erro com json invalido -> texto cru' $e4 '{json invalido'

# Resolve-CodexExe -Override
$self = (Get-Command pwsh).Source
$rOk = Resolve-CodexExe -Override $self
Assert-Equal 'override existente devolve o caminho' $rOk $self

$threw = $false
try { Resolve-CodexExe -Override 'C:\__nao_existe__\codex.exe' | Out-Null } catch { $threw = $true }
Assert-Equal 'override inexistente lanca BLOCK' $threw $true

# Resolve-CodexExe - descoberta automatica deterministica
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$probeRoot = [IO.Path]::GetFullPath((Join-Path $tempRoot ('CodexCliSupportSelfTest_' + [guid]::NewGuid().ToString('N'))))
if (-not $probeRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "BLOCK: raiz temporaria inesperada no self-test: $probeRoot"
}
$canonicalPath = Join-Path $probeRoot 'codex.exe'
$stagedDir = Join-Path $probeRoot 'staged-alpha'
$stagedPath = Join-Path $stagedDir 'codex.exe'
$backupDir = Join-Path $probeRoot 'backup-before-0.142.5'
$backupPath = Join-Path $backupDir 'codex.exe'
$originalVersionProbe = ${function:Get-CodexExeVersion}
try {
    New-Item -ItemType Directory -Path $stagedDir, $backupDir -Force | Out-Null
    New-Item -ItemType File -Path $canonicalPath, $stagedPath, $backupPath -Force | Out-Null

    function Get-CodexExeVersion {
        param([string]$ExePath)
        if ([string]::Equals($ExePath, $canonicalPath, [StringComparison]::OrdinalIgnoreCase)) {
            return [version]'0.142.5'
        }
        if ([string]::Equals($ExePath, $stagedPath, [StringComparison]::OrdinalIgnoreCase)) {
            return [version]'0.146.0'
        }
        if ([string]::Equals($ExePath, $backupPath, [StringComparison]::OrdinalIgnoreCase)) {
            return [version]'9.9.9'
        }
        return $null
    }

    $candidates = @(Get-CodexExeCandidatePaths -BasePath $probeRoot)
    Assert-Equal 'descoberta: exclui backup-*' ($candidates -contains $backupPath) $false
    Assert-Equal 'descoberta: canonico primeiro' $candidates[0] $canonicalPath
    Assert-Equal 'resolve: canonico prevalece sobre alpha maior' (Resolve-CodexExe -BasePath $probeRoot) $canonicalPath

    Remove-Item -LiteralPath $canonicalPath -Force
    Assert-Equal 'resolve: fallback sem canonico' (Resolve-CodexExe -BasePath $probeRoot) $stagedPath

    Remove-Item -LiteralPath $stagedPath -Force
    $onlyBackupThrew = $false
    try { Resolve-CodexExe -BasePath $probeRoot | Out-Null } catch { $onlyBackupThrew = $true }
    Assert-Equal 'resolve: somente backup bloqueia' $onlyBackupThrew $true
}
finally {
    Set-Item -Path Function:Get-CodexExeVersion -Value $originalVersionProbe
    if (Test-Path -LiteralPath $probeRoot -PathType Container) {
        Remove-Item -LiteralPath $probeRoot -Recurse -Force
    }
}

# Resolve-CodexJobStatus — a resposta final manda; stderr ruidoso nao gera falso 'error'
$s1 = Resolve-CodexJobStatus -FinalText 'VEREDICTO: nenhum gap' -StreamError '' -Stderr 'ERROR: {"error":{"message":"x"}}'
Assert-Equal 'status: resposta final + stderr ruidoso -> completed' $s1.status 'completed'

$s2 = Resolve-CodexJobStatus -FinalText '' -StreamError '' -Stderr 'ERROR: {"error":{"message":"modelo nao suportado"}}'
Assert-Equal 'status: sem resposta + erro de servidor -> error' $s2.status 'error'

$s3 = Resolve-CodexJobStatus -FinalText '' -StreamError 'evento de erro do stream' -Stderr ''
Assert-Equal 'status: sem resposta + erro de stream -> error' $s3.status 'error'

$s4 = Resolve-CodexJobStatus -FinalText '' -StreamError '' -Stderr 'tudo limpo, sem erro'
Assert-Equal 'status: sem resposta sem erro -> sem-texto' $s4.status 'sem-texto'

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-CodexCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-CodexCliSupportSelfTest.ps1' -ForegroundColor Cyan
