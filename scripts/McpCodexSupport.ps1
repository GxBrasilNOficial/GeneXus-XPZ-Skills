#requires -Version 7.4

<#
.SYNOPSIS
    Adaptador Codex da skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Grava o bloco [mcp_servers.jev] entre marcadores de comentario proprios da
    skill, sem biblioteca TOML de edicao. Deteccao e validacao usam o tomllib
    da biblioteca padrao do Python 3.11+ (somente leitura). Sem Python 3.11+ o
    Codex cai em edicao_manual_necessaria com o trecho pronto.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:McpCodexSupportDir = Split-Path -Parent $PSCommandPath
. (Join-Path $script:McpCodexSupportDir 'McpIntegrationSupport.ps1')
. (Join-Path $script:McpCodexSupportDir 'McpLauncherSupport.ps1')

$script:McpCodexOpenMarker = '# >>> xpz-mcp-integrations-setup:jev >>>'
$script:McpCodexCloseMarker = '# <<< xpz-mcp-integrations-setup:jev <<<'

function Get-McpCodexConfigPath {
    return (Join-Path (Get-McpProfileRoot) '.codex\config.toml')
}

function Get-McpCodexMarkers {
    return [pscustomobject]@{
        Open  = $script:McpCodexOpenMarker
        Close = $script:McpCodexCloseMarker
    }
}

function ConvertTo-McpTomlString {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
    $escaped = $Value.Replace('\', '\\')
    $escaped = $escaped.Replace('"', '\"')
    $escaped = $escaped.Replace("`r", '\r')
    $escaped = $escaped.Replace("`n", '\n')
    $escaped = $escaped.Replace("`t", '\t')
    return '"' + $escaped + '"'
}

function ConvertTo-McpTomlArray {
    param([Parameter(Mandatory = $true)][string[]]$Values)
    $parts = @($Values | ForEach-Object { ConvertTo-McpTomlString -Value $_ })
    return '[' + ($parts -join ', ') + ']'
}

function New-McpCodexBlockText {
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [string]$NewLine = "`n"
    )
    $markers = Get-McpCodexMarkers
    $command = ConvertTo-McpTomlString -Value 'pwsh'
    $args = ConvertTo-McpTomlArray -Values @('-NoProfile', '-File', $LauncherPath)
    $envTable = '{ JEV_API_BASE_URL = ' + (ConvertTo-McpTomlString -Value $BaseUrl) +
        ', JEV_MCP_MODEL = ' + (ConvertTo-McpTomlString -Value $Model) + ' }'
    $lines = @(
        $markers.Open
        '[mcp_servers.jev]'
        ('command = ' + $command)
        ('args = ' + $args)
        ('env = ' + $envTable)
        $markers.Close
    )
    return ($lines -join $NewLine)
}

function Get-McpCodexExpectedEntry {
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model
    )
    return [ordered]@{
        command = 'pwsh'
        args    = @('-NoProfile', '-File', $LauncherPath)
        env     = [ordered]@{
            JEV_API_BASE_URL = $BaseUrl
            JEV_MCP_MODEL    = $Model
        }
    }
}

function Join-McpNormalizedLines {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowNull()][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$NewLine
    )
    $clean = @($Lines | ForEach-Object { $_.TrimEnd("`r") })
    return ($clean -join $NewLine)
}

function Get-McpCodexBlockContentFromText {
    param([Parameter(Mandatory = $true)][string]$BlockText)
    $lines = @($BlockText -split "`n")
    if ($lines.Count -lt 3) { return '' }
    return (($lines[1..($lines.Count - 2)]) -join "`n")
}

function Get-McpCodexBlockInfo {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $markers = Get-McpCodexMarkers
    $lines = @($Text -split "`n")
    $openLines = @()
    $closeLines = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd("`r")
        if ($line -ceq $markers.Open) { $openLines += $i }
        elseif ($line -ceq $markers.Close) { $closeLines += $i }
    }
    if ($openLines.Count -eq 0 -and $closeLines.Count -eq 0) {
        return [pscustomobject]@{
            state       = 'absent'
            openLine    = $null
            closeLine   = $null
            content     = $null
            contentHash = $null
            lines       = $lines
        }
    }
    if ($openLines.Count -ne 1 -or $closeLines.Count -ne 1 -or $closeLines[0] -le $openLines[0]) {
        return [pscustomobject]@{
            state       = 'unbalanced'
            openLine    = $openLines
            closeLine   = $closeLines
            content     = $null
            contentHash = $null
            lines       = $lines
        }
    }
    $contentLines = @()
    for ($i = $openLines[0] + 1; $i -lt $closeLines[0]; $i++) {
        $contentLines += $lines[$i].TrimEnd("`r")
    }
    $content = $contentLines -join "`n"
    return [pscustomobject]@{
        state       = 'present'
        openLine    = $openLines[0]
        closeLine   = $closeLines[0]
        content     = $content
        contentHash = Get-McpTextHash -Text $content
        lines       = $lines
    }
}

