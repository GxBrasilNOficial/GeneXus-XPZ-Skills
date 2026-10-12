#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Test-PrePushHistoryCommitPlaceholder.ps1.

.DESCRIPTION
    Monta um repositório git temporario e confirma:
      - campo Commit: com placeholder ('este commit', 'TODO', vazio) em
        arquivo historico/ tocado pela frente -> candidata;
      - campo Commit: com hash real -> não vira candidata;
      - arquivo historico/ NÃO tocado (fora do diff) -> não vira candidata;
      - arquivo fora de historico/ com placeholder -> não vira candidata.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushHistoryCommitPlaceholder.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-history-commit-placeholder-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
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

    # historico/ NÃO tocado nesta frente, com placeholder -> não deve ser candidata.
    Write-TempFile -RelativePath 'historico/Antigo.md' -Content "### Rastreabilidade`n- Commit: este commit`n"
    Write-TempFile -RelativePath 'base.md' -Content "base`n"
    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'base'))
    $baseSha = (Invoke-TempGit @('rev-parse', 'HEAD') | Out-String).Trim()

    # historico/ tocado: mistura de placeholder e hash real.
    $novo = @'
## Frente X

### Rastreabilidade

- Commit: este commit

## Frente Y

### Rastreabilidade

- Commit: `9acc032` (`mensagem real`)

## Frente Z

### Rastreabilidade

- Commit: TODO

## Frente W

### Rastreabilidade

- Commit:
'@
    Write-TempFile -RelativePath 'historico/IdeiasImplementadas_teste.md' -Content $novo
    # arquivo fora de historico/ com placeholder -> não deve ser candidata.
    Write-TempFile -RelativePath 'CHANGELOG.md' -Content "- Commit: este commit`n"

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'adiciona historico com placeholders'))

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

    $paths = @($result.findings | ForEach-Object { $_.path })

    # 'este commit' (linha 5) e 'TODO' (linha 17) devem ser candidatas.
    if (@($paths | Where-Object { $_ -eq 'historico/IdeiasImplementadas_teste.md:5' }).Count -eq 0) {
        throw "placeholder 'este commit' deveria virar candidata (linha 5); candidatas: $($paths -join ', ')"
    }
    if (@($paths | Where-Object { $_ -eq 'historico/IdeiasImplementadas_teste.md:17' }).Count -eq 0) {
        throw "placeholder 'TODO' deveria virar candidata (linha 17); candidatas: $($paths -join ', ')"
    }
    # 'vazio' (campo Commit: sem valor) deve ser candidata.
    if (@($result.findings | Where-Object { $_.message -match '\(vazio\)' }).Count -eq 0) {
        throw "placeholder vazio deveria virar candidata; candidatas: $($paths -join ', ')"
    }
    # hash real (linha 11) NÃO deve ser candidata.
    if (@($paths | Where-Object { $_ -eq 'historico/IdeiasImplementadas_teste.md:11' }).Count -ne 0) {
        throw "hash real NAO deveria virar candidata (linha 11); candidatas: $($paths -join ', ')"
    }
    # historico/ não tocado NÃO deve aparecer.
    if (@($paths | Where-Object { $_ -like 'historico/Antigo.md:*' }).Count -ne 0) {
        throw "historico/Antigo.md (fora do diff) NAO deveria virar candidata; candidatas: $($paths -join ', ')"
    }
    # fora de historico/ NÃO deve aparecer.
    if (@($paths | Where-Object { $_ -like 'CHANGELOG.md:*' }).Count -ne 0) {
        throw "CHANGELOG.md (fora de historico/) NAO deveria virar candidata; candidatas: $($paths -join ', ')"
    }

    Write-Output 'OK: Test-PrePushHistoryCommitPlaceholderSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
