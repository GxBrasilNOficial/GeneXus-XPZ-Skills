#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Test-PrePushSharedScriptSkillCoverage.ps1.

.DESCRIPTION
    Monta um repositório git temporario com um script compartilhado alterado e
    quatro documentos de skill. Confirma:
      - skill que cita o script e NÃO está no diff -> candidata (transversal);
      - quality-checklist.md que cita o script e NÃO está no diff -> candidata;
      - skill que cita o script mas ESTÁ no diff (dona tocada) -> não vira candidata;
      - skill que NÃO cita o script -> não vira candidata.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushSharedScriptSkillCoverage.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-shared-script-skill-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
$utf8NoBom = Get-Utf8NoBomEncoding
function Write-TempFile {
    param([string]$RelativePath, [string]$Content)
    $full = Join-Path $tempRoot $RelativePath
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
}

function Invoke-TempGit {
    param([string[]]$Arguments)
    $output = & git -C $tempRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} falhou: {1}" -f ($Arguments -join ' '), (($output | Out-String).Trim()))
    }
    return $output
}

try {
    [void](Invoke-TempGit @('init', '-q'))
    [void](Invoke-TempGit @('config', 'user.email', 'selftest@example.com'))
    [void](Invoke-TempGit @('config', 'user.name', 'Self Test'))
    [void](Invoke-TempGit @('config', 'commit.gpgsign', 'false'))

    $scriptName = 'Invoke-DemoSharedEngine'
    Write-TempFile -RelativePath ("scripts/{0}.ps1" -f $scriptName) -Content "param([string]`$X)`n# v1`n"

    # Skill dona (sera tocada nesta frente).
    Write-TempFile -RelativePath 'skill-dona/SKILL.md' -Content "# Dona`nContrato de ``$scriptName`` documentado aqui.`n"
    # Skill transversal que consome o script (NÃO sera tocada) -> candidata.
    Write-TempFile -RelativePath 'skill-transversal/SKILL.md' -Content "# Transversal`nEsta skill chama ``$scriptName`` no fluxo de import.`n"
    # quality-checklist transversal que cita o script (NÃO sera tocado) -> candidata.
    Write-TempFile -RelativePath 'skill-transversal/quality-checklist.md' -Content "# Checklist`n- [ ] verificar saida de ``$scriptName```n"
    # Skill que NÃO cita o script -> nunca candidata.
    Write-TempFile -RelativePath 'skill-outra/SKILL.md' -Content "# Outra`nNada a ver com o engine.`n"

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'base'))
    $baseSha = (Invoke-TempGit @('rev-parse', 'HEAD') | Out-String).Trim()

    # HEAD: altera o script E a skill dona (esta entra no diff).
    Write-TempFile -RelativePath ("scripts/{0}.ps1" -f $scriptName) -Content "param([string]`$X, [string]`$Y)`n# v2 novo parametro`n"
    Write-TempFile -RelativePath 'skill-dona/SKILL.md' -Content "# Dona`nContrato de ``$scriptName`` documentado aqui (agora com -Y).`n"

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'altera engine e skill dona'))

    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -BaseRef $baseSha -AsJson 2>&1
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    $result = $jsonText | ConvertFrom-Json

    if ($exitCode -ne 0) {
        throw "gate deveria sair com exit 0 (consultivo); obtido $exitCode. Saida: $jsonText"
    }
    if ($result.status -ne 'warn') {
        throw "status deveria ser 'warn'; obtido '$($result.status)'. Saida: $jsonText"
    }

    $candidatePaths = @($result.findings | ForEach-Object { $_.path })

    if (@($candidatePaths | Where-Object { $_ -like 'skill-transversal/SKILL.md:*' }).Count -eq 0) {
        throw "skill-transversal/SKILL.md (cita o script, fora do diff) deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }
    if (@($candidatePaths | Where-Object { $_ -like 'skill-transversal/quality-checklist.md:*' }).Count -eq 0) {
        throw "skill-transversal/quality-checklist.md deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }
    if (@($candidatePaths | Where-Object { $_ -like 'skill-dona/SKILL.md:*' }).Count -ne 0) {
        throw "skill-dona/SKILL.md esta no diff e NAO deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }
    if (@($candidatePaths | Where-Object { $_ -like 'skill-outra/SKILL.md:*' }).Count -ne 0) {
        throw "skill-outra/SKILL.md nao cita o script e NAO deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }

    Write-Output 'OK: Test-PrePushSharedScriptSkillCoverageSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