function Get-McpCodexHeaderScan {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $lines = @($Text -split "`n")
    $exactHeaders = @()
    $subHeaders = @()
    $otherHeaders = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd("`r").Trim()
        if ($line -ceq '[mcp_servers.jev]') {
            $exactHeaders += $i
        } elseif ($line.StartsWith('[mcp_servers.jev.')) {
            $subHeaders += $i
        } elseif ($line -match '^\[\s*mcp_servers\s*\.\s*[''"]?jev[''"]?\s*[\].]') {
            # Cobre [ mcp_servers.jev ], [mcp_servers.'jev'], etc.
            $otherHeaders += $i
        }
    }
    return [pscustomobject]@{
        ExactHeaders = $exactHeaders
        SubHeaders   = $subHeaders
        OtherHeaders = $otherHeaders
    }
}

function Test-McpCodexTextLooksLikeJev {
    <#
    .SYNOPSIS
        Heuristica textual de entrada jev no TOML do Codex (sem tomllib).
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if ($Text -match 'xpz-mcp-integrations-setup:jev') { return $true }
    $scan = Get-McpCodexHeaderScan -Text $Text
    if ($scan.ExactHeaders.Count -gt 0 -or $scan.SubHeaders.Count -gt 0 -or $scan.OtherHeaders.Count -gt 0) {
        return $true
    }
    # Chave pontilhada / aspas: mcp_servers.jev / mcp_servers.'jev'
    if ($Text -match 'mcp_servers\s*\.\s*[''"]?jev[''"]?') { return $true }
    # Tabela inline: mcp_servers = { jev = { ... } }
    if ($Text -match 'mcp_servers\s*=\s*\{[\s\S]*?\bjev\b') { return $true }
    # Subchaves sob [mcp_servers]: jev.command / jev = / "jev" =
    if ($Text -match '(?ms)\[\s*mcp_servers\s*\].*?^\s*[''"]?jev[''"]?\s*[.=]') { return $true }
    return $false
}

function Test-McpCodexConfigHoldsJev {
    <#
    .SYNOPSIS
        Decide se o config.toml do Codex ainda referencia jev (live hold).
    .DESCRIPTION
        Prefer tomllib; sem Python, usa heuristica e fail-closed se houver
        mcp_servers sem como provar ausencia de jev.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)]$Probe,
        [Parameter(Mandatory = $true)][string]$BlockState
    )
    if ($BlockState -eq 'present') { return $true }
    if ($Probe.Ok -and [bool]$Probe.HasJev) { return $true }
    if (Test-McpCodexTextLooksLikeJev -Text $Text) { return $true }
    if (-not $Probe.Ok -and [string]$Probe.Status -eq 'python_indisponivel' -and $Text -match 'mcp_servers') {
        # Sem tomllib nao da para provar que mcp_servers nao esconde jev.
        return $true
    }
    return $false
}

