#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Test-PrePushTraceabilityCoverage.ps1.

.DESCRIPTION
    Monta uma raiz temporaria com um 09 sintetico e invoca o gate com -ChangedFiles
    nao-vazio (pula o git diff; o sinal de verbosidade e invariante sobre o texto do 09).
    Confirma:
      - linha de script no formato verboso antigo (rotulo `Evidencia direta` colado num
        caminho `scripts/` ou `scripts-maintenance/`) -> dispara PUBLIC_TRACEABILITY_VERBOSE_LINE;
      - ponteiro enxuto (`- `scripts/X` (categoria) -- ...`, sem rotulo) -> NAO dispara;
      - bullet de governanca que cita script com texto intermediario (": o script `scripts/...`")
        -> NAO dispara;
      - 09 totalmente enxuto -> status pass, zero findings de verbosidade.
    Os casos de assinatura usam repositorios Git temporarios para verificar fontes atual
    e legada, versao nao resolvida, afirmacoes de versao corrente, proximo bump obsoleto,
    referencias historicas e exclusao de Markdown ignorado; exige Git disponivel.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushTraceabilityCoverage.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-traceability-verbose-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
$utf8NoBom = Get-Utf8NoBomEncoding

function Write-Synthetic09 {
    param([string]$Content)
    [System.IO.File]::WriteAllText((Join-Path $tempRoot '09-inventario-e-rastreabilidade-publica.md'), $Content, $utf8NoBom)
}

function Invoke-Gate {
    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -ChangedFiles '09-inventario-e-rastreabilidade-publica.md' -AsJson 2>&1
    $script:lastExit = $LASTEXITCODE
    return (($output | Out-String).Trim() | ConvertFrom-Json)
}

