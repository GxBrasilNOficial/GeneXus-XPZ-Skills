#requires -Version 7.4

<#
.SYNOPSIS
    Gate consultivo: enumeracao de gates na documentação da rotina que ficou
    como subconjunto próprio do conjunto de gates que o orquestrador executa.

.DESCRIPTION
    Conserto da causa-raiz de um gap real: ao adicionar gates novos ao
    orquestrador, a tabela "Scripts do orquestrador" foi atualizada, mas uma
    OUTRA enumeracao em prosa (afirmacao fechada "os gates consultivos são X e
    Y") ficou com o conjunto antigo. A verificacao "o termo novo está presente?"
    e cega a esse caso, porque a frase defasada não cita o termo novo — cita os
    antigos. Tres revisoes perderam isso.

    Este gate deriva a VERDADE do código: extrai do orquestrador
    (scripts/Invoke-PrePushMechanicalChecks.ps1) o conjunto de scripts de gate
    que ele realmente invoca (Join-Path $PSScriptRoot 'Test-*.ps1'). Depois
    varre os .md da raiz e sinaliza qualquer LINHA que enumere >= 2 desses gates
    como um subconjunto próprio do conjunto real — candidata a enumeracao
    defasada. A tabela canonica (um gate por linha) e mencoes contextuais de um
    único gate não casam o critério ">= 2 na mesma linha".

    Consultivo (severity warn): o agente confronta cada candidata — completar a
    enumeracao, ou justificar que o subconjunto e intencional (ex.: lista só os
    gates de um tema). Invariante: a doc não deve afirmar um conjunto de gates
    que contradiz o que o orquestrador executa.

.PARAMETER RootPath
    Raiz do repositório. Default: pai de scripts/.

.PARAMETER BaseRef
    Aceito para o contrato comum dos gates; este gate e invariante (não usa diff).

.PARAMETER ChangedFiles
    Aceito para o contrato comum dos gates; não usado (verificacao e repo-wide).

.PARAMETER MaxFindings
    Teto de candidatas reportadas. Default: 30.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [ValidateRange(1, 500)]
    [int]$MaxFindings = 30,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

$orchestratorRel = 'scripts/Invoke-PrePushMechanicalChecks.ps1'
$orchestratorPath = Join-Path $resolvedRoot $orchestratorRel

$findings = [System.Collections.Generic.List[object]]::new()
$truncated = $false
$orchestratorGates = @()

if (Test-Path -LiteralPath $orchestratorPath -PathType Leaf) {
    $orchestratorText = [System.IO.File]::ReadAllText($orchestratorPath)

    # Conjunto de verdade: scripts de gate que o orquestrador invoca, EXCETO os
    # gates de parse (Test-*ScriptsParse.ps1). Estes são gates mecanicos de saude
    # do repo, sempre referenciados como par fixo e completo (parse PS + parse
    # Python) e não integram a enumeracao consultiva que a doc descreve em listas;
    # incluí-los gera falso positivo nessas co-citacoes legitimas.
    $invokeRegex = [regex]::new("Join-Path\s+\`$PSScriptRoot\s+'(?<name>Test-[A-Za-z0-9.\-]+\.ps1)'")
    $gateSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $invokeRegex.Matches($orchestratorText)) {
        $name = $m.Groups['name'].Value
        if ($name -match 'ScriptsParse\.ps1$') { continue }
        [void]$gateSet.Add($name)
    }
    $orchestratorGates = @($gateSet | Sort-Object)

    if ($orchestratorGates.Count -ge 2) {
        # Token de nome de gate-script em texto (dentro de crases, após scripts/, etc.).
        $nameTokenRegex = [regex]::new('Test-[A-Za-z0-9.\-]+\.ps1')

        $docFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.md' -ErrorAction SilentlyContinue)
        foreach ($docFile in $docFiles) {
            if ($truncated) { break }

            $lines = @()
            try {
                $lines = @([System.IO.File]::ReadAllLines($docFile.FullName))
            } catch {
                continue
            }
            $relPath = ($docFile.Name)

            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($truncated) { break }
                $text = $lines[$i]

                $onLine = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($m in $nameTokenRegex.Matches($text)) {
                    if ($gateSet.Contains($m.Value)) {
                        [void]$onLine.Add($m.Value)
                    }
                }

                # Enumeracao: >= 2 gates do conjunto, mas subconjunto próprio.
                if ($onLine.Count -lt 2) { continue }
                if ($onLine.Count -ge $orchestratorGates.Count) { continue }

                if ($findings.Count -ge $MaxFindings) {
                    $truncated = $true
                    break
                }

                $listed = @($onLine | Sort-Object)
                $missing = @($orchestratorGates | Where-Object { -not $onLine.Contains($_) })

                $findings.Add([pscustomobject][ordered]@{
                    code     = 'GATE_ENUMERATION_SUBSET'
                    severity = 'warn'
                    path     = ('{0}:{1}' -f $relPath, ($i + 1))
                    message  = ("enumera {0} de {1} gates do orquestrador ({2}); se a frase descreve o conjunto de gates, confirmar se esta completa — ausente(s): {3}" -f $onLine.Count, $orchestratorGates.Count, ($listed -join ', '), ($missing -join ', '))
                })
            }
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status            = $status
    orchestrator      = $orchestratorRel
    orchestratorGates = @($orchestratorGates)
    candidateCount    = $findings.Count
    truncated         = $truncated
    findings          = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("ORCHESTRATOR_GATES={0}" -f ($orchestratorGates -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $findings.Count)
    foreach ($finding in @($findings)) {
        Write-Output ("GATE_ENUMERATION_SUBSET: {0}: {1}" -f $finding.path, $finding.message)
    }
    if ($truncated) {
        Write-Output 'CANDIDATES_TRUNCATED=true'
    }
}

exit 0
