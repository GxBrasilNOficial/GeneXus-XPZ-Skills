#requires -Version 7.4

<#
.SYNOPSIS
    Suporte folha dos wrappers MSBuild GeneXus: leitura de contexto ativo (abertura vs efetiva),
    marcador unico de falha de task e classificador de exit do Open-GeneXusKbHeadless.ps1.

.DESCRIPTION
    Folha sem dependencia de deploy/hosting: nao carrega (nem cita) o suporte de deploy nem o
    registro de hosting kinds. E consumida diretamente por Invoke-GeneXusXpzExport.ps1,
    Invoke-GeneXusXpzImport.ps1, Test-GeneXusXpzImportPreview.ps1 e Open-GeneXusKbHeadless.ps1.
    O suporte de deploy tambem carrega esta folha, para manter
    Resolve-GeneXusKbActiveContextReadings disponivel aos wrappers de build e demais
    consumidores do suporte de deploy.

    Marcador de falha: um unico helper alimenta (a) as flags de Set dos wrappers, em modo
    tolerante (Loose, substring; igual ao legado) e (b) o exit do OpenHeadless, em modo
    estrito (ErrorSeverity: apenas `error :` com `Task` opcional, nunca os nomes PascalCase
    das tasks). A mesma fonte textual (stdout primario; stderr filtrado so quando o stdout
    nao carrega marcador `error` classificado; stdout vence em conflito) alimenta flags,
    exit e mensagens.

    Exit do OpenHeadless: cadeia de prioridade Open(20) -> SetVersion(21) -> SetEnvironment(22)
    -> Close(25). Exits 23/24 ficam RESERVADOS-SEM-RAMO (sem evidencia de marcador de falha
    proprio de Get*). Formato desconhecido -> 20. Escopo: somente o OpenHeadless usa este
    classificador; Export/Import/Preview mantem 41/31/32.
#>

Set-StrictMode -Version Latest

function Test-GeneXusMsBuildFunctionDefined {
    param([Parameter(Mandatory)][string]$Name)

    return [bool](Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue)
}

# Guarda contra dupla definicao: se a folha ja foi carregada nesta sessao, nao redefine
# (garante carga idempotente quando o suporte de deploy e um wrapper direto carregam a folha).
if (Test-GeneXusMsBuildFunctionDefined -Name 'Resolve-GeneXusMsBuildFailureMarker') {
    return
}

function Resolve-GeneXusKbActiveContextReadings {
    <#
    .SYNOPSIS
        Separa a leitura de abertura e a leitura efetiva de GetActiveVersion/GetActiveEnvironment no stdout do MSBuild.
    .DESCRIPTION
        Os wrappers de build leem o contexto ativo antes de SetActiveVersion/SetActiveEnvironment (para citar,
        em caso de falha do Set, o contexto que estava ativo na abertura) e de novo depois dos Set (contexto
        efetivo da operacao). A primeira leitura e a de abertura; a ultima, a efetiva. Com uma unica leitura,
        ela so vale como efetiva quando nenhuma troca foi pedida ou quando o Set correspondente falhou
        (o contexto nao mudou); caso contrario a troca pode ter ocorrido sem leitura posterior e o efetivo
        fica nulo, para nao reportar o contexto anterior a troca como se fosse o da operacao.
    #>
    param(
        [AllowNull()][string]$Text,
        [string]$Pattern,
        [AllowNull()][string]$RequestedName,
        [bool]$SetFailed = $false
    )

    $readings = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrEmpty($Text)) {
        foreach ($match in [regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $readings.Add($match.Groups[1].Value.Trim()) | Out-Null
        }
    }

    $atOpen = $null
    $effective = $null
    if ($readings.Count -gt 0) {
        $atOpen = $readings[0]
    }
    if ($readings.Count -ge 2) {
        $effective = $readings[$readings.Count - 1]
    }
    elseif ($readings.Count -eq 1 -and ([string]::IsNullOrWhiteSpace($RequestedName) -or $SetFailed)) {
        $effective = $readings[0]
    }

    return [pscustomobject][ordered]@{
        AtOpen       = $atOpen
        Effective    = $effective
        ReadingCount = $readings.Count
    }
}

function Get-GeneXusMsBuildFailureMarkerLabel {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Open', 'Close', 'SetVersion', 'SetEnvironment')]
        [string]$Kind
    )

    switch ($Kind) {
        'Open' { return 'Open Knowledge Base' }
        'Close' { return 'Close Knowledge Base' }
        'SetVersion' { return 'Set Active Version' }
        'SetEnvironment' { return 'Set Active Environment' }
    }
}

function Get-GeneXusMsBuildFailureMarkerPattern {
    <#
    .SYNOPSIS
        Constroi o regex de marcador de falha por task, em modo tolerante ou por severidade error.
    .DESCRIPTION
        Loose: substring `'<label>' falhou` (mesma deteccao tolerante do legado; alimenta as flags).
        ErrorSeverity: `error : > '<label>'[ Task] falhou` (so severidade error, Task opcional;
        alimenta o classificador de exit). Nunca usa os nomes PascalCase das tasks.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Open', 'Close', 'SetVersion', 'SetEnvironment')]
        [string]$Kind,

        [ValidateSet('Loose', 'ErrorSeverity')]
        [string]$MatchMode = 'Loose'
    )

    $escapedLabel = [regex]::Escape((Get-GeneXusMsBuildFailureMarkerLabel -Kind $Kind))
    if ($MatchMode -eq 'ErrorSeverity') {
        return ('(?i)error\s*:\s*>\s*' + $escapedLabel + '(\s+Task)?\s+falhou')
    }

    return ('(?i)' + $escapedLabel + '\s+falhou')
}