function Invoke-McpTomlProbe {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $prerequisites = Get-McpPrerequisites
    if (-not $prerequisites.PythonCompatible) {
        return [pscustomobject]@{
            Status  = 'python_indisponivel'
            Ok      = $false
            Error   = 'Python 3.11+ nao encontrado'
            HasJev  = $null
            CanonicalJson = $null
        }
    }
    $probeScript = Join-Path $script:McpCodexSupportDir 'McpTomlProbe.py'
    if (-not (Test-McpRegularFile -Path $probeScript)) {
        return [pscustomobject]@{
            Status  = 'probe_ausente'
            Ok      = $false
            Error   = "probe Python ausente: $probeScript"
            HasJev  = $null
            CanonicalJson = $null
        }
    }
    # O TOML segue pela entrada padrao do probe (UTF-8 sem BOM): nunca vai para disco.
    $proc = $null
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = [string]$prerequisites.Python.Path
        $psi.ArgumentList.Add([string]$probeScript)
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardInputEncoding = [System.Text.UTF8Encoding]::new($false)
        $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $proc.StandardInput.Write($Text)
        $proc.StandardInput.Close()
        $proc.WaitForExit()
        $stdoutText = [string]$stdoutTask.GetAwaiter().GetResult()
        $null = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $proc.ExitCode
        $textOutput = $stdoutText.Trim()
        if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($textOutput)) {
            return [pscustomobject]@{
                Status  = 'probe_falhou'
                Ok      = $false
                Error   = "probe Python saiu com exit $exitCode"
                HasJev  = $null
                CanonicalJson = $null
            }
        }
        try {
            $parsed = $textOutput | ConvertFrom-Json -AsHashtable
        } catch {
            return [pscustomobject]@{
                Status  = 'probe_falhou'
                Ok      = $false
                Error   = 'probe Python devolveu JSON invalido'
                HasJev  = $null
                CanonicalJson = $null
            }
        }
        return [pscustomobject]@{
            Status        = 'ok'
            Ok            = [bool]$parsed.ok
            Error         = $(if ($parsed.ContainsKey('error')) { [string]$parsed.error } else { $null })
            HasJev        = $(if ($parsed.ContainsKey('hasJev')) { [bool]$parsed.hasJev } else { $false })
            CanonicalJson = $(if ($parsed.ContainsKey('canonicalJson')) { [string]$parsed.canonicalJson } else { $null })
        }
    } finally {
        if ($null -ne $proc) { $proc.Dispose() }
    }
}

function ConvertFrom-McpCanonicalJson {
    param([Parameter(Mandatory = $true)][string]$Json)
    return ($Json | ConvertFrom-Json -AsHashtable)
}

function Remove-McpCodexSection {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )
    $lines = @($Text -split "`n")
    $scan = Get-McpCodexHeaderScan -Text $Text
    if ($scan.ExactHeaders.Count -ne 1) {
        return $null
    }
    if ($scan.OtherHeaders.Count -gt 0) {
        return $null
    }
    $start = $scan.ExactHeaders[0]
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd("`r").Trim()
        if ($line.StartsWith('[') -and -not $line.StartsWith('[mcp_servers.jev.')) {
            $end = $i
            break
        }
    }
    $kept = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -lt $start -or $i -ge $end) {
            $kept += $lines[$i]
        }
    }
    return ($kept -join "`n")
}

