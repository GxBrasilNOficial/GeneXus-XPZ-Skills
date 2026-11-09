#requires -Version 7.4

<#
.SYNOPSIS
    Adaptador OpenCode da skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Reaproveita o mecanismo JSONC ja usado pelo reviewer-ro:
      - localizacao textual por Find-JsoncMatchingBrace/Find-JsoncKeyValueSpan
        (copiadas de Install-OpenCodeReviewerRoAgent.ps1, com atribuicao);
      - parse completo ciente de comentarios por ConvertFrom-Jsonc, carregado
        por dot-source de OpenCodeReviewerRoGuard.ps1 (que so define funcoes);
      - validacao pos-edicao por comparacao de objetos.

    Forma canonica: mcp.servers.jev. Forma legada: mcp.jev. Coexistencia e
    conflito. A skill so substitui/remove entrada byte-identica a um hash
    registrado no install-manifest.json; qualquer outra coisa vira
    entrada_em_conflito ou edicao_manual_necessaria, sem escrita.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:McpOpenCodeSupportDir = Split-Path -Parent $PSCommandPath
. (Join-Path $script:McpOpenCodeSupportDir 'McpIntegrationSupport.ps1')

$guardPath = Join-Path $script:McpOpenCodeSupportDir 'OpenCodeReviewerRoGuard.ps1'
if (-not (Test-Path -LiteralPath $guardPath -PathType Leaf)) {
    throw "XPZ_MCP_OPENCODE_GUARD_MISSING: $guardPath"
}
. $guardPath

function Find-JsoncMatchingBrace {
    <# Copiada de Install-OpenCodeReviewerRoAgent.ps1 (mecanismo reviewer-ro).
       Dado o indice de um '{' em $Text, devolve o indice do '}' correspondente,
       ignorando chaves dentro de strings. -1 se nao fechar. #>
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [int] $OpenIndex)
    $depth = 0; $inStr = $false; $esc = $false
    for ($i = $OpenIndex; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($inStr) {
            if ($esc) { $esc = $false }
            elseif ($c -eq '\') { $esc = $true }
            elseif ($c -eq '"') { $inStr = $false }
            continue
        }
        if ($c -eq '"') { $inStr = $true; continue }
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { return $i } }
    }
    return -1
}

function Find-JsoncKeyValueSpan {
    <# Copiada de Install-OpenCodeReviewerRoAgent.ps1 (mecanismo reviewer-ro).
       Localiza a chave "Key" (fora de string) cujo valor e um objeto {...} e
       devolve @{ keyStart; valueOpen; valueClose } ou $null. #>
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [string] $Key, [int] $From = 0, [int] $To = -1)
    $needle = '"' + $Key + '"'
    $idx = $From
    while ($true) {
        $k = $Text.IndexOf($needle, $idx)
        if ($k -lt 0) { return $null }
        if ($To -ge 0 -and $k -ge $To) { return $null }
        $j = $k + $needle.Length
        while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
        if ($j -lt $Text.Length -and $Text[$j] -eq ':') {
            $j++
            while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
            if ($j -lt $Text.Length -and $Text[$j] -eq '{') {
                $close = Find-JsoncMatchingBrace -Text $Text -OpenIndex $j
                if ($close -lt 0) { throw "XPZ_MCP_JSONC_UNCLOSED: chave '$Key' com objeto nao fechado" }
                return @{ keyStart = $k; valueOpen = $j; valueClose = $close }
            }
        }
        $idx = $k + $needle.Length
    }
}