try {
    # Cenario 1: dois verbosos (scripts/ e scripts-maintenance/) + tres negativos.
    Write-Synthetic09 @'
# 09 sintetico

## Nota sobre o motor operacional compartilhado

- `Evidência direta`: `scripts/FooVerboso.ps1` descreve contrato com parametros, exit codes e consumidores por extenso, duplicando o dono logico.
- `scripts/BarEnxuto.ps1` (motor) — papel em uma frase. Dono: 02. Validação: nenhum.
- `Evidência direta`: o script `scripts/BazGovernanca.ps1` e parte da infraestrutura operacional desta base; nao e ponteiro de script.
- `Evidência direta`: `scripts-maintenance/CampanhaVerbosa.ps1` implementa campanha de manutencao com prosa de contrato longa.
- `scripts-maintenance/CampanhaEnxuta.ps1` (manutenção) — campanha. Dono: 10a.
'@
    $r1 = Invoke-Gate
    if ($script:lastExit -ne 0) { throw "gate deveria sair com exit 0 (consultivo); obtido $($script:lastExit)" }
    if ($r1.status -ne 'warn') { throw "cenario 1: status deveria ser 'warn'; obtido '$($r1.status)'" }
    $verbose1 = @($r1.findings | Where-Object { $_.code -eq 'PUBLIC_TRACEABILITY_VERBOSE_LINE' })
    if ($verbose1.Count -ne 2) {
        throw ("cenario 1: deveria haver 2 PUBLIC_TRACEABILITY_VERBOSE_LINE (scripts/ + scripts-maintenance/); obtido {0}. Findings: {1}" -f $verbose1.Count, (@($r1.findings | ForEach-Object { $_.code }) -join ', '))
    }

    # Cenario 2: 09 totalmente enxuto (sem formato verboso) -> pass, zero verbosidade.
    Write-Synthetic09 @'
# 09 sintetico enxuto

## Nota sobre o motor operacional compartilhado

- `scripts/BarEnxuto.ps1` (motor) — papel em uma frase. Dono: 02. Validação: nenhum.
- `Evidência direta`: o script `scripts/BazGovernanca.ps1` e parte da infraestrutura operacional; nao e ponteiro.
- `Inferência forte`: nota de raciocinio editorial, nao e ponteiro de script.
'@
    $r2 = Invoke-Gate
    if ($script:lastExit -ne 0) { throw "gate deveria sair com exit 0 (consultivo); obtido $($script:lastExit)" }
    $verbose2 = @($r2.findings | Where-Object { $_.code -eq 'PUBLIC_TRACEABILITY_VERBOSE_LINE' })
    if ($verbose2.Count -ne 0) {
        throw ("cenario 2: 09 enxuto nao deveria disparar verbosidade; obtido {0}" -f $verbose2.Count)
    }
    if ($r2.status -ne 'pass') {
        throw ("cenario 2: status deveria ser 'pass'; obtido '$($r2.status)'. Findings: {0}" -f (@($r2.findings | ForEach-Object { $_.code }) -join ', '))
    }

    function Invoke-SignatureFixtureGit {
        param([string]$RepositoryRoot, [string[]]$Arguments)
        $gitOutput = & git -C $RepositoryRoot @Arguments 2>&1
        $gitExitCode = $LASTEXITCODE
        if ($gitExitCode -ne 0) {
            throw ("git {0} falhou no fixture: {1}" -f ($Arguments -join ' '), (@($gitOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine))
        }
    }

    function New-SignatureFixtureRepository {
        param(
            [string]$RepositoryRoot,
            [string]$BuildSource,
            [AllowNull()] [string]$SignatureSource,
            [hashtable]$Documents,
            [switch]$IgnoreTemp
        )

        $fixtureScripts = Join-Path $RepositoryRoot 'scripts'
        [void](New-Item -ItemType Directory -Path $fixtureScripts -Force)
        [System.IO.File]::WriteAllText((Join-Path $fixtureScripts 'Build-KbIntelligenceIndex.py'), $BuildSource + [Environment]::NewLine, $utf8NoBom)
        if ($null -ne $SignatureSource) {
            [System.IO.File]::WriteAllText((Join-Path $fixtureScripts 'GeneXusKbIntelligenceExtractorSignature.py'), $SignatureSource + [Environment]::NewLine, $utf8NoBom)
        }
        foreach ($document in $Documents.GetEnumerator()) {
            $documentPath = Join-Path $RepositoryRoot $document.Key
            $documentDirectory = Split-Path -Parent $documentPath
            if (-not (Test-Path -LiteralPath $documentDirectory -PathType Container)) {
                [void](New-Item -ItemType Directory -Path $documentDirectory -Force)
            }
            [System.IO.File]::WriteAllText($documentPath, [string]$document.Value + [Environment]::NewLine, $utf8NoBom)
        }
        if ($IgnoreTemp) {
            [System.IO.File]::WriteAllText((Join-Path $RepositoryRoot '.gitignore'), "Temp/$([Environment]::NewLine)", $utf8NoBom)
            [void](New-Item -ItemType Directory -Path (Join-Path $RepositoryRoot 'Temp') -Force)
            [System.IO.File]::WriteAllText((Join-Path $RepositoryRoot 'Temp/ignored.md'), 'O extrator 13 é o contrato em vigor.' + [Environment]::NewLine, $utf8NoBom)
        }

        Invoke-SignatureFixtureGit -RepositoryRoot $RepositoryRoot -Arguments @('init', '--quiet')
        Invoke-SignatureFixtureGit -RepositoryRoot $RepositoryRoot -Arguments @('config', 'user.name', 'Traceability SelfTest')
        Invoke-SignatureFixtureGit -RepositoryRoot $RepositoryRoot -Arguments @('config', 'user.email', 'traceability-selftest@example.invalid')
        Invoke-SignatureFixtureGit -RepositoryRoot $RepositoryRoot -Arguments @('add', '--', '.')
        Invoke-SignatureFixtureGit -RepositoryRoot $RepositoryRoot -Arguments @('commit', '--quiet', '-m', 'Baseline sintetica')
    }

    function Invoke-SignatureFixtureGate {
        param([string]$RepositoryRoot, [string]$ChangedFile)
        $gateOutput = & pwsh -NoProfile -File $scriptPath -RootPath $RepositoryRoot -BaseRef HEAD -ChangedFiles $ChangedFile -AsJson 2>&1
        $gateExit = $LASTEXITCODE
        if ($gateExit -ne 0) {
            throw ("gate de assinatura deveria sair com exit 0; obtido {0}: {1}" -f $gateExit, (($gateOutput | Out-String).Trim()))
        }
        return (($gateOutput | Out-String).Trim() | ConvertFrom-Json)
    }

    function Assert-SignatureStalePaths {
        param([object]$Result, [string[]]$ExpectedPaths, [string]$Scenario)
        $signatureFindings = @($Result.findings | Where-Object { $_.code -eq 'EXTRACTOR_SIGNATURE_STALE_DOC_REF' })
        $signaturePaths = @($signatureFindings | ForEach-Object { $_.path } | Sort-Object)
        $expectedSortedPaths = @($ExpectedPaths | Sort-Object)
        if ($Result.status -ne 'warn' -or $signatureFindings.Count -ne $expectedSortedPaths.Count -or ($signaturePaths -join '|') -cne ($expectedSortedPaths -join '|')) {
            throw ("{0}: paths de afirmações correntes inesperados; esperados: {1}; encontrados: {2}. Findings: {3}" -f $Scenario, ($expectedSortedPaths -join ', '), ($signaturePaths -join ', '), (@($Result.findings | ForEach-Object { $_.code + ':' + $_.path }) -join ', '))
        }
        if (@($Result.findings | Where-Object { $_.code -ne 'EXTRACTOR_SIGNATURE_STALE_DOC_REF' }).Count -gt 0) {
            throw ("{0}: findings inesperados: {1}" -f $Scenario, (@($Result.findings | ForEach-Object { $_.code }) -join ', '))
        }
    }

    # Cenario 3: versao no modulo atual, assertions diretas e somente Markdown visivel ao Git.
    $signatureRoot = Join-Path $tempRoot 'signature-fixture'
    $signatureDocuments = @{
        'current-version.md' = 'No índice atual, o extrator é 13.'
        'untracked-current-version.md' = 'Current extractor version: 13.'
        'in-force-claim.md' = 'O extrator 13 é o contrato em vigor.'
        'used-today-claim.md' = 'O motor do extrator 13 continua sendo o usado hoje.'
        'stale-next-bump.md' = 'EXTRACTOR_SIGNATURE_VERSION — atualização 2026-09-25: o valor "13" foi consumido; usar próximo bump material disponível (hoje 14).'
        'introduced-feature.md' = 'A funcionalidade foi introduzida no extrator 13.'
        'CHANGELOG.md' = '- KbIntelligence / extrator 13 (2026-09-25): Domains atualmente indexados por fullyQualifiedName.'
    }
    New-SignatureFixtureRepository -RepositoryRoot $signatureRoot -BuildSource '# synthetic build module' -SignatureSource 'EXTRACTOR_SIGNATURE_VERSION = "13"' -Documents $signatureDocuments -IgnoreTemp
    $fixtureScripts = Join-Path $signatureRoot 'scripts'
    [System.IO.File]::WriteAllText((Join-Path $fixtureScripts 'GeneXusKbIntelligenceExtractorSignature.py'), 'EXTRACTOR_SIGNATURE_VERSION = "16"' + [Environment]::NewLine, $utf8NoBom)
    $signatureGateResult = Invoke-SignatureFixtureGate -RepositoryRoot $signatureRoot -ChangedFile 'scripts/GeneXusKbIntelligenceExtractorSignature.py'
    Assert-SignatureStalePaths -Result $signatureGateResult -ExpectedPaths @('current-version.md', 'in-force-claim.md', 'stale-next-bump.md', 'untracked-current-version.md', 'used-today-claim.md') -Scenario 'cenario 3'

    # Cenario 4: a fonte legada em Build-KbIntelligenceIndex.py continua suportada.
    $legacyRoot = Join-Path $tempRoot 'legacy-signature-fixture'
    New-SignatureFixtureRepository -RepositoryRoot $legacyRoot -BuildSource 'EXTRACTOR_SIGNATURE_VERSION = "13"' -SignatureSource $null -Documents @{
        'legacy-current-version.md' = 'O extrator 13 é o contrato em vigor.'
    }
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'scripts/Build-KbIntelligenceIndex.py'), 'EXTRACTOR_SIGNATURE_VERSION = "16"' + [Environment]::NewLine, $utf8NoBom)
    $legacyResult = Invoke-SignatureFixtureGate -RepositoryRoot $legacyRoot -ChangedFile 'scripts/Build-KbIntelligenceIndex.py'
    Assert-SignatureStalePaths -Result $legacyResult -ExpectedPaths @('legacy-current-version.md') -Scenario 'cenario 4'

    # Cenario 5: sem fonte de versao na base ou no estado atual, o gate nao passa silenciosamente.
    $unresolvedRoot = Join-Path $tempRoot 'unresolved-signature-fixture'
    New-SignatureFixtureRepository -RepositoryRoot $unresolvedRoot -BuildSource '# no signature version in baseline' -SignatureSource $null -Documents @{}
    [System.IO.File]::WriteAllText((Join-Path $unresolvedRoot 'scripts/Build-KbIntelligenceIndex.py'), '# no signature version in current tree' + [Environment]::NewLine, $utf8NoBom)
    $unresolvedResult = Invoke-SignatureFixtureGate -RepositoryRoot $unresolvedRoot -ChangedFile 'scripts/Build-KbIntelligenceIndex.py'
    $unresolvedFindings = @($unresolvedResult.findings | Where-Object { $_.code -eq 'EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED' })
    if ($unresolvedResult.status -ne 'warn' -or $unresolvedFindings.Count -ne 1 -or @($unresolvedResult.findings | Where-Object { $_.code -ne 'EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED' }).Count -gt 0) {
        throw ("cenario 5: esperava apenas EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED; status/findings: {0}/{1}" -f $unresolvedResult.status, (@($unresolvedResult.findings | ForEach-Object { $_.code }) -join ', '))
    }

    Write-Output 'OK: Test-PrePushTraceabilityCoverageSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