function Resolve-GeneXusMsBuildFailureMarker {
    <#
    .SYNOPSIS
        Deteccao unica de marcadores de falha de task no log MSBuild GeneXus.
    .DESCRIPTION
        Devolve, por task, o match tolerante (Loose) e o match estrito por severidade error
        (ErrorSeverity). Consumido pelas flags (Loose) e pelo classificador de exit
        (ErrorSeverity). O mesmo padrao, com o mesmo motor case-insensitive, e aplicado em toda
        a varredura, evitando a divergencia -match (case-insensitive) x [regex]::Match
        (case-sensitive).
    #>
    param(
        [AllowNull()][string]$Text,

        [ValidateSet('Open', 'Close', 'SetVersion', 'SetEnvironment')]
        [string[]]$Kind = @('Open', 'Close', 'SetVersion', 'SetEnvironment')
    )

    $result = [ordered]@{}
    foreach ($currentKind in $Kind) {
        $loose = $false
        $strict = $false
        if (-not [string]::IsNullOrEmpty($Text)) {
            $loose = [regex]::IsMatch($Text, (Get-GeneXusMsBuildFailureMarkerPattern -Kind $currentKind -MatchMode 'Loose'))
            $strict = [regex]::IsMatch($Text, (Get-GeneXusMsBuildFailureMarkerPattern -Kind $currentKind -MatchMode 'ErrorSeverity'))
        }

        $result[$currentKind] = [pscustomobject][ordered]@{
            Loose         = $loose
            ErrorSeverity = $strict
        }
    }

    return $result
}

function Resolve-GeneXusMsBuildDiagnosticSource {
    <#
    .SYNOPSIS
        Seleciona a fonte textual que alimenta flags, exit e mensagens.
    .DESCRIPTION
        stdout e primario; o stderr filtrado so e usado quando o stdout nao carrega marcador
        `error` classificado (algum dos quatro kinds em severidade error); em conflito, stdout
        vence. Warnings nao contam como marcador.
    #>
    param(
        [AllowNull()][string]$StdOutText,
        [AllowNull()][string]$StdErrFilteredText
    )

    $stdOutMarkers = Resolve-GeneXusMsBuildFailureMarker -Text $StdOutText
    $stdErrMarkers = Resolve-GeneXusMsBuildFailureMarker -Text $StdErrFilteredText

    $stdOutHasError = $false
    foreach ($kind in $stdOutMarkers.Keys) {
        if ($stdOutMarkers[$kind].ErrorSeverity) { $stdOutHasError = $true; break }
    }

    $stdErrHasError = $false
    foreach ($kind in $stdErrMarkers.Keys) {
        if ($stdErrMarkers[$kind].ErrorSeverity) { $stdErrHasError = $true; break }
    }

    if ($stdOutHasError) {
        return [pscustomobject][ordered]@{
            SelectedText              = $StdOutText
            Source                    = 'stdout'
            StdOutHasClassifiedError  = $true
            StdErrHasClassifiedError  = $stdErrHasError
        }
    }

    if ($stdErrHasError) {
        return [pscustomobject][ordered]@{
            SelectedText              = $StdErrFilteredText
            Source                    = 'stderr'
            StdOutHasClassifiedError  = $false
            StdErrHasClassifiedError  = $true
        }
    }

    return [pscustomobject][ordered]@{
        SelectedText              = $StdOutText
        Source                    = 'stdout'
        StdOutHasClassifiedError  = $false
        StdErrHasClassifiedError  = $false
    }
}

function Get-GeneXusMsBuildOperationExitCode {
    <#
    .SYNOPSIS
        Classifica o exit do Open-GeneXusKbHeadless.ps1 pela linha de falha (cadeia de prioridade).
    .DESCRIPTION
        Diferente do legado (que casava o nome da task em qualquer parte do log, inclusive linhas
        de sucesso `> GetActiveEnvironment Sucesso`), este classificador so reconhece marcadores
        com severidade error e aplica a cadeia Open(20) -> SetVersion(21) -> SetEnvironment(22)
        -> Close(25). Exits 23/24 ficam reservados (sem ramo). Formato desconhecido -> 20.
    #>
    param(
        [int]$MsBuildExitCode,
        [AllowNull()][string]$StdOutText,
        [AllowNull()][string]$StdErrFilteredText
    )

    if ($MsBuildExitCode -eq 0) {
        return 0
    }

    $source = Resolve-GeneXusMsBuildDiagnosticSource -StdOutText $StdOutText -StdErrFilteredText $StdErrFilteredText
    $markers = Resolve-GeneXusMsBuildFailureMarker -Text $source.SelectedText

    if ($markers['Open'].ErrorSeverity) { return 20 }
    if ($markers['SetVersion'].ErrorSeverity) { return 21 }
    if ($markers['SetEnvironment'].ErrorSeverity) { return 22 }
    if ($markers['Close'].ErrorSeverity) { return 25 }
    return 20
}