function Find-JsoncDirectKeyValueSpan {
    <#
        Localiza uma chave que seja filho DIRETO do objeto informado. Diferente
        de Find-JsoncKeyValueSpan, nao desce em objetos aninhados: mcp.jev nao
        pode casar o jev dentro de mcp.servers. Pula strings e comentarios.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$ObjectSpan,
        [Parameter(Mandatory = $true)][string]$Key
    )
    $i = $ObjectSpan.valueOpen + 1
    $end = $ObjectSpan.valueClose
    $depth = 0
    $inString = $false
    $escape = $false
    $inLineComment = $false
    $inBlockComment = $false
    while ($i -lt $end) {
        $c = $Text[$i]
        if ($inLineComment) {
            if ($c -eq "`n") { $inLineComment = $false }
            $i++
            continue
        }
        if ($inBlockComment) {
            if ($c -eq '*' -and $i + 1 -lt $end -and $Text[$i + 1] -eq '/') {
                $inBlockComment = $false
                $i += 2
            } else {
                $i++
            }
            continue
        }
        if ($inString) {
            if ($escape) { $escape = $false }
            elseif ($c -eq '\') { $escape = $true }
            elseif ($c -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $end -and $Text[$i + 1] -eq '/') {
            $inLineComment = $true
            $i += 2
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $end -and $Text[$i + 1] -eq '*') {
            $inBlockComment = $true
            $i += 2
            continue
        }
        if ($c -eq '"') {
            $start = $i
            $j = $i + 1
            $stringEscape = $false
            while ($j -lt $end) {
                $ch = $Text[$j]
                if ($stringEscape) { $stringEscape = $false }
                elseif ($ch -eq '\') { $stringEscape = $true }
                elseif ($ch -eq '"') { break }
                $j++
            }
            if ($j -ge $end) { return $null }
            if ($depth -eq 0) {
                $name = $Text.Substring($start + 1, $j - $start - 1)
                if ($name -ceq $Key) {
                    $k = $j + 1
                    while ($k -lt $end -and [char]::IsWhiteSpace($Text[$k])) { $k++ }
                    if ($k -lt $end -and $Text[$k] -eq ':') {
                        $k++
                        while ($k -lt $end -and [char]::IsWhiteSpace($Text[$k])) { $k++ }
                        if ($k -lt $end -and $Text[$k] -eq '{') {
                            $close = Find-JsoncMatchingBrace -Text $Text -OpenIndex $k
                            if ($close -lt 0) {
                                throw "XPZ_MCP_JSONC_UNCLOSED: chave '$Key' com objeto nao fechado"
                            }
                            return @{ keyStart = $start; valueOpen = $k; valueClose = $close }
                        }
                    }
                }
            }
            $i = $j + 1
            continue
        }
        if ($c -eq '{') { $depth++; $i++; continue }
        if ($c -eq '}') {
            if ($depth -gt 0) { $depth-- }
            $i++
            continue
        }
        $i++
    }
    return $null
}

function Get-McpJsoncRootOpen {
    param([Parameter(Mandatory = $true)][string]$Text)
    $i = 0
    $n = $Text.Length
    while ($i -lt $n) {
        $c = $Text[$i]
        if ([char]::IsWhiteSpace($c)) { $i++; continue }
        if ($c -eq '/' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '/') {
            while ($i -lt $n -and $Text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '*') {
            $i += 2
            while ($i + 1 -lt $n -and -not ($Text[$i] -eq '*' -and $Text[$i + 1] -eq '/')) { $i++ }
            $i += 2
            continue
        }
        if ($c -eq '{') { return $i }
        return -1
    }
    return -1
}

function Find-McpJsoncPathSpan {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string[]]$Path
    )
    $rootOpen = Get-McpJsoncRootOpen -Text $Text
    if ($rootOpen -lt 0) {
        throw 'XPZ_MCP_JSONC_ROOT_MISSING: objeto raiz ausente'
    }
    $rootClose = Find-JsoncMatchingBrace -Text $Text -OpenIndex $rootOpen
    if ($rootClose -lt 0) {
        throw 'XPZ_MCP_JSONC_ROOT_UNCLOSED: objeto raiz nao fechado'
    }
    $current = @{ keyStart = $rootOpen; valueOpen = $rootOpen; valueClose = $rootClose }
    foreach ($segment in $Path) {
        $next = Find-JsoncDirectKeyValueSpan -Text $Text -ObjectSpan $current -Key $segment
        if ($null -eq $next) {
            return $null
        }
        $current = $next
    }
    return $current
}

function Get-McpLineIndentAt {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$Index
    )
    $p = $Index - 1
    while ($p -ge 0 -and $Text[$p] -ne "`n" -and $Text[$p] -ne "`r") { $p-- }
    $p++
    $indent = ''
    while ($p -lt $Text.Length -and ($Text[$p] -eq ' ' -or $Text[$p] -eq "`t")) {
        $indent += $Text[$p]
        $p++
    }
    return $indent
}

function Get-McpJsoncChildIndent {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$ObjectSpan
    )
    $i = $ObjectSpan.valueOpen + 1
    while ($i -lt $ObjectSpan.valueClose) {
        $c = $Text[$i]
        if ($c -eq "`n" -or $c -eq "`r") {
            $j = $i + 1
            $indent = ''
            while ($j -lt $Text.Length -and ($Text[$j] -eq ' ' -or $Text[$j] -eq "`t")) {
                $indent += $Text[$j]
                $j++
            }
            if ($j -lt $Text.Length -and $Text[$j] -ne '}' -and $Text[$j] -ne '{') {
                return $indent
            }
        }
        $i++
    }
    return ((Get-McpLineIndentAt -Text $Text -Index $ObjectSpan.valueOpen) + '  ')
}

function Get-McpJsoncEol {
    param([Parameter(Mandatory = $true)][string]$Text)
    if ($Text.Contains("`r`n")) { return "`r`n" }
    return "`n"
}

