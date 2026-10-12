#requires -Version 7.4

<#
.SYNOPSIS
    Self-test do aplicador Repair-PtBrAccentDegradation.ps1 (caminhos .md e .ps1).
.DESCRIPTION
    Cria arquivos temporarios golden, roda o aplicador via -Files e verifica:
    - .md: inequivoca corrigida; code inline e fenced block preservados; faixa
      pt-BR respeitada (secao ES/EN nao tocada); EOL/UTF-8.
    - .ps1: inequivoca corrigida SO em comentarios (de linha e de bloco); codigo
      e strings intactos, inclusive string com '#' no meio; idempotencia.
    Exit 0 se tudo passa; exit 1 na primeira falha.
.EXAMPLE
    pwsh -NoProfile -File scripts/Test-RepairPtBrAccentDegradationSelfTest.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repair = Join-Path $PSScriptRoot 'Repair-PtBrAccentDegradation.ps1'
$script:passed = 0
function Assert-True {
    param([bool] $Cond, [string] $Message)
    if (-not $Cond) { throw "FAIL: $Message" }
    $script:passed++
    Write-Host "  ok: $Message"
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('repairtest_' + [System.IO.Path]::GetRandomFileName())
[void](New-Item -ItemType Directory -Path $tmp)
$enc = New-Object System.Text.UTF8Encoding($false)

try {
    # -----------------------------------------------------------------------
    # Golden .ps1 — corrige so comentarios; codigo/strings intactos.
    # -----------------------------------------------------------------------
    $ps = @(
        '$funcao = 1   # define a funcao principal'
        'Write-Output "mensagem: nao traduzida"'
        '<#'
        '  Resumo: gera o indice e a versao.'
        '#>'
        '$x = "tem # nao"   # comentario com acao'
    ) -join "`n"
    $psPath = Join-Path $tmp 'golden.ps1'
    [System.IO.File]::WriteAllText($psPath, $ps, $enc)

    & $repair -Files $psPath | Out-Null
    $r = [System.IO.File]::ReadAllText($psPath)

    Write-Host 'Golden .ps1:'
    Assert-True ($r -match 'define a função principal') 'ps: comentario de linha corrigido (funcao->função)'
    Assert-True ($r -match '\$funcao = 1')               'ps: identificador de codigo $funcao intacto'
    Assert-True ($r -match 'mensagem: nao traduzida')    'ps: string com "nao" NAO tocada'
    Assert-True ($r -match 'gera o índice e a versão')   'ps: bloco <# #> corrigido (indice/versao)'
    Assert-True ($r -match '"tem # nao"')                'ps: string com # no meio NAO tocada'
    Assert-True ($r -match 'comentario com ação')        'ps: comentario apos string-com-# corrigido (acao->ação)'

    # Idempotencia: segunda passada nao muda nada
    & $repair -Files $psPath | Out-Null
    $r2 = [System.IO.File]::ReadAllText($psPath)
    Assert-True ($r2 -ceq $r) 'ps: idempotente (segunda passada sem mudanca)'

    # -----------------------------------------------------------------------
    # Golden .md — inequivoca + supressao de codigo + faixa pt-BR.
    # -----------------------------------------------------------------------
    $md = @(
        'A funcao nao foi documentada.'
        'Codigo inline: `funcao` preservado.'
        '```'
        'nao funcao codigo'
        '```'
        '## Español'
        'El repositorio tiene una version.'
    ) -join "`n"
    $mdPath = Join-Path $tmp 'golden.md'
    [System.IO.File]::WriteAllText($mdPath, $md, $enc)

    & $repair -Files $mdPath | Out-Null
    $rm = [System.IO.File]::ReadAllText($mdPath)

    Write-Host 'Golden .md:'
    Assert-True ($rm -match 'A função não foi documentada')   'md: prosa corrigida (funcao/nao)'
    Assert-True ($rm -match 'Código inline: `funcao` preservado') 'md: code inline preservado, prefixo corrigido'
    Assert-True ($rm -match "(?m)^nao funcao codigo$")         'md: fenced block intacto'
    Assert-True ($rm -match 'El repositorio tiene una version') 'md: secao Español NAO tocada (faixa pt-BR)'

    # -----------------------------------------------------------------------
    # Caixa preservada
    # -----------------------------------------------------------------------
    $caso = '# NAO e tambem, Funcao final' -join "`n"
    $cPath = Join-Path $tmp 'caixa.ps1'
    [System.IO.File]::WriteAllText($cPath, $caso, $enc)
    & $repair -Files $cPath | Out-Null
    $rc = [System.IO.File]::ReadAllText($cPath)
    Write-Host 'Caixa:'
    Assert-True ($rc -cmatch 'NÃO')    'caixa: ALLCAPS preservado (NAO->NÃO)'
    Assert-True ($rc -cmatch 'também') 'caixa: minuscula (tambem->também)'
    Assert-True ($rc -cmatch 'Função') 'caixa: Title preservado (Funcao->Função)'

    Write-Host ''
    Write-Host "SELF-TEST OK ($script:passed asserts)."
    Write-Host 'PTBR_ACCENT_REPAIR_SELFTEST_OK'
    exit 0
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
