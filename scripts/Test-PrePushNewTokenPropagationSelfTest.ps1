#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Test-PrePushNewTokenPropagation.ps1.

.DESCRIPTION
    Monta um repositório git temporario que reproduz a estrutura do gap real
    (frente de padronizacao JSON XPZ): um motor ganha o alias -ObjectList
    co-localizado com -ObjectNames/-ObjectGuids (transicao no diff), enquanto um
    exemplo continua mencionando o conjunto antigo sem o alias novo. Confirma:
      - caso positivo: a mencao defasada vira candidata (status=warn);
      - controle negativo: mencao já propagada não vira candidata;
      - declaracao do próprio parâmetro (.PARAMETER) não vira candidata;
      - classificação de forma (mentionClass): prosa corrida -> 'prose',
        item de lista de parâmetros -> 'param-list-item', linha em bloco de
        código cercado -> 'command-example';
      - truncamento ciente de classe: com teto baixo e prosa abundante, a
        prosa e limitada (truncatedProseCount > 0) mas a candidata nao-prosa
        sobrevive ao truncamento;
      - universo VERSIONADO da varredura: mencao defasada em arquivo ignorado
        pelo .gitignore (Temp/, node_modules/) ou apenas nao rastreado NAO vira
        candidata, enquanto a mencao versionada equivalente continua virando —
        trava a regressao de voltar ao walk de filesystem, que inflava o
        livro-razao de vereditos com material que nao e documento do repo.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushNewTokenPropagation.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-newtoken-propagation-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
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

    # --- Estado base: sem -ObjectList ---
    $motorBase = @'
[CmdletBinding()]
param(
    [string[]]$ObjectNames,
    [string[]]$ObjectGuids
)
<#
.PARAMETER ObjectNames
Nomes de objetos a copiar.
#>
# Quando -ObjectNames ou -ObjectGuids e fornecido, so os listados sao copiados.
if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) { $usaGuids = $true }
'@
    Write-TempFile -RelativePath 'motor.ps1' -Content $motorBase

    # Mencao equivalente que ficara defasada (sem ObjectList).
    Write-TempFile -RelativePath 'exemplo.md' -Content "Quando ObjectNames ou ObjectGuids e informado, faz seed do objeto.`n"

    # Controle negativo: mencao já propagada.
    Write-TempFile -RelativePath 'ok-doc.md' -Content "Use ObjectList, ObjectNames ou ObjectGuids para selecionar objetos.`n"

    # Mencao defasada em item de lista de parâmetros (classe param-list-item).
    $paramListDoc = @'
Parametros:

- `-ObjectNames` nomes de objetos a copiar
'@
    Write-TempFile -RelativePath 'param-list.md' -Content ($paramListDoc + "`n")

    # Mencao defasada dentro de bloco de código cercado (classe command-example).
    $cmdDoc = @'
Exemplo de comando:

```text
& ./motor.ps1 -ObjectNames Proc:Foo
```
'@
    Write-TempFile -RelativePath 'cmd.md' -Content ($cmdDoc + "`n")

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'base'))
    $baseSha = (Invoke-TempGit @('rev-parse', 'HEAD') | Out-String).Trim()

    # --- HEAD: introduz -ObjectList co-localizado (transicao) ---
    $motorHead = @'