function Insert-JsoncProperty {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$ObjectSpan,
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$ValueText
    )
    $eol = Get-McpJsoncEol -Text $Text
    $parentIndent = Get-McpLineIndentAt -Text $Text -Index $ObjectSpan.valueOpen
    $childIndent = Get-McpJsoncChildIndent -Text $Text -ObjectSpan $ObjectSpan
    $content = $Text.Substring($ObjectSpan.valueOpen + 1, $ObjectSpan.valueClose - $ObjectSpan.valueOpen - 1)
    $property = '"' + $Key + '": ' + $ValueText
    if ([string]::IsNullOrWhiteSpace($content)) {
        $replacement = $eol + $childIndent + $property + $eol + $parentIndent
        return $Text.Substring(0, $ObjectSpan.valueOpen + 1) + $replacement + $Text.Substring($ObjectSpan.valueClose)
    }
    $insertion = $eol + $childIndent + $property + ','
    return $Text.Substring(0, $ObjectSpan.valueOpen + 1) + $insertion + $Text.Substring($ObjectSpan.valueOpen + 1)
}

function Remove-JsoncProperty {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$ObjectSpan,
        [Parameter(Mandatory = $true)][hashtable]$KeySpan
    )
    $before = $KeySpan.keyStart - 1
    while ($before -ge 0 -and [char]::IsWhiteSpace($Text[$before])) { $before-- }
    $commaBefore = -1
    if ($before -ge 0 -and $Text[$before] -eq ',') {
        $commaBefore = $before
    }
    $after = $KeySpan.valueClose + 1
    while ($after -lt $Text.Length -and [char]::IsWhiteSpace($Text[$after])) { $after++ }
    $commaAfter = -1
    if ($after -lt $Text.Length -and $Text[$after] -eq ',') {
        $commaAfter = $after
    }
    if ($commaBefore -ge 0) {
        $newText = $Text.Remove($commaBefore, $KeySpan.valueClose - $commaBefore + 1)
        return $newText
    }
    if ($commaAfter -ge 0) {
        $newText = $Text.Remove($KeySpan.keyStart, $commaAfter - $KeySpan.keyStart + 1)
        $cursor = $KeySpan.keyStart
        while ($cursor -lt $newText.Length -and [char]::IsWhiteSpace($newText[$cursor])) {
            $cursor++
        }
        return $newText.Remove($KeySpan.keyStart, $cursor - $KeySpan.keyStart)
    }
    $contentStart = $ObjectSpan.valueOpen + 1
    $contentLength = $ObjectSpan.valueClose - $ObjectSpan.valueOpen - 1
    return $Text.Remove($contentStart, $contentLength)
}

function New-McpOpenCodeEntryObject {
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [bool]$Disabled = $false
    )
    $command = @('pwsh', '-NoProfile', '-File', $LauncherPath)
    return [ordered]@{
        type        = 'local'
        command     = $command
        environment = [ordered]@{
            JEV_API_BASE_URL = $BaseUrl
            JEV_MCP_MODEL    = $Model
        }
        disabled    = $Disabled
    }
}

function ConvertTo-McpOpenCodeValueText {
    param([Parameter(Mandatory = $true)]$Value)
    $json = $Value | ConvertTo-Json -Depth 20
    return (($json -replace "`r`n", "`n").TrimEnd("`n"))
}

function Add-McpValueIndent {
    <#
        Prefixa as linhas 2..N do valor com a indentacao da chave. A primeira
        linha fica apos "chave": e as demais precisam acompanhar o nivel da
        chave para o arquivo final ficar legivel. O texto resultante e o que o
        manifesto registra, mantendo a identidade textual do bloco emitido.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ValueText,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Indent,
        [string]$NewLine = "`n"
    )
    $lines = @(($ValueText -replace "`r`n", "`n") -split "`n")
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Length -gt 0) {
            $lines[$i] = $Indent + $lines[$i]
        }
    }
    return ($lines -join $NewLine)
}

function Get-McpOpenCodeConfigCandidates {
    $root = Join-Path (Get-McpProfileRoot) '.config\opencode'
    $json = Join-Path $root 'opencode.json'
    $jsonc = Join-Path $root 'opencode.jsonc'
    return [pscustomobject]@{
        Root       = $root
        Json       = $json
        Jsonc      = $jsonc
        JsonExists = (Test-McpRegularFile -Path $json)
        JsoncExists = (Test-McpRegularFile -Path $jsonc)
    }
}

