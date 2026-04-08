param(
    [Parameter(Mandatory = $true)]
    [string]$TargetMarkdown,

    [Parameter(Mandatory = $true)]
    [string[]]$XmlExamplePaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($XmlExamplePaths.Count -ne 4) {
    throw "append-procedure-dp-molds.ps1 expects exactly 4 XML example paths."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$updateScript = Join-Path $scriptRoot 'Update-XpzDocSection.ps1'

$introLines = @(
    '- Evidencia direta: esta base agora contem 2 moldes XML sanitizados completos de `Procedure` e 2 de `DataProvider`.',
    '- Inferencia forte: esse conjunto complementa os moldes ja existentes de `WebPanel` e `Transaction`, reduzindo a necessidade de consulta adicional ao acervo bruto para prototipos controlados desses dois tipos.',
    '- Hipotese: para `Procedure` muito densa ou `DataProvider` com saida muito especializada, ainda pode ser necessario buscar molde bruto comparavel adicional.'
)

$exampleTitles = @(
    '### Molde sanitizado de Procedure 1 - `PRCExemploMinimo`',
    '### Molde sanitizado de Procedure 2 - `PRCExemploParm`',
    '### Molde sanitizado de DataProvider 1 - `DPExemploLista`',
    '### Molde sanitizado de DataProvider 2 - `DPExemploParm`'
)

$exampleNotes = @(
    ((@(
        '- Perfil: `Procedure` minima, com inventario recorrente de `Part` e quase nenhum conteudo interno.',
        '- Uso operacional: boa casca para testes de serializacao, stub server-side e verificacao do envelope estrutural do tipo.'
    ) -join "`r`n")),
    ((@(
        '- Perfil: `Procedure` curta com `parm(out:...)` e variavel baseada em dominio.',
        '- Uso operacional: boa referencia para clonagem controlada quando o alvo tiver parametro simples e variavel associada.'
    ) -join "`r`n")),
    ((@(
        '- Perfil: `DataProvider` simples com saida de colecao declarada no proprio `Source`.',
        '- Uso operacional: boa referencia para saida pequena baseada em estrutura repetida.'
    ) -join "`r`n")),
    ((@(
        '- Perfil: `DataProvider` com `parm(in:...)`, `OutputCollection=True` e composicao textual mais rica no `Source`.',
        '- Uso operacional: boa referencia para `DataProvider` orientado por parametros e saida em colecao.'
    ) -join "`r`n"))
)

& $updateScript `
    -TargetMarkdown $TargetMarkdown `
    -SectionTitle '## Moldes sanitizados completos de Procedure e DataProvider' `
    -IntroLines $introLines `
    -XmlExamplePaths $XmlExamplePaths `
    -ExampleTitles $exampleTitles `
    -ExampleNotes $exampleNotes
