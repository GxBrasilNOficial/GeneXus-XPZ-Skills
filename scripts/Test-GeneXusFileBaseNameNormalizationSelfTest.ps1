#requires -Version 7.4
<#
.SYNOPSIS
    Self-test (lock de comportamento) da fonte unica Normalize-FileBaseName.

.DESCRIPTION
    Dot-sourceia GeneXusFileBaseNameNormalizationSupport.ps1 e trava a saida de Normalize-FileBaseName
    para uma tabela de nomes problematicos (caracteres invalidos de arquivo, ponto final, etc.). Como
    Sync-GeneXusXpzToXml.ps1 e (futuramente) o conversor de export legado dot-sourceiam a MESMA
    funcao, esta tabela garante normalizacao identica entre os caminhos (paridade) e protege contra
    regressao na extracao.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportScript = Join-Path $PSScriptRoot 'GeneXusFileBaseNameNormalizationSupport.ps1'
if (-not (Test-Path -LiteralPath $supportScript -PathType Leaf)) {
    throw "Support script not found: $supportScript"
}
. $supportScript

function Assert-Equal {
    param([string]$Actual, [string]$Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "ASSERT FALHOU: $Message (esperado='$Expected', obtido='$Actual')"
    }
}

# Casos de lock. '/' '\' ':' '*' '?' '<' '>' '|' '"' sao invalidos -> '_'; ponto final -> removido;
# ponto interno preservado.
$cases = @(
    @{ In = 'Cliente';        Out = 'Cliente' }
    @{ In = 'a/b';            Out = 'a_b' }
    @{ In = 'a\b';            Out = 'a_b' }
    @{ In = 'a:b*c?d';        Out = 'a_b_c_d' }
    @{ In = 'a<b>c|d';        Out = 'a_b_c_d' }
    @{ In = 'with"quote';     Out = 'with_quote' }
    @{ In = 'report.';        Out = 'report' }
    @{ In = 'ends...';        Out = 'ends' }
    @{ In = 'a.b.c';          Out = 'a.b.c' }
    @{ In = '';               Out = '' }
)

foreach ($case in $cases) {
    $actual = Normalize-FileBaseName -LogicalName $case.In
    Assert-Equal -Actual $actual -Expected $case.Out -Message ("Normalize-FileBaseName('{0}')" -f $case.In)
}

Write-Output 'OK: Test-GeneXusFileBaseNameNormalizationSelfTest.ps1'
exit 0