function Get-McpOpenCodeConfigTarget {
    $candidates = Get-McpOpenCodeConfigCandidates
    if ($candidates.JsonExists -and $candidates.JsoncExists) {
        return [pscustomobject]@{
            status     = 'conflict'
            path       = $null
            candidates = $candidates
            reason     = 'opencode.json e opencode.jsonc presentes; sem precedencia comprovada'
        }
    }
    if ($candidates.JsonExists) {
        return [pscustomobject]@{ status = 'ok'; path = $candidates.Json; candidates = $candidates; reason = $null }
    }
    if ($candidates.JsoncExists) {
        return [pscustomobject]@{ status = 'ok'; path = $candidates.Jsonc; candidates = $candidates; reason = $null }
    }
    return [pscustomobject]@{ status = 'absent'; path = $null; candidates = $candidates; reason = $null }
}

function Get-McpOpenCodeEntryInfo {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$LauncherPath,
        [string]$BaseUrl,
        [string]$Model
    )
    $document = Read-McpTextDocument -Path $Path
    try {
        $parsed = ConvertFrom-Jsonc -Raw $document.Text
    } catch {
        return [pscustomobject]@{
            status   = 'entrada_quebrada'
            path     = $Path
            document = $document
            parsed   = $null
            reason   = $_.Exception.Message
        }
    }
    try {
        $canonicalSpan = Find-McpJsoncPathSpan -Text $document.Text -Path @('mcp', 'servers', 'jev')
        $legacySpan = Find-McpJsoncPathSpan -Text $document.Text -Path @('mcp', 'jev')
    } catch {
        return [pscustomobject]@{
            status   = 'entrada_quebrada'
            path     = $Path
            document = $document
            parsed   = $null
            reason   = $_.Exception.Message
        }
    }
    $canonicalPresent = $null -ne $canonicalSpan
    $legacyPresent = $null -ne $legacySpan
    if ($canonicalPresent -and $legacyPresent) {
        return [pscustomobject]@{
            status        = 'entrada_em_conflito'
            path          = $Path
            document      = $document
            parsed        = $parsed
            reason        = 'mcp.servers.jev e mcp.jev coexistem'
            canonicalSpan = $canonicalSpan
            legacySpan    = $legacySpan
        }
    }
    $form = 'absent'
    $span = $null
    if ($canonicalPresent) { $form = 'canonical'; $span = $canonicalSpan }
    elseif ($legacyPresent) { $form = 'legacy'; $span = $legacySpan }

    $valueText = $null
    $hash = $null
    $entry = $null
    if ($null -ne $span) {
        $valueText = $document.Text.Substring($span.valueOpen, $span.valueClose - $span.valueOpen + 1)
        $hash = Get-McpTextHash -Text $valueText
        if ($form -eq 'canonical') {
            $entry = $parsed.mcp.servers.jev
        } else {
            $entry = $parsed.mcp.jev
        }
    }
    $disabled = $false
    if ($null -ne $entry) {
        $entryOrdered = ConvertTo-McpOrdered -Value $entry
        if ($entryOrdered -is [System.Collections.IDictionary]) {
            if ($entryOrdered.Contains('disabled') -and $entryOrdered['disabled'] -eq $true) { $disabled = $true }
            if ($entryOrdered.Contains('enabled') -and $entryOrdered['enabled'] -eq $false) { $disabled = $true }
        }
    }
    $expectedText = $null
    $expectedHash = $null
    $expectedObject = $null
    if (-not [string]::IsNullOrWhiteSpace($LauncherPath)) {
        $expectedObject = New-McpOpenCodeEntryObject -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model -Disabled $disabled
        $baseText = ConvertTo-McpOpenCodeValueText -Value $expectedObject
        if ($null -ne $span) {
            $keyIndent = Get-McpLineIndentAt -Text $document.Text -Index $span.keyStart
            $expectedText = Add-McpValueIndent -ValueText $baseText -Indent $keyIndent -NewLine (Get-McpJsoncEol -Text $document.Text)
        } else {
            $expectedText = $baseText
        }
        $expectedHash = Get-McpTextHash -Text $expectedText
    }
    return [pscustomobject]@{
        status         = 'ok'
        path           = $Path
        document       = $document
        parsed         = $parsed
        form           = $form
        span           = $span
        valueText      = $valueText
        hash           = $hash
        entry          = $entry
        disabled       = $disabled
        expectedText   = $expectedText
        expectedHash   = $expectedHash
        expectedObject = $expectedObject
    }
}


function Remove-McpJsonPropertyPath {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string[]]$Path
    )
    $copy = Copy-McpJsonValue -Value $Object
    if ($Path.Count -eq 0) { return $copy }
    $current = $copy
    for ($i = 0; $i -lt $Path.Count - 1; $i++) {
        if ($current -isnot [System.Collections.IDictionary]) { return $copy }
        $segment = $Path[$i]
        if (-not $current.Contains($segment)) { return $copy }
        $current = $current[$segment]
    }
    if ($current -is [System.Collections.IDictionary]) {
        $leaf = $Path[$Path.Count - 1]
        if ($current.Contains($leaf)) {
            $current.Remove($leaf)
        }
    }
    return $copy
}