function Update-McpCodexConfig {
    <#
    .SYNOPSIS
        Insere, substitui, migra ou remove o bloco [mcp_servers.jev] do Codex.

    .OUTPUTS
        PSCustomObject com status em unchanged|written|planned|manual|conflict|python_indisponivel.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [string[]]$ManifestHashes = @(),
        [ValidateSet('auto', 'install', 'remove', 'migrate')][string]$Action = 'auto',
        [switch]$MigrateLegacy,
        [switch]$WhatIf
    )

    $document = Read-McpTextDocument -Path $Path
    $eol = $document.NewLine
    $snippet = New-McpCodexBlockText -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model -NewLine "`n"
    $originalProbe = Invoke-McpTomlProbe -Text $document.Text
    if ($originalProbe.Status -eq 'python_indisponivel') {
        return [pscustomobject]@{
            status  = 'python_indisponivel'
            path    = $Path
            action  = $Action
            reason  = $originalProbe.Error
            written = $false
            snippet = $snippet
        }
    }
    if (-not $originalProbe.Ok) {
        return [pscustomobject]@{
            status  = 'entrada_quebrada'
            path    = $Path
            action  = $Action
            reason  = $originalProbe.Error
            written = $false
            snippet = $snippet
        }
    }

    $block = Get-McpCodexBlockInfo -Text $document.Text
    if ($block.state -eq 'unbalanced') {
        return [pscustomobject]@{
            status  = 'entrada_em_conflito'
            path    = $Path
            action  = $Action
            reason  = 'marcadores do bloco jev desbalanceados ou duplicados'
            written = $false
            snippet = $snippet
        }
    }

    $expectedBlockText = New-McpCodexBlockText -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model -NewLine "`n"
    $expectedBlockContent = Get-McpCodexBlockContentFromText -BlockText $expectedBlockText
    $expectedBlockHash = Get-McpTextHash -Text $expectedBlockContent
    $newText = $document.Text
    $effectiveAction = $Action
    if ($Action -eq 'auto') {
        if ($block.state -eq 'present') { $effectiveAction = 'install' }
        elseif ($originalProbe.HasJev) { $effectiveAction = 'migrate' }
        else { $effectiveAction = 'install' }
    }

    if ($effectiveAction -in @('install', 'migrate')) {
        if ($block.state -eq 'present') {
            if ($block.contentHash -eq $expectedBlockHash) {
                return [pscustomobject]@{
                    status           = 'unchanged'
                    path             = $Path
                    action           = 'install'
                    entryHash        = $block.contentHash
                    expectedHash     = $expectedBlockHash
                    documentHash     = $document.Hash
                    written          = $false
                }
            }
            if ($ManifestHashes -notcontains $block.contentHash) {
                return [pscustomobject]@{
                    status  = 'entrada_em_conflito'
                    path    = $Path
                    action  = 'install'
                    reason  = 'conteudo entre os marcadores nao e byte-identico a um bloco emitido'
                    written = $false
                    snippet = $snippet
                }
            }
            $lines = @($document.Text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
            $newLines = @()
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($i -eq $block.openLine -or $i -eq $block.closeLine) {
                    $newLines += $lines[$i]
                    continue
                }
                if ($i -gt $block.openLine -and $i -lt $block.closeLine) {
                    if ($i -eq $block.openLine + 1) {
                        # Substitui apenas o conteudo; os marcadores originais
                        # permanecem nas linhas openLine/closeLine.
                        $newLines += @($expectedBlockContent -split "`n")
                    }
                    continue
                }
                $newLines += $lines[$i]
            }
            $newText = Join-McpNormalizedLines -Lines $newLines -NewLine $eol
        } else {
            $scan = Get-McpCodexHeaderScan -Text $document.Text
            if ($originalProbe.HasJev) {
                # Grafia nao migravel (ex.: mcp_servers.jev.command) antes de
                # sugerir -MigrateLegacy — paridade com Get-McpCodexState.
                $migratable = ($scan.ExactHeaders.Count -eq 1 -and $scan.OtherHeaders.Count -eq 0)
                if (-not $migratable) {
                    return [pscustomobject]@{
                        status  = 'entrada_em_conflito'
                        path    = $Path
                        action  = 'migrate'
                        reason  = 'entrada manual em grafia diferente de um unico [mcp_servers.jev]; remova a mao'
                        written = $false
                        snippet = $snippet
                    }
                }
                if (-not $MigrateLegacy -and $Action -ne 'migrate') {
                    return [pscustomobject]@{
                        status  = 'manual'
                        path    = $Path
                        action  = 'migrate'
                        reason  = 'entrada manual mcp_servers.jev exige aprovacao explicita para migrar'
                        written = $false
                        snippet = $snippet
                    }
                }
                $withoutSection = Remove-McpCodexSection -Text $document.Text
                if ($null -eq $withoutSection) {
                    return [pscustomobject]@{
                        status  = 'entrada_em_conflito'
                        path    = $Path
                        action  = 'migrate'
                        reason  = 'secao manual nao pode ser removida com seguranca'
                        written = $false
                        snippet = $snippet
                    }
                }
                $base = ($withoutSection -replace "`r`n", "`n").TrimEnd("`n")
                $newText = $base + $eol + $eol + ($expectedBlockText -replace "`n", $eol)
            } else {
                $base = $document.Text.TrimEnd("`r", "`n")
                if ([string]::IsNullOrWhiteSpace($base)) {
                    $newText = ($expectedBlockText -replace "`n", $eol) + $eol
                } else {
                    $newText = $base + $eol + $eol + ($expectedBlockText -replace "`n", $eol) + $eol
                }
            }
        }
    } elseif ($effectiveAction -eq 'remove') {
        if ($block.state -eq 'absent') {
            if ($originalProbe.HasJev) {
                return [pscustomobject]@{
                    status  = 'entrada_em_conflito'
                    path    = $Path
                    action  = 'remove'
                    reason  = 'entrada mcp_servers.jev sem marcadores da skill; remocao recusada'
                    written = $false
                    snippet = $snippet
                }
            }
            return [pscustomobject]@{ status = 'unchanged'; path = $Path; action = 'remove'; written = $false }
        }
        if ($block.contentHash -ne $expectedBlockHash -and $ManifestHashes -notcontains $block.contentHash) {
            return [pscustomobject]@{
                status  = 'entrada_em_conflito'
                path    = $Path
                action  = 'remove'
                reason  = 'bloco nao reconhecido pelo manifesto; remocao recusada'
                written = $false
                snippet = $snippet
            }
        }
        $lines = @($document.Text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
        $kept = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -ge $block.openLine -and $i -le $block.closeLine) { continue }
            $kept += $lines[$i]
        }
        $newText = (Join-McpNormalizedLines -Lines $kept -NewLine $eol).TrimEnd("`r", "`n") + $eol
    } else {
        return [pscustomobject]@{ status = 'entrada_em_conflito'; path = $Path; action = $effectiveAction; reason = 'acao invalida'; written = $false }
    }

    # Pos-validacao pelo tomllib: parse, conjunto igual fora de mcp_servers.jev
    # e entrada final exatamente igual ao objeto emitido.
    $newProbe = Invoke-McpTomlProbe -Text $newText
    if (-not $newProbe.Ok) {
        return [pscustomobject]@{
            status  = 'edicao_manual_necessaria'
            path    = $Path
            action  = $effectiveAction
            reason  = 'texto resultante nao parseia: ' + $newProbe.Error
            written = $false
            snippet = $snippet
        }
    }
    $originalObject = ConvertFrom-McpCanonicalJson -Json $originalProbe.CanonicalJson
    $newObject = ConvertFrom-McpCanonicalJson -Json $newProbe.CanonicalJson
    $left = Copy-McpJsonValue -Value $originalObject
    $right = Copy-McpJsonValue -Value $newObject
    $leftServers = Get-McpDictionaryValue -Object $left -Key 'mcp_servers'
    $rightServers = Get-McpDictionaryValue -Object $right -Key 'mcp_servers'
    $newJev = Get-McpDictionaryValue -Object $rightServers -Key 'jev'
    if ($null -ne $leftServers -and $leftServers -is [System.Collections.IDictionary]) {
        if ($leftServers.Contains('jev')) {
            $leftServers.Remove('jev')
        }
        if ($leftServers.Count -eq 0) {
            $left.Remove('mcp_servers')
        }
    }
    if ($null -ne $rightServers -and $rightServers -is [System.Collections.IDictionary]) {
        if ($rightServers.Contains('jev')) {
            $rightServers.Remove('jev')
        }
        if ($rightServers.Count -eq 0) {
            $right.Remove('mcp_servers')
        }
    }
    $diff = @(Compare-McpJsonValue -Left $left -Right $right)
    if ($diff.Count -ne 0) {
        return [pscustomobject]@{
            status  = 'edicao_manual_necessaria'
            path    = $Path
            action  = $effectiveAction
            reason  = 'diferenca inesperada fora de mcp_servers.jev'
            written = $false
            diff    = $diff
            snippet = $snippet
        }
    }
    if ($effectiveAction -ne 'remove') {
        $expectedObject = Get-McpCodexExpectedEntry -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model
        $entryDiff = @(Compare-McpJsonValue -Left $newJev -Right $expectedObject)
        if ($entryDiff.Count -ne 0) {
            return [pscustomobject]@{
                status  = 'edicao_manual_necessaria'
                path    = $Path
                action  = $effectiveAction
                reason  = 'entrada emitida nao confere com o objeto esperado'
                written = $false
                diff    = $entryDiff
                snippet = $snippet
            }
        }
    } else {
        if ($newProbe.HasJev) {
            return [pscustomobject]@{
                status  = 'edicao_manual_necessaria'
                path    = $Path
                action  = 'remove'
                reason  = 'mcp_servers.jev ainda presente apos remocao'
                written = $false
                snippet = $snippet
            }
        }
    }

    $diffLines = @(Compare-Object -ReferenceObject @($document.Text -split "`n") -DifferenceObject @($newText -split "`n") |
        ForEach-Object { [pscustomobject]@{ side = [string]$_.SideIndicator; line = [string]$_.InputObject } })
    if ($WhatIf) {
        return [pscustomobject]@{
            status       = 'planned'
            path         = $Path
            action       = $effectiveAction
            entryHash    = $expectedBlockHash
            expectedHash = $expectedBlockHash
            documentHash = $document.Hash
            written      = $false
            diff         = $diffLines
            newText      = $newText
        }
    }
    $writeResult = Write-McpTextTransactional `
        -Path $Path `
        -Text $newText `
        -EncodingKind $document.EncodingKind `
        -ExpectedHash $document.Hash `
        -ExpectedLength ([long]$document.Length) `
        -ExpectedLastWriteTimeUtc $document.LastWriteTimeUtc
    return [pscustomobject]@{
        status       = $writeResult.Status
        path         = $Path
        action       = $effectiveAction
        entryHash    = $expectedBlockHash
        expectedHash = $expectedBlockHash
        documentHash = $writeResult.Hash
        backupPath   = $writeResult.BackupPath
        written      = ($writeResult.Status -eq 'written')
        diff         = $diffLines
    }
}

