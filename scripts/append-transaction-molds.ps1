param(
    [Parameter(Mandatory = $true)]
    [string]$TargetMarkdown,

    [Parameter(Mandatory = $true)]
    [string[]]$XmlExamplePaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($XmlExamplePaths.Count -ne 4) {
    throw "append-transaction-molds.ps1 expects exactly 4 XML example paths."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$updateScript = Join-Path $scriptRoot 'Update-XpzDocSection.ps1'

$introLines = @(
    '- Evidencia direta: esta base agora contem 4 moldes XML sanitizados completos de `Transaction`, cobrindo as familias `F1`, `F2`, `F5` e `F6`.',
    '- Inferencia forte: esse conjunto ja permite prototipos controlados de `Transaction` sem depender de consulta adicional ao acervo bruto para essas familias representadas.',
    '- Hipotese: as familias `F3` e `F4` ainda ficam melhor atendidas por escolha de familia + molde bruto comparavel, porque nao receberam anexo completo nesta rodada.'
)

$exampleTitles = @(
    '### Molde sanitizado 1 - `TRNExemploF1`',
    '### Molde sanitizado 2 - `TRNExemploF2`',
    '### Molde sanitizado 3 - `TRNExemploF5`',
    '### Molde sanitizado 4 - `TRNExemploF6`'
)

$exampleNotes = @(
    ((@(
        '- Familia coberta: `F1` (`Um nivel enxuto`).',
        '- Fonte de selecao: menor XML observado da faixa `1 Level` + `0..6 AttributeProperties`.',
        '- Sanitizacao aplicada: nome do objeto, nome de pasta, textos visiveis e referencias nominais foram anonimizados; `Object/@type`, `Part type`, hierarquia, `parent*`, `moduleGuid` e estrutura XML foram preservados.'
    ) -join "`r`n")),
    ((@(
        '- Familia coberta: `F2` (`Um nivel com apoio estrutural moderado`).',
        '- Fonte de selecao: menor XML observado da faixa `1 Level` + `7..11 AttributeProperties`.',
        '- Sanitizacao aplicada: nome do objeto, textos de regra e referencias nominais foram anonimizados; a densidade de `AttributeProperties`, a ordem das `Part`, `CDATA` e os atributos internos foram preservados.'
    ) -join "`r`n")),
    ((@(
        '- Familia coberta: `F5` (`Pai-filho com dois niveis`).',
        '- Fonte de selecao: menor XML observado entre os objetos com exatamente `2 Level`.',
        '- Sanitizacao aplicada: nome do objeto, pasta, textos visiveis e referencias nominais foram anonimizados; a relacao pai-filho, o aninhamento de `Level`, `Part type` e blocos de evento foram preservados.'
    ) -join "`r`n")),
    ((@(
        '- Familia coberta: `F6` (`Multinivel`).',
        '- Fonte de selecao: menor XML observado entre os objetos com `3+ Level` escolhido por melhor legibilidade publica.',
        '- Sanitizacao aplicada: nome do objeto, nomes de subniveis, textos de negocio e referencias nominais foram anonimizados; o numero de niveis, a ordem de aninhamento, `Part type`, `CDATA` e densidade estrutural foram preservados.'
    ) -join "`r`n"))
)

& $updateScript `
    -TargetMarkdown $TargetMarkdown `
    -SectionTitle '## Moldes sanitizados completos de Transaction' `
    -IntroLines $introLines `
    -XmlExamplePaths $XmlExamplePaths `
    -ExampleTitles $exampleTitles `
    -ExampleNotes $exampleNotes