function Get-McpOpenCodeMissingPath {
    param(
        [Parameter(Mandatory = $true)]$Parsed,
        [Parameter(Mandatory = $true)][string[]]$Path
    )
    $current = $Parsed
    $prefix = @()
    foreach ($segment in $Path) {
        $prefix += $segment
        if ($current -isnot [System.Collections.IDictionary]) {
            return $prefix
        }
        if (-not $current.Contains($segment)) {
            return $prefix
        }
        $current = $current[$segment]
    }
    return $Path
}

function Test-McpOpenCodeExactEntry {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)]$Expected
    )
    $differences = @(Compare-McpJsonValue -Left $Entry -Right $Expected)
    return [pscustomobject]@{
        ok          = ($differences.Count -eq 0)
        differences = $differences
    }
}

function Add-McpOpenCodeEntryToText {
    <#
        Insere mcp.servers.jev em tres passos, cada um como filho direto do
        objeto pai. Inserir o valor ja aninhado mudaria a indentacao interna da
        entrada e quebraria a identidade textual reconhecida pelo manifesto.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$ValueText
    )
    $current = $Text
    $mcpSpan = Find-McpJsoncPathSpan -Text $current -Path @('mcp')
    if ($null -eq $mcpSpan) {
        $rootOpen = Get-McpJsoncRootOpen -Text $current
        if ($rootOpen -lt 0) { throw 'XPZ_MCP_JSONC_ROOT_MISSING: objeto raiz ausente' }
        $rootClose = Find-JsoncMatchingBrace -Text $current -OpenIndex $rootOpen
        $rootSpan = @{ valueOpen = $rootOpen; valueClose = $rootClose }
        $current = Insert-JsoncProperty -Text $current -ObjectSpan $rootSpan -Key 'mcp' -ValueText '{}'
        $mcpSpan = Find-McpJsoncPathSpan -Text $current -Path @('mcp')
    }
    $serversSpan = Find-McpJsoncPathSpan -Text $current -Path @('mcp', 'servers')
    if ($null -eq $serversSpan) {
        $current = Insert-JsoncProperty -Text $current -ObjectSpan $mcpSpan -Key 'servers' -ValueText '{}'
        $serversSpan = Find-McpJsoncPathSpan -Text $current -Path @('mcp', 'servers')
    }
    if ($null -eq $serversSpan) {
        throw 'XPZ_MCP_JSONC_INSERT_FAILED: mcp.servers nao localizado apos insercao'
    }
    $eol = Get-McpJsoncEol -Text $current
    $keyIndent = Get-McpJsoncChildIndent -Text $current -ObjectSpan $serversSpan
    $indentedValue = Add-McpValueIndent -ValueText $ValueText -Indent $keyIndent -NewLine $eol
    $newText = Insert-JsoncProperty -Text $current -ObjectSpan $serversSpan -Key 'jev' -ValueText $indentedValue
    return [pscustomobject]@{
        Text      = $newText
        ValueText = $indentedValue
        KeyIndent = $keyIndent
    }
}