[CmdletBinding()]
param(
    [string[]]$ObjectList,
    [string[]]$ObjectNames,
    [string[]]$ObjectGuids
)
<#
.PARAMETER ObjectList
Alias operacional.
.PARAMETER ObjectNames
Nomes de objetos a copiar.
#>
# Quando -ObjectList, -ObjectNames ou -ObjectGuids e fornecido, so os listados sao copiados.
if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) { $usaGuids = $true }
'@
    Write-TempFile -RelativePath 'motor.ps1' -Content $motorHead
    # exemplo.md e ok-doc.md permanecem inalterados.

    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'introduz ObjectList'))

    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -BaseRef $baseSha -AsJson 2>&1
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    $result = $jsonText | ConvertFrom-Json

    if ($exitCode -ne 0) {
        throw "gate deveria sair com exit 0 (consultivo); obtido $exitCode. Saida: $jsonText"
    }
    if ($result.status -ne 'warn') {
        throw "status deveria ser 'warn' (ha mencao defasada); obtido '$($result.status)'. Saida: $jsonText"
    }
    if (@($result.introducedTokens) -notcontains 'ObjectList') {
        throw "introducedTokens deveria conter 'ObjectList'; obtido: $(@($result.introducedTokens) -join ', ')"
    }

    $candidatePaths = @($result.findings | ForEach-Object { $_.path })
    $exemploHit = @($candidatePaths | Where-Object { $_ -like 'exemplo.md:*' })
    if ($exemploHit.Count -eq 0) {
        throw "exemplo.md (mencao defasada) deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }

    $okHit = @($candidatePaths | Where-Object { $_ -like 'ok-doc.md:*' })
    if ($okHit.Count -ne 0) {
        throw "ok-doc.md (controle negativo, ja propagado) NAO deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }

    $motorHit = @($candidatePaths | Where-Object { $_ -like 'motor.ps1:*' })
    if ($motorHit.Count -ne 0) {
        throw "motor.ps1 nao deveria gerar candidata (descricao ja propagada; .PARAMETER e declaracao filtrados); candidatas: $($candidatePaths -join ', ')"
    }

    # --- Classificação de forma (mentionClass) ---
    $exemploFinding = @($result.findings | Where-Object { $_.path -like 'exemplo.md:*' })[0]
    if ($exemploFinding.mentionClass -ne 'prose') {
        throw "exemplo.md deveria ter mentionClass='prose'; obtido '$($exemploFinding.mentionClass)'"
    }

    $paramListFinding = @($result.findings | Where-Object { $_.path -like 'param-list.md:*' })
    if ($paramListFinding.Count -eq 0) {
        throw "param-list.md (item de lista defasado) deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }
    if ($paramListFinding[0].mentionClass -ne 'param-list-item') {
        throw "param-list.md deveria ter mentionClass='param-list-item'; obtido '$($paramListFinding[0].mentionClass)'"
    }

    $cmdFinding = @($result.findings | Where-Object { $_.path -like 'cmd.md:*' })
    if ($cmdFinding.Count -eq 0) {
        throw "cmd.md (linha em bloco cercado) deveria virar candidata; candidatas: $($candidatePaths -join ', ')"
    }
    if ($cmdFinding[0].mentionClass -ne 'command-example') {
        throw "cmd.md deveria ter mentionClass='command-example'; obtido '$($cmdFinding[0].mentionClass)'"
    }

    # --- Truncamento ciente de classe: prosa e limitada, nao-prosa nunca ---
    # Acrescenta prosa abundante e roda com teto baixo (-MaxFindings 2); confirma
    # que a candidata param-list-item (param-list.md) sobrevive ao truncamento e
    # que a prosa respeita o teto.
    Write-TempFile -RelativePath 'prose-a.md' -Content "Veja ObjectNames para detalhes do fluxo.`n"
    Write-TempFile -RelativePath 'prose-b.md' -Content "O fluxo usa ObjectNames neste ponto.`n"
    Write-TempFile -RelativePath 'prose-c.md' -Content "Confira ObjectNames antes do seed.`n"
    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'prosa abundante'))

    $truncOutput = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -BaseRef $baseSha -AsJson -MaxFindings 2 2>&1
    $truncResult = (($truncOutput | Out-String).Trim()) | ConvertFrom-Json

    if (-not $truncResult.truncated) {
        throw "com -MaxFindings 2 e prosa abundante, truncated deveria ser true"
    }
    if ($truncResult.truncatedProseCount -lt 1) {
        throw "truncatedProseCount deveria ser >= 1; obtido $($truncResult.truncatedProseCount)"
    }
    $proseKept = @($truncResult.findings | Where-Object { $_.mentionClass -eq 'prose' })
    if ($proseKept.Count -gt 2) {
        throw "prosa retida deveria respeitar o teto (<=2); obtido $($proseKept.Count)"
    }
    $truncPaths = @($truncResult.findings | ForEach-Object { $_.path })
    $paramListKept = @($truncPaths | Where-Object { $_ -like 'param-list.md:*' })
    if ($paramListKept.Count -eq 0) {
        throw "candidata param-list-item NAO deveria ser truncada pelo teto; ausente em: $($truncPaths -join ', ')"
    }

    # --- Universo VERSIONADO: ignorado/nao rastreado fica fora da varredura ---
    # A varredura usa `git ls-files`; material ignorado (rascunho de rodada em
    # Temp/, dependencia vendorizada em node_modules/) ou apenas nao rastreado
    # nao e documento do repositório: nao pode ficar defasado num push e so
    # inflaria o livro-razao de vereditos exigido pelo orquestrador.
    Write-TempFile -RelativePath '.gitignore' -Content "Temp/`nnode_modules/`n"
    Write-TempFile -RelativePath 'Temp/rascunho.md' -Content "Rascunho: use ObjectNames por enquanto.`n"
    Write-TempFile -RelativePath 'node_modules/vendor.md' -Content "Vendor doc mentions ObjectNames only.`n"
    # Nao ignorado, mas nunca adicionado ao indice (apenas nao rastreado).
    Write-TempFile -RelativePath 'nao-rastreado.md' -Content "Nota solta citando ObjectNames.`n"
    [void](Invoke-TempGit @('add', '.gitignore'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'ignora Temp e node_modules'))

    $trackedOutput = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -BaseRef $baseSha -AsJson 2>&1
    $trackedResult = (($trackedOutput | Out-String).Trim()) | ConvertFrom-Json
    $trackedPaths = @($trackedResult.findings | ForEach-Object { $_.path })

    foreach ($fora in @('rascunho.md', 'vendor.md', 'nao-rastreado.md')) {
        $hit = @($trackedPaths | Where-Object { $_ -like "*$fora*" })
        if ($hit.Count -ne 0) {
            throw "$fora nao e versionado e NAO deveria virar candidata (regressao para o walk de filesystem); candidatas: $($trackedPaths -join ', ')"
        }
    }

    # Controle positivo do mesmo run: a mencao VERSIONADA equivalente continua
    # virando candidata — prova que a varredura nao ficou vazia por acidente.
    $versionadoHit = @($trackedPaths | Where-Object { $_ -like 'exemplo.md:*' })
    if ($versionadoHit.Count -eq 0) {
        throw "exemplo.md (mencao defasada VERSIONADA) deveria continuar candidata; candidatas: $($trackedPaths -join ', ')"
    }

    Write-Output 'OK: Test-PrePushNewTokenPropagationSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