function Get-McpCodexState {
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [string[]]$ManifestHashes = @()
    )
    $path = Get-McpCodexConfigPath
    $findings = [System.Collections.Generic.List[object]]::new()
    # Caminho que existe mas nao e arquivo regular e conflito, nunca ausencia (mesma regra do OpenCode).
    if (Test-McpConfigPathNonRegular -Path $path) {
        $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message 'config.toml existe mas nao e arquivo regular (link, reparse ou diretorio); nao decide sozinho' -Client 'codex')) | Out-Null
        return [pscustomobject]@{
            client   = 'codex'
            state    = 'nao_configurado'
            path     = $path
            findings = @($findings)
            form     = 'absent'
        }
    }
    if (-not (Test-McpRegularFile -Path $path)) {
        return [pscustomobject]@{
            client   = 'codex'
            state    = 'nao_configurado'
            path     = $path
            findings = @($findings)
            form     = 'absent'
        }
    }
    $document = Read-McpTextDocument -Path $path
    $expectedBlockText = New-McpCodexBlockText -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model -NewLine "`n"
    $expectedBlockContent = Get-McpCodexBlockContentFromText -BlockText $expectedBlockText
    $expectedBlockHash = Get-McpTextHash -Text $expectedBlockContent
    $block = Get-McpCodexBlockInfo -Text $document.Text
    if ($block.state -eq 'unbalanced') {
        $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message 'marcadores do bloco jev desbalanceados' -Client 'codex')) | Out-Null
        return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'unbalanced' }
    }
    $probe = Invoke-McpTomlProbe -Text $document.Text
    if ($probe.Status -eq 'python_indisponivel') {
        $findings.Add((New-McpFinding -Code 'python_indisponivel' -Class 'warn' -Message $probe.Error -Client 'codex')) | Out-Null
        $findings.Add((New-McpFinding -Code 'edicao_manual_necessaria' -Class 'warn' -Message 'sem tomllib 3.11+ a validacao do Codex fica manual' -Client 'codex')) | Out-Null
        if ($block.state -eq 'present' -and ($block.contentHash -eq $expectedBlockHash -or $ManifestHashes -contains $block.contentHash)) {
            return [pscustomobject]@{ client = 'codex'; state = 'escrito'; path = $path; findings = @($findings); form = 'block' }
        }
        return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'manual' }
    }
    if (-not $probe.Ok) {
        $findings.Add((New-McpFinding -Code 'entrada_quebrada' -Class 'blocking' -Message $probe.Error -Client 'codex')) | Out-Null
        return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'broken' }
    }
    if ($block.state -eq 'present') {
        if ($block.contentHash -ne $expectedBlockHash -and $ManifestHashes -notcontains $block.contentHash) {
            $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message 'conteudo entre marcadores nao reconhecido' -Client 'codex')) | Out-Null
            return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'block' }
        }
        $state = 'escrito'
        $processes = @(Get-Process -Name 'codex' -ErrorAction SilentlyContinue | Where-Object { $null -ne $_ })
        if ($processes.Count -gt 0) {
            foreach ($process in $processes) {
                try {
                    if ($document.LastWriteTimeUtc -gt $process.StartTime.ToUniversalTime()) {
                        $state = 'recarga_pendente'
                        break
                    }
                } catch {
                    # processo encerrado durante a leitura
                }
            }
        }
        return [pscustomobject]@{ client = 'codex'; state = $state; path = $path; findings = @($findings); form = 'block'; hash = $block.contentHash }
    }
    if ($probe.HasJev) {
        $scan = Get-McpCodexHeaderScan -Text $document.Text
        if ($scan.ExactHeaders.Count -eq 1 -and $scan.OtherHeaders.Count -eq 0) {
            $findings.Add((New-McpFinding -Code 'edicao_manual_necessaria' -Class 'blocking' -Message 'entrada manual [mcp_servers.jev] fora dos marcadores; use -MigrateLegacy para migrar com diff e aprovacao' -Client 'codex')) | Out-Null
            return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'manual'; migration = 'MigrateLegacy' }
        }
        $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message 'mcp_servers.jev existe fora dos marcadores em grafia nao migravel' -Client 'codex')) | Out-Null
        return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'manual' }
    }
    return [pscustomobject]@{ client = 'codex'; state = 'nao_configurado'; path = $path; findings = @($findings); form = 'absent' }
}