function Update-McpOpenCodeConfig {
    <#
    .SYNOPSIS
        Insere, substitui, migra ou remove a entrada jev do opencode.json(c).

    .OUTPUTS
        PSCustomObject com status em unchanged|written|planned|manual|conflict.
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

    $info = Get-McpOpenCodeEntryInfo -Path $Path -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model
    if ($info.status -eq 'entrada_quebrada' -or $info.status -eq 'entrada_em_conflito') {
        return [pscustomobject]@{
            status  = $info.status
            path    = $Path
            action  = $Action
            reason  = $info.reason
            written = $false
        }
    }

    $oldText = $info.document.Text
    $newText = $oldText
    $effectiveAction = $Action
    $entryHash = $null
    $expectedValueText = $info.expectedText
    $recognized = $false
    if ($null -ne $info.hash) {
        $recognized = ($info.hash -eq $info.expectedHash) -or ($ManifestHashes -contains $info.hash)
    }

    if ($Action -eq 'auto') {
        if ($info.form -eq 'canonical') { $effectiveAction = 'install' }
        elseif ($info.form -eq 'legacy') { $effectiveAction = 'install' }
        else { $effectiveAction = 'install' }
    }

    if ($effectiveAction -in @('install', 'migrate')) {
        if ($info.form -eq 'both') {
            return [pscustomobject]@{ status = 'conflict'; path = $Path; action = $effectiveAction; reason = 'mcp.servers.jev e mcp.jev coexistem'; written = $false }
        }
        if ($info.form -eq 'canonical') {
            if ($info.hash -eq $info.expectedHash) {
                return [pscustomobject]@{
                    status        = 'unchanged'
                    path          = $Path
                    action        = 'install'
                    entryHash     = $info.hash
                    expectedHash  = $info.expectedHash
                    entry         = $info.entry
                    documentHash  = $info.document.Hash
                    written       = $false
                }
            }
            if (-not $recognized) {
                return [pscustomobject]@{
                    status = 'conflict'
                    path   = $Path
                    action = 'install'
                    reason = 'mcp.servers.jev nao e byte-identico a entrada emitida pela skill'
                    written = $false
                }
            }
            $replacement = $expectedValueText
            $newText = $oldText.Substring(0, $info.span.valueOpen) + $replacement + $oldText.Substring($info.span.valueClose + 1)
            $entryHash = Get-McpTextHash -Text $replacement
        } elseif ($info.form -eq 'legacy') {
            if (-not $MigrateLegacy -and -not ($ManifestHashes -contains $info.hash)) {
                return [pscustomobject]@{
                    status   = 'manual'
                    path     = $Path
                    action   = 'migrate'
                    reason   = 'entrada manual mcp.jev exige aprovacao explicita para migrar'
                    written  = $false
                    snippet  = $expectedValueText
                    diff     = $null
                }
            }
            $disabled = $info.disabled
            $expectedObject = New-McpOpenCodeEntryObject -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model -Disabled $disabled
            $expectedValueText = ConvertTo-McpOpenCodeValueText -Value $expectedObject
            $legacyDisabled = $disabled
            # Remove a entrada legada e insere a canonica no mesmo passo.
            $mcpSpanBefore = Find-McpJsoncPathSpan -Text $oldText -Path @('mcp')
            if ($null -eq $mcpSpanBefore) {
                return [pscustomobject]@{ status = 'conflict'; path = $Path; action = 'migrate'; reason = 'mcp ausente na entrada legada'; written = $false }
            }
            $withoutLegacy = Remove-JsoncProperty -Text $oldText -ObjectSpan $mcpSpanBefore -KeySpan $info.span
            $insert = Add-McpOpenCodeEntryToText -Text $withoutLegacy -ValueText $expectedValueText
            $newText = $insert.Text
            $expectedValueText = $insert.ValueText
            $entryHash = Get-McpTextHash -Text $expectedValueText
        } else {
            $disabled = $false
            $expectedObject = New-McpOpenCodeEntryObject -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model -Disabled $disabled
            $expectedValueText = ConvertTo-McpOpenCodeValueText -Value $expectedObject
            $insert = Add-McpOpenCodeEntryToText -Text $oldText -ValueText $expectedValueText
            $newText = $insert.Text
            $expectedValueText = $insert.ValueText
            $entryHash = Get-McpTextHash -Text $expectedValueText
        }
    } elseif ($effectiveAction -eq 'remove') {
        if ($info.form -eq 'both') {
            return [pscustomobject]@{ status = 'conflict'; path = $Path; action = 'remove'; reason = 'mcp.servers.jev e mcp.jev coexistem'; written = $false }
        }
        if ($info.form -eq 'absent') {
            return [pscustomobject]@{ status = 'unchanged'; path = $Path; action = 'remove'; written = $false; reason = 'entrada ausente' }
        }
        if (-not $recognized) {
            return [pscustomobject]@{
                status = 'conflict'
                path   = $Path
                action = 'remove'
                reason = 'entrada nao reconhecida pelo manifesto; remocao recusada'
                written = $false
            }
        }
        $objectSpan = if ($info.form -eq 'canonical') {
            (Find-McpJsoncPathSpan -Text $oldText -Path @('mcp', 'servers'))
        } else {
            (Find-McpJsoncPathSpan -Text $oldText -Path @('mcp'))
        }
        if ($null -eq $objectSpan) {
            return [pscustomobject]@{ status = 'conflict'; path = $Path; action = 'remove'; reason = 'objeto pai da entrada nao localizado'; written = $false }
        }
        $newText = Remove-JsoncProperty -Text $oldText -ObjectSpan $objectSpan -KeySpan $info.span
    } else {
        return [pscustomobject]@{ status = 'conflict'; path = $Path; action = $effectiveAction; reason = 'acao invalida'; written = $false }
    }

    # Pos-validacao: parse completo + comparacao semantica da diferenca esperada.
    try {
        $newParsed = ConvertFrom-Jsonc -Raw $newText
    } catch {
        return [pscustomobject]@{
            status   = 'manual'
            path     = $Path
            action   = $effectiveAction
            reason   = 'texto resultante nao parseia: ' + $_.Exception.Message
            written  = $false
            snippet  = $expectedValueText
        }
    }
    $originalParsed = $info.parsed
    if ($effectiveAction -eq 'remove') {
        $removePath = if ($info.form -eq 'canonical') { @('mcp', 'servers', 'jev') } else { @('mcp', 'jev') }
        $left = Remove-McpJsonPropertyPath -Object $originalParsed -Path $removePath
        $right = Remove-McpJsonPropertyPath -Object $newParsed -Path $removePath
        $diff = @(Compare-McpJsonValue -Left $left -Right $right)
        if ($diff.Count -ne 0) {
            return [pscustomobject]@{
                status   = 'manual'
                path     = $Path
                action   = $effectiveAction
                reason   = 'diferenca inesperada apos remocao'
                written  = $false
                diff     = $diff
                snippet  = $expectedValueText
            }
        }
    } else {
        if ($info.form -eq 'legacy') {
            $left = Copy-McpJsonValue -Value $originalParsed
            $right = Copy-McpJsonValue -Value $newParsed
            $leftMcp = Get-McpDictionaryValue -Object $left -Key 'mcp'
            if ($null -ne $leftMcp -and $leftMcp -is [System.Collections.IDictionary] -and $leftMcp.Contains('jev')) {
                $leftMcp.Remove('jev')
            }
            $rightMcp = Get-McpDictionaryValue -Object $right -Key 'mcp'
            if ($null -ne $rightMcp -and $rightMcp -is [System.Collections.IDictionary]) {
                $servers = Get-McpDictionaryValue -Object $rightMcp -Key 'servers'
                if ($null -ne $servers -and $servers -is [System.Collections.IDictionary]) {
                    if ($servers.Contains('jev')) {
                        $servers.Remove('jev')
                    }
                    if ($servers.Count -eq 0) {
                        $rightMcp.Remove('servers')
                    }
                }
            }
            $diff = @(Compare-McpJsonValue -Left $left -Right $right)
            if ($diff.Count -ne 0) {
                return [pscustomobject]@{
                    status   = 'manual'
                    path     = $Path
                    action   = $effectiveAction
                    reason   = 'diferenca inesperada na migracao'
                    written  = $false
                    diff     = $diff
                    snippet  = $expectedValueText
                }
            }
            $migratedEntry = Get-McpDictionaryValue -Object (Get-McpDictionaryValue -Object (Get-McpDictionaryValue -Object $newParsed -Key 'mcp') -Key 'servers') -Key 'jev'
            $shape = Test-McpOpenCodeExactEntry -Entry $migratedEntry -Expected (ConvertFrom-Json -InputObject $expectedValueText -AsHashtable)
            if (-not $shape.ok) {
                return [pscustomobject]@{ status = 'manual'; path = $Path; action = $effectiveAction; reason = 'entrada migrada nao confere'; written = $false; diff = $shape.differences; snippet = $expectedValueText }
            }
        } else {
            $missingPath = Get-McpOpenCodeMissingPath -Parsed $originalParsed -Path @('mcp', 'servers', 'jev')
            $left = Remove-McpJsonPropertyPath -Object $originalParsed -Path $missingPath
            $right = Remove-McpJsonPropertyPath -Object $newParsed -Path $missingPath
            $diff = @(Compare-McpJsonValue -Left $left -Right $right)
            if ($diff.Count -ne 0) {
                return [pscustomobject]@{
                    status   = 'manual'
                    path     = $Path
                    action   = $effectiveAction
                    reason   = 'diferenca inesperada fora da entrada jev'
                    written  = $false
                    diff     = $diff
                    snippet  = $expectedValueText
                }
            }
            $newEntry = Get-McpDictionaryValue -Object (Get-McpDictionaryValue -Object (Get-McpDictionaryValue -Object $newParsed -Key 'mcp') -Key 'servers') -Key 'jev'
            $shape = Test-McpOpenCodeExactEntry -Entry $newEntry -Expected (ConvertFrom-Json -InputObject $expectedValueText -AsHashtable)
            if (-not $shape.ok) {
                return [pscustomobject]@{ status = 'manual'; path = $Path; action = $effectiveAction; reason = 'entrada emitida nao confere'; written = $false; diff = $shape.differences; snippet = $expectedValueText }
            }
        }
    }

    $diffLines = @(Compare-Object -ReferenceObject @($oldText -split "`n") -DifferenceObject @($newText -split "`n") -IncludeEqual:$false |
        ForEach-Object { [pscustomobject]@{ side = [string]$_.SideIndicator; line = [string]$_.InputObject } })

    if ($WhatIf) {
        return [pscustomobject]@{
            status       = 'planned'
            path         = $Path
            action       = $effectiveAction
            entryHash    = $entryHash
            expectedHash = $info.expectedHash
            documentHash = $info.document.Hash
            written      = $false
            diff         = $diffLines
            newText      = $newText
        }
    }

    $writeResult = Write-McpTextTransactional `
        -Path $Path `
        -Text $newText `
        -EncodingKind $info.document.EncodingKind `
        -ExpectedHash $info.document.Hash `
        -ExpectedLength ([long]$info.document.Length) `
        -ExpectedLastWriteTimeUtc $info.document.LastWriteTimeUtc
    return [pscustomobject]@{
        status       = $writeResult.Status
        path         = $Path
        action       = $effectiveAction
        entryHash    = $entryHash
        expectedHash = $info.expectedHash
        documentHash = $writeResult.Hash
        backupPath   = $writeResult.BackupPath
        written      = ($writeResult.Status -eq 'written')
        diff         = $diffLines
    }
}

function Get-McpOpenCodeState {
    param(
        [Parameter(Mandatory = $true)][string]$LauncherPath,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [string[]]$ManifestHashes = @()
    )
    $target = Get-McpOpenCodeConfigTarget
    $findings = [System.Collections.Generic.List[object]]::new()
    if ($target.status -eq 'conflict') {
        $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message $target.reason -Client 'opencode')) | Out-Null
        return [pscustomobject]@{
            client   = 'opencode'
            state    = 'nao_configurado'
            path     = $null
            findings = @($findings)
            form     = 'absent'
        }
    }
    if ($target.status -eq 'absent') {
        return [pscustomobject]@{
            client   = 'opencode'
            state    = 'nao_configurado'
            path     = $null
            findings = @($findings)
            form     = 'absent'
        }
    }
    $info = Get-McpOpenCodeEntryInfo -Path $target.path -LauncherPath $LauncherPath -BaseUrl $BaseUrl -Model $Model
    if ($info.status -eq 'entrada_quebrada') {
        $findings.Add((New-McpFinding -Code 'entrada_quebrada' -Class 'blocking' -Message $info.reason -Client 'opencode')) | Out-Null
        return [pscustomobject]@{
            client   = 'opencode'
            state    = 'nao_configurado'
            path     = $target.path
            findings = @($findings)
            form     = 'broken'
        }
    }
    if ($info.status -eq 'entrada_em_conflito') {
        $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message $info.reason -Client 'opencode')) | Out-Null
        return [pscustomobject]@{
            client   = 'opencode'
            state    = 'nao_configurado'
            path     = $target.path
            findings = @($findings)
            form     = 'both'
        }
    }
    if ($info.form -eq 'absent') {
        return [pscustomobject]@{
            client   = 'opencode'
            state    = 'nao_configurado'
            path     = $target.path
            findings = @($findings)
            form     = 'absent'
        }
    }
    $recognized = ($info.hash -eq $info.expectedHash) -or ($ManifestHashes -contains $info.hash)
    if (-not $recognized) {
        if ($info.form -eq 'legacy') {
            $findings.Add((New-McpFinding -Code 'edicao_manual_necessaria' -Class 'blocking' -Message 'entrada manual mcp.jev; use -MigrateLegacy para migrar com diff e aprovacao' -Client 'opencode')) | Out-Null
            return [pscustomobject]@{
                client    = 'opencode'
                state     = 'nao_configurado'
                path      = $target.path
                findings  = @($findings)
                form      = 'legacy'
                migration = 'MigrateLegacy'
                hash      = $info.hash
            }
        }
        $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message 'entrada jev nao reconhecida pelo manifesto' -Client 'opencode')) | Out-Null
        return [pscustomobject]@{
            client   = 'opencode'
            state    = 'nao_configurado'
            path     = $target.path
            findings = @($findings)
            form     = $info.form
            hash     = $info.hash
        }
    }
    if ($info.disabled) {
        $findings.Add((New-McpFinding -Code 'entrada_desabilitada' -Class 'warn' -Message 'entrada jev reconhecida, mas disabled=true/enabled=false' -Client 'opencode')) | Out-Null
    }
    $state = 'escrito'
    $processes = @(Get-Process -Name 'opencode' -ErrorAction SilentlyContinue | Where-Object { $null -ne $_ })
    if ($processes.Count -gt 0) {
        $configTime = $info.document.LastWriteTimeUtc
        foreach ($process in $processes) {
            try {
                if ($configTime -gt $process.StartTime.ToUniversalTime()) {
                    $state = 'recarga_pendente'
                    break
                }
            } catch {
                # Processo encerrado entre a enumeracao e a leitura: ignora.
            }
        }
    }
    return [pscustomobject]@{
        client   = 'opencode'
        state    = $state
        path     = $target.path
        findings = @($findings)
        form     = $info.form
        hash     = $info.hash
        disabled = $info.disabled
    }
}
