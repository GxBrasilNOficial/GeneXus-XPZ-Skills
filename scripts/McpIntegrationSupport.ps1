#requires -Version 7.4

<#
.SYNOPSIS
    Suporte compartilhado da skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Reune contrato de descritor, caminhos gerenciados, leitura/escrita
    transacional, config.json, install-manifest.json, requisitos de runtime e
    tabela de exit codes reservados.

    A skill trabalha com configs de terceiros (OpenCode e Codex) e com um
    componente MCP externo opcional. Nada aqui grava sem chamada explicita de
    um mutador; as funcoes de escrita sao usadas pelos motores e pelos
    self-tests com raizes temporarias.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'XpzProcessProbeSupport.ps1')

$script:McpDescriptorRelativePath = 'xpz-mcp-integrations-setup/components/jev.json'
$script:McpLauncherTemplateRelativePath = 'xpz-mcp-integrations-setup/templates/launcher.ps1'
$script:McpExitCodesRelativePath = 'xpz-mcp-integrations-setup/exit-codes.catalog.json'
$script:McpExitCodePrecedenceCache = $null

function Resolve-McpFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-McpPathUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $candidate = Resolve-McpFullPath -Path $Path
    $root = Resolve-McpFullPath -Path $Parent
    if ($candidate.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $candidate.StartsWith(
        $root + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Test-McpConfigPathNonRegular {
    <#
    .SYNOPSIS
        Verdadeiro quando o caminho existe mas nao e arquivo regular (diretorio, link simbolico,
        reparse point). Essa configuracao nao pode ser lida nem reconhecida com seguranca: e conflito,
        nunca ausencia. Um caminho inexistente devolve falso.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-McpRegularFile -Path $Path) { return $false }
    return (Test-Path -LiteralPath $Path)
}

function Test-McpRegularFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    } catch {
        return $false
    }
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) {
        return $false
    }
    return $true
}

function Get-McpRepoRoot {
    $root = Resolve-McpFullPath -Path (Join-Path $PSScriptRoot '..')
    $descriptorPath = Join-Path $root $script:McpDescriptorRelativePath
    if (-not (Test-Path -LiteralPath $descriptorPath -PathType Leaf)) {
        throw "XPZ_MCP_REPO_ROOT_INVALID: descritor nao encontrado em $descriptorPath"
    }
    return $root
}

function Get-McpProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'XPZ_MCP_PROFILE_MISSING: USERPROFILE nao definido'
    }
    return (Resolve-McpFullPath -Path $env:USERPROFILE)
}

function Get-McpLocalAppData {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'XPZ_MCP_LOCALAPPDATA_MISSING: LOCALAPPDATA nao definido'
    }
    return (Resolve-McpFullPath -Path $env:LOCALAPPDATA)
}

function Get-McpManagedRoot {
    return (Resolve-McpFullPath -Path (Join-Path (Get-McpLocalAppData) 'xpz-mcp-integrations'))
}

function Ensure-McpManagedRoot {
    $root = Get-McpManagedRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return $root
}

function Get-McpFileHash {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-McpBytesHash {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Get-McpTextHash {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    return Get-McpBytesHash -Bytes $bytes
}

function Get-McpFileIdentity {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-McpRegularFile -Path $Path)) {
        return $null
    }
    $info = [System.IO.FileInfo]::new($Path)
    return [pscustomobject]@{
        Path               = $info.FullName
        Length             = $info.Length
        LastWriteTimeUtc   = $info.LastWriteTimeUtc
        Hash               = Get-McpFileHash -Path $Path
    }
}

function Get-McpEncodingFromBom {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        return [pscustomobject]@{
            Kind      = 'utf8-bom'
            HasBom    = $true
            Offset    = 3
            Encoding  = [System.Text.UTF8Encoding]::new($true)
        }
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        return [pscustomobject]@{
            Kind      = 'utf16-le'
            HasBom    = $true
            Offset    = 2
            Encoding  = [System.Text.UnicodeEncoding]::new($false, $true)
        }
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        return [pscustomobject]@{
            Kind      = 'utf16-be'
            HasBom    = $true
            Offset    = 2
            Encoding  = [System.Text.UnicodeEncoding]::new($true, $true)
        }
    }
    return [pscustomobject]@{
        Kind      = 'utf8-nobom'
        HasBom    = $false
        Offset    = 0
        Encoding  = [System.Text.UTF8Encoding]::new($false)
    }
}

function Read-McpTextDocument {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-McpRegularFile -Path $Path)) {
        throw "XPZ_MCP_FILE_NOT_REGULAR: $Path"
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bom = Get-McpEncodingFromBom -Bytes $bytes
    $text = $bom.Encoding.GetString($bytes, $bom.Offset, $bytes.Length - $bom.Offset)
    $newLine = "`n"
    if ($text.Contains("`r`n")) {
        $newLine = "`r`n"
    }
    return [pscustomobject]@{
        Path             = [System.IO.Path]::GetFullPath($Path)
        Text             = $text
        Bytes            = $bytes
        EncodingKind     = $bom.Kind
        HasBom           = $bom.HasBom
        NewLine          = $newLine
        Hash             = Get-McpBytesHash -Bytes $bytes
        Length           = $bytes.Length
        LastWriteTimeUtc = ([System.IO.FileInfo]::new($Path)).LastWriteTimeUtc
    }
}

function ConvertTo-McpTextBytes {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$EncodingKind
    )
    switch ($EncodingKind) {
        'utf8-bom' {
            $encoding = [System.Text.UTF8Encoding]::new($true)
            $body = $encoding.GetBytes($Text)
            $preamble = $encoding.GetPreamble()
            return ,([byte[]]($preamble + $body))
        }
        'utf16-le' {
            $encoding = [System.Text.UnicodeEncoding]::new($false, $true)
            $body = $encoding.GetBytes($Text)
            $preamble = $encoding.GetPreamble()
            return ,([byte[]]($preamble + $body))
        }
        'utf16-be' {
            $encoding = [System.Text.UnicodeEncoding]::new($true, $true)
            $body = $encoding.GetBytes($Text)
            $preamble = $encoding.GetPreamble()
            return ,([byte[]]($preamble + $body))
        }
        default {
            return ,([System.Text.UTF8Encoding]::new($false).GetBytes($Text))
        }
    }
}

function Write-McpTextTransactional {
    <#
    .SYNOPSIS
        Escrita transacional de config de cliente/artefato gerenciado.

    .DESCRIPTION
        Valida folha regular (sem reparse point), adquire lock create-new,
        revalida identidade, grava temporario na mesma pasta, confere hash e
        promove com File.Replace (substituicao) ou FileMode.CreateNew (criacao
        exclusiva). -CreateExclusive recusa se a folha ja existir — fecha a
        corrida em que o chamador sondou ausencia, passou expectedHash nulo e
        um terceiro criou o arquivo antes desta entrada. Devolve status, hash e backup.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$EncodingKind = 'utf8-nobom',
        [string]$ExpectedHash,
        [Nullable[long]]$ExpectedLength = $null,
        [Nullable[datetime]]$ExpectedLastWriteTimeUtc = $null,
        [switch]$RequireExisting,
        [switch]$CreateExclusive,
        [switch]$WhatIf
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $fullPath
    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "XPZ_MCP_PARENT_MISSING: pasta pai nao existe: $parent"
    }
    if ($CreateExclusive -and $RequireExisting) {
        throw 'XPZ_MCP_INVALID_ARGS: CreateExclusive e RequireExisting sao mutuamente exclusivos'
    }

    $exists = Test-Path -LiteralPath $fullPath
    if ($exists -and -not (Test-McpRegularFile -Path $fullPath)) {
        throw "XPZ_MCP_TARGET_NOT_REGULAR: $fullPath"
    }
    if (-not $exists -and $RequireExisting) {
        throw "XPZ_MCP_TARGET_MISSING: $fullPath"
    }
    if ($CreateExclusive -and $exists) {
        throw "XPZ_MCP_RACE: destino surgiu antes da criacao exclusiva: $fullPath"
    }
    if ($exists) {
        $identity = Get-McpFileIdentity -Path $fullPath
        if (-not [string]::IsNullOrWhiteSpace($ExpectedHash) -and $identity.Hash -ne $ExpectedHash) {
            throw "XPZ_MCP_RACE: conteudo de $fullPath mudou antes da escrita"
        }
        if ($null -ne $ExpectedLength -and $identity.Length -ne [long]$ExpectedLength) {
            throw "XPZ_MCP_RACE: tamanho de $fullPath mudou antes da escrita"
        }
        if ($null -ne $ExpectedLastWriteTimeUtc -and $identity.LastWriteTimeUtc -ne [datetime]$ExpectedLastWriteTimeUtc) {
            throw "XPZ_MCP_RACE: mtime de $fullPath mudou antes da escrita"
        }
    }

    $newBytes = ConvertTo-McpTextBytes -Text $Text -EncodingKind $EncodingKind
    $newHash = Get-McpBytesHash -Bytes $newBytes
    if ($exists) {
        $oldBytes = [System.IO.File]::ReadAllBytes($fullPath)
        if ($oldBytes.Length -eq $newBytes.Length -and (Get-McpBytesHash -Bytes $oldBytes) -eq $newHash) {
            return [pscustomobject]@{
                Status     = 'unchanged'
                Path       = $fullPath
                BackupPath = $null
                Hash       = $newHash
                ByteCount  = $newBytes.Length
            }
        }
    }

    if ($WhatIf) {
        return [pscustomobject]@{
            Status     = 'planned'
            Path       = $fullPath
            BackupPath = $null
            Hash       = $newHash
            ByteCount  = $newBytes.Length
            Changed    = $true
        }
    }

    $lockPath = $fullPath + '.xpz-mcp.lock'
    $lockStream = $null
    $lockAcquired = $false
    $tempPath = $null
    $backupPath = $null
    $promoted = $false
    $createExclusive = [bool]$CreateExclusive -or (-not $exists)
    try {
        # CreateNew e a aquisicao real; so remove o lock no finally se esta execucao o criou
        # (perdedor concorrente nao pode apagar o .xpz-mcp.lock do vencedor).
        try {
            $lockStream = [System.IO.File]::Open(
                $lockPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
        } catch [System.IO.IOException] {
            throw "XPZ_MCP_LOCKED: lock existente em $lockPath; remova-o apenas apos confirmar que nao ha execucao ativa"
        }
        $lockAcquired = $true
        $lockPayload = [System.Text.Encoding]::UTF8.GetBytes("pid=$PID;utc=$([DateTime]::UtcNow.ToString('o'))")
        $lockStream.Write($lockPayload, 0, $lockPayload.Length)
        $lockStream.Flush($true)

        if ($createExclusive) {
            if (Test-Path -LiteralPath $fullPath) {
                throw "XPZ_MCP_RACE: destino surgiu antes da criacao exclusiva: $fullPath"
            }
        } else {
            if (-not (Test-Path -LiteralPath $fullPath)) {
                throw "XPZ_MCP_RACE: destino sumiu durante a substituicao: $fullPath"
            }
            if (-not (Test-McpRegularFile -Path $fullPath)) {
                throw "XPZ_MCP_TARGET_NOT_REGULAR: $fullPath"
            }
            $lockedIdentity = Get-McpFileIdentity -Path $fullPath
            if (-not [string]::IsNullOrWhiteSpace($ExpectedHash) -and $lockedIdentity.Hash -ne $ExpectedHash) {
                throw "XPZ_MCP_RACE: conteudo de $fullPath mudou durante a escrita"
            }
            if ($null -ne $ExpectedLength -and $lockedIdentity.Length -ne [long]$ExpectedLength) {
                throw "XPZ_MCP_RACE: tamanho de $fullPath mudou durante a escrita"
            }
            if ($null -ne $ExpectedLastWriteTimeUtc -and $lockedIdentity.LastWriteTimeUtc -ne [datetime]$ExpectedLastWriteTimeUtc) {
                throw "XPZ_MCP_RACE: mtime de $fullPath mudou durante a escrita"
            }
        }

        $leaf = Split-Path -Leaf $fullPath
        $tempPath = Join-Path $parent ('.' + $leaf + '.xpz-mcp.' + [Guid]::NewGuid().ToString('N') + '.tmp')
        $tempStream = [System.IO.File]::Open(
            $tempPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        try {
            $tempStream.Write($newBytes, 0, $newBytes.Length)
            $tempStream.Flush($true)
        } finally {
            $tempStream.Dispose()
        }
        $tempHash = Get-McpFileHash -Path $tempPath
        if ($tempHash -ne $newHash) {
            throw "XPZ_MCP_TEMP_VERIFY_FAILED: hash do temporario diverge do conteudo montado"
        }

        if ($createExclusive) {
            if (Test-Path -LiteralPath $fullPath) {
                throw "XPZ_MCP_RACE: destino surgiu antes da criacao exclusiva: $fullPath"
            }
            $destStream = $null
            try {
                try {
                    $destStream = [System.IO.File]::Open(
                        $fullPath,
                        [System.IO.FileMode]::CreateNew,
                        [System.IO.FileAccess]::Write,
                        [System.IO.FileShare]::None
                    )
                } catch [System.IO.IOException] {
                    throw "XPZ_MCP_RACE: falha na criacao exclusiva de $fullPath :: $($_.Exception.Message)"
                }
                $destStream.Write($newBytes, 0, $newBytes.Length)
                $destStream.Flush($true)
            } finally {
                if ($null -ne $destStream) {
                    $destStream.Dispose()
                }
            }
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            $tempPath = $null
        } else {
            $stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
            $backupPath = $fullPath + '.xpz-mcp.bak-' + $stamp
            [System.IO.File]::Replace($tempPath, $fullPath, $backupPath, $true)
            $tempPath = $null
        }
        $promoted = $true

        $writtenHash = Get-McpFileHash -Path $fullPath
        if ($writtenHash -ne $newHash) {
            throw "XPZ_MCP_WRITE_VERIFY_FAILED: hash gravado diverge do planejado"
        }

        return [pscustomobject]@{
            Status     = 'written'
            Path       = $fullPath
            BackupPath = $backupPath
            Hash       = $newHash
            ByteCount  = $newBytes.Length
        }
    } finally {
        if ($null -ne $lockStream) {
            $lockStream.Dispose()
            $lockStream = $null
        }
        if ($lockAcquired -and (Test-Path -LiteralPath $lockPath)) {
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        }
        if (-not $promoted -and $null -ne $tempPath -and (Test-Path -LiteralPath $tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-McpJsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-McpRegularFile -Path $Path)) {
        return $null
    }
    $document = Read-McpTextDocument -Path $Path
    try {
        # -AsHashtable aceita chave vazia (lockfile npm tem packages[""]) e
        # devolve OrderedHashtable. Leitores que precisam de propriedades usam
        # os helpers abaixo, nunca PSObject.Properties direto em dicionario.
        return ($document.Text | ConvertFrom-Json -AsHashtable -Depth 30)
    } catch {
        throw "XPZ_MCP_JSON_INVALID: $Path :: $($_.Exception.Message)"
    }
}

function Get-McpKeyNames {
    param([Parameter(Mandatory = $true)]$Object)
    if ($Object -is [System.Collections.IDictionary]) {
        return @($Object.Keys)
    }
    return @($Object.PSObject.Properties.Name)
}

function Get-McpDictionaryValue {
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Object,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Key
    )
    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Key)) {
            return $Object[$Key]
        }
        return $null
    }
    $property = $Object.PSObject.Properties[$Key]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function ConvertTo-McpOrdered {
    param($Value)
    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[[string]$key] = ConvertTo-McpOrdered -Value $Value[$key]
        }
        return $result
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-McpOrdered -Value $property.Value
        }
        return $result
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += ConvertTo-McpOrdered -Value $item
        }
        return ,$items
    }
    return $Value
}

function Copy-McpJsonValue {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $copy[[string]$key] = Copy-McpJsonValue -Value $Value[$key]
        }
        return $copy
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $copy = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $copy[$property.Name] = Copy-McpJsonValue -Value $property.Value
        }
        return $copy
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) { $items += Copy-McpJsonValue -Value $item }
        return ,$items
    }
    return $Value
}

function Compare-McpJsonValue {
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Left,
        [Parameter(Mandatory = $true)][AllowNull()]$Right,
        [string]$Path = ''
    )
    $differences = [System.Collections.Generic.List[object]]::new()
    $leftIsDict = $Left -is [System.Collections.IDictionary]
    $rightIsDict = $Right -is [System.Collections.IDictionary]
    $leftIsObj = $Left -is [System.Management.Automation.PSCustomObject]
    $rightIsObj = $Right -is [System.Management.Automation.PSCustomObject]
    if (($leftIsDict -or $leftIsObj) -and ($rightIsDict -or $rightIsObj)) {
        if ($leftIsDict) {
            $leftKeys = @($Left.Keys)
        } else {
            $leftKeys = @($Left.PSObject.Properties.Name)
        }
        if ($rightIsDict) {
            $rightKeys = @($Right.Keys)
        } else {
            $rightKeys = @($Right.PSObject.Properties.Name)
        }
        $allKeys = @($leftKeys + $rightKeys | Sort-Object -Unique)
        foreach ($key in $allKeys) {
            $childPath = if ([string]::IsNullOrWhiteSpace($Path)) { [string]$key } else { $Path + '.' + $key }
            $hasLeft = $leftKeys -contains $key
            $hasRight = $rightKeys -contains $key
            if ($leftIsDict) {
                $leftValue = $Left[$key]
            } else {
                $leftValue = $Left.PSObject.Properties[$key].Value
            }
            if ($rightIsDict) {
                $rightValue = $Right[$key]
            } else {
                $rightValue = $Right.PSObject.Properties[$key].Value
            }
            if (-not $hasLeft) {
                $differences.Add([pscustomobject]@{ path = $childPath; kind = 'added'; left = $null; right = $rightValue }) | Out-Null
                continue
            }
            if (-not $hasRight) {
                $differences.Add([pscustomobject]@{ path = $childPath; kind = 'removed'; left = $leftValue; right = $null }) | Out-Null
                continue
            }
            $child = Compare-McpJsonValue -Left $leftValue -Right $rightValue -Path $childPath
            foreach ($difference in $child) { $differences.Add($difference) | Out-Null }
        }
        return @($differences)
    }
    if ($Left -is [System.Collections.IEnumerable] -and $Left -isnot [string] -and
        $Right -is [System.Collections.IEnumerable] -and $Right -isnot [string]) {
        $leftItems = @($Left)
        $rightItems = @($Right)
        if ($leftItems.Count -ne $rightItems.Count) {
            $differences.Add([pscustomobject]@{ path = $Path; kind = 'array-length'; left = $leftItems.Count; right = $rightItems.Count }) | Out-Null
            return @($differences)
        }
        for ($i = 0; $i -lt $leftItems.Count; $i++) {
            $child = Compare-McpJsonValue -Left $leftItems[$i] -Right $rightItems[$i] -Path ($Path + '[' + $i + ']')
            foreach ($difference in $child) { $differences.Add($difference) | Out-Null }
        }
        return @($differences)
    }
    if ($Left -is [string] -or $Right -is [string]) {
        if ([string]$Left -cne [string]$Right) {
            $differences.Add([pscustomobject]@{ path = $Path; kind = 'changed'; left = $Left; right = $Right }) | Out-Null
        }
        return @($differences)
    }
    if ($Left -ne $Right) {
        $differences.Add([pscustomobject]@{ path = $Path; kind = 'changed'; left = $Left; right = $Right }) | Out-Null
    }
    return @($differences)
}

function Write-McpJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value,
        [switch]$WhatIf
    )
    $json = (($Value | ConvertTo-Json -Depth 30) -replace "`r`n", "`n")
    if (-not $json.EndsWith("`n")) {
        $json += "`n"
    }
    $pathExisted = Test-Path -LiteralPath $Path
    $existing = $null
    if ($pathExisted) {
        $existing = Read-McpTextDocument -Path $Path
    }
    $expectedHash = $null
    $expectedLength = $null
    $expectedMtime = $null
    if ($null -ne $existing) {
        $expectedHash = $existing.Hash
        $expectedLength = [long]$existing.Length
        $expectedMtime = $existing.LastWriteTimeUtc
    }
    return Write-McpTextTransactional `
        -Path $Path `
        -Text $json `
        -EncodingKind 'utf8-nobom' `
        -ExpectedHash $expectedHash `
        -ExpectedLength $expectedLength `
        -ExpectedLastWriteTimeUtc $expectedMtime `
        -CreateExclusive:(-not $pathExisted) `
        -WhatIf:$WhatIf
}

function Assert-McpExactKeys {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string[]]$Expected,
        [Parameter(Mandatory = $true)][string]$Context
    )
    if ($null -eq $Object) {
        throw "XPZ_MCP_DESCRIPTOR_INVALID: $Context ausente"
    }
    $actual = @(Get-McpKeyNames -Object $Object | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    if (($actual -join '|') -ne ($wanted -join '|')) {
        throw "XPZ_MCP_DESCRIPTOR_INVALID: $Context com chaves [$($actual -join ',')]; esperado [$($wanted -join ',')]"
    }
}

function Test-McpStringArray {
    param($Value)
    if ($null -eq $Value) {
        return $false
    }
    foreach ($item in @($Value)) {
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
            return $false
        }
    }
    return $true
}

function Get-McpDescriptor {
    param([string]$RepoRoot = (Get-McpRepoRoot))
    $path = Join-Path (Resolve-McpFullPath -Path $RepoRoot) $script:McpDescriptorRelativePath
    if (-not (Test-McpRegularFile -Path $path)) {
        throw "XPZ_MCP_DESCRIPTOR_MISSING: $path"
    }
    $descriptor = Get-McpJsonFile -Path $path
    Assert-McpExactKeys -Object $descriptor -Expected @('schemaVersion', 'component', 'defaultMode', 'presets', 'modes') -Context 'descritor'
    if ($descriptor.schemaVersion -ne 1) {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: schemaVersion deve ser 1'
    }
    Assert-McpExactKeys -Object $descriptor.component -Expected @(
        'id', 'displayName', 'package', 'version', 'tarballIntegrity', 'distEntry', 'license', 'engines'
    ) -Context 'component'
    if ([string]::IsNullOrWhiteSpace([string]$descriptor.component.id)) {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.id vazio'
    }
    if ([string]$descriptor.component.package -notmatch '^@[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*$') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.package fora do formato npm'
    }
    if ([string]$descriptor.component.version -notmatch '^\d+\.\d+\.\d+$') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.version deve ser semver exato'
    }
    if ([string]$descriptor.component.tarballIntegrity -notmatch '^sha512-[A-Za-z0-9+/=]+$') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.tarballIntegrity deve ser sha512'
    }
    if ([string]$descriptor.component.distEntry -ne 'dist/index.js') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.distEntry inesperado'
    }
    if ([string]$descriptor.component.license -ne 'MIT') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.license deve ser MIT'
    }
    Assert-McpExactKeys -Object $descriptor.component.engines -Expected @('node') -Context 'component.engines'
    if ([string]$descriptor.component.engines.node -ne '>=22') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: component.engines.node deve ser >=22'
    }

    $presetNames = @(Get-McpKeyNames -Object $descriptor.presets)
    if ($presetNames.Count -eq 0) {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: presets vazio'
    }
    foreach ($presetName in $presetNames) {
        $preset = $descriptor.presets.$presetName
        Assert-McpExactKeys -Object $preset -Expected @('displayName', 'baseUrl', 'model') -Context "preset $presetName"
        if ([string]$preset.baseUrl -notmatch '^https://[^\s]+$') {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: preset $presetName com baseUrl invalida"
        }
        if ([string]::IsNullOrWhiteSpace([string]$preset.model)) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: preset $presetName com model vazio"
        }
    }

    $modeNames = @(Get-McpKeyNames -Object $descriptor.modes)
    $implemented = @()
    foreach ($modeName in $modeNames) {
        $mode = $descriptor.modes.$modeName
        Assert-McpExactKeys -Object $mode -Expected @(
            'secretEnvVar', 'publicEnvVars', 'requiredFields', 'exclusiveEnvVars', 'implemented', 'preset', 'endpointRule'
        ) -Context "mode $modeName"
        if ([string]::IsNullOrWhiteSpace([string]$mode.secretEnvVar)) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName sem secretEnvVar"
        }
        if (-not (Test-McpStringArray -Value $mode.publicEnvVars)) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName com publicEnvVars invalido"
        }
        if (-not (Test-McpStringArray -Value $mode.requiredFields)) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName com requiredFields invalido"
        }
        if (-not (Test-McpStringArray -Value $mode.exclusiveEnvVars)) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName com exclusiveEnvVars invalido"
        }
        if ($mode.implemented -isnot [bool]) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName com implemented nao booleano"
        }
        if ($mode.implemented) {
            $implemented += $modeName
        }
        if ($null -ne $mode.preset -and -not ($presetNames -contains [string]$mode.preset)) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName aponta preset inexistente"
        }
        if (@('sdk', 'explicit-url') -notcontains [string]$mode.endpointRule) {
            throw "XPZ_MCP_DESCRIPTOR_INVALID: mode $modeName com endpointRule invalida"
        }
    }
    if ($implemented.Count -ne 1) {
        throw "XPZ_MCP_DESCRIPTOR_INVALID: exatamente um modo implementado e obrigatorio; encontrado [$($implemented -join ',')]"
    }
    if ($implemented[0] -ne 'compatible') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: o modo implementado da v1 deve ser compatible'
    }
    if (-not ($modeNames -contains [string]$descriptor.defaultMode)) {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: defaultMode inexistente'
    }
    if ([string]$descriptor.defaultMode -ne 'compatible') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: defaultMode da v1 deve ser compatible'
    }
    $compatible = $descriptor.modes.compatible
    if ([string]$compatible.secretEnvVar -ne 'JEV_API_KEY') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: compatible.secretEnvVar deve ser JEV_API_KEY'
    }
    if ((@($compatible.publicEnvVars) | Sort-Object) -join '|' -ne 'JEV_API_BASE_URL|JEV_MCP_MODEL') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: compatible.publicEnvVars inesperado'
    }
    if ((@($compatible.requiredFields) | Sort-Object) -join '|' -ne 'baseUrl|model') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: compatible.requiredFields inesperado'
    }
    if ([string]$compatible.preset -ne 'command-code') {
        throw 'XPZ_MCP_DESCRIPTOR_INVALID: compatible.preset deve ser command-code'
    }

    return [pscustomobject]@{
        Path       = $path
        Hash       = Get-McpFileHash -Path $path
        Descriptor = $descriptor
    }
}

function Get-McpConfigPath {
    return (Join-Path (Get-McpManagedRoot) 'config.json')
}

function Get-McpManifestPath {
    return (Join-Path (Get-McpManagedRoot) 'install-manifest.json')
}

function Get-McpConfig {
    $path = Get-McpConfigPath
    if (-not (Test-McpRegularFile -Path $path)) {
        return [pscustomobject]@{
            Exists = $false
            Path   = $path
            Value  = $null
            Error  = $null
        }
    }
    try {
        $value = Get-McpJsonFile -Path $path
    } catch {
        return [pscustomobject]@{
            Exists = $true
            Path   = $path
            Value  = $null
            Error  = $_.Exception.Message
        }
    }
    $errorMessage = $null
    try {
        Assert-McpExactKeys -Object $value -Expected @('schemaVersion', 'provider', 'baseUrl', 'model', 'endpointConfirmed') -Context 'config.json'
        if ($value.schemaVersion -ne 1) { throw 'config.json com schemaVersion invalido' }
        if ([string]$value.provider -ne 'compatible') { throw 'config.json com provider nao suportado' }
        if ([string]$value.baseUrl -notmatch '^https://[^\s]+$') { throw 'config.json com baseUrl invalida' }
        if ([string]::IsNullOrWhiteSpace([string]$value.model)) { throw 'config.json com model vazio' }
        if ($value.endpointConfirmed -isnot [bool]) { throw 'config.json com endpointConfirmed nao booleano' }
    } catch {
        $errorMessage = $_.Exception.Message
    }
    return [pscustomobject]@{
        Exists = $true
        Path   = $path
        Value  = $(if ($null -eq $errorMessage) { $value } else { $null })
        Error  = $errorMessage
    }
}

function Set-McpConfig {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][bool]$EndpointConfirmed,
        [switch]$WhatIf
    )
    $path = Get-McpConfigPath
    if ($WhatIf -and -not (Test-Path -LiteralPath (Split-Path -Parent $path) -PathType Container)) {
        return [pscustomobject]@{
            Status    = 'planned'
            Path      = $path
            BackupPath = $null
            Hash      = $null
            ByteCount = 0
            Changed   = $true
        }
    }
    if (-not $WhatIf) {
        $managedRoot = Ensure-McpManagedRoot
        # Set-McpAcl vive em McpVaultSupport.ps1 (dot-source antes de gravar config).
        $null = Set-McpAcl -Path $managedRoot -Directory
    }
    $value = [ordered]@{
        schemaVersion     = 1
        provider          = 'compatible'
        baseUrl           = $BaseUrl
        model             = $Model
        endpointConfirmed = $EndpointConfirmed
    }
    $writeResult = Write-McpJsonFile -Path $path -Value $value -WhatIf:$WhatIf
    if (-not $WhatIf -and (Test-McpRegularFile -Path $path)) {
        $null = Set-McpAcl -Path $path
    }
    return $writeResult
}

function New-McpManifest {
    return [ordered]@{
        schemaVersion  = 1
        packageVersion = $null
        launchers      = @()
        clients        = [ordered]@{}
        e2e            = [ordered]@{}
    }
}

function Get-McpManifest {
    $path = Get-McpManifestPath
    if (-not (Test-McpRegularFile -Path $path)) {
        return [pscustomobject]@{
            Exists  = $false
            Corrupt = $false
            Path    = $path
            Error   = $null
            Value   = New-McpManifest
        }
    }
    try {
        $value = ConvertTo-McpOrdered -Value (Get-McpJsonFile -Path $path)
        Assert-McpExactKeys -Object $value -Expected @('schemaVersion', 'packageVersion', 'launchers', 'clients', 'e2e') -Context 'install-manifest.json'
        if ($value.schemaVersion -ne 1) {
            throw 'install-manifest.json com schemaVersion invalido'
        }
        return [pscustomobject]@{
            Exists  = $true
            Corrupt = $false
            Path    = $path
            Error   = $null
            Value   = $value
        }
    } catch {
        return [pscustomobject]@{
            Exists  = $true
            Corrupt = $true
            Path    = $path
            Error   = $_.Exception.Message
            Value   = New-McpManifest
        }
    }
}

function ConvertTo-McpCanonicalNode {
    <#
    .SYNOPSIS
        Normaliza um objeto para comparacao de conteudo: chaves de objetos em ordem alfabetica,
        recursivamente. A ordem dos arrays e preservada, porque nela ha significado.
    #>
    param($Node)
    if ($null -eq $Node) { return $null }
    if ($Node -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($Node.Keys | Sort-Object)) { $ordered[[string]$key] = ConvertTo-McpCanonicalNode -Node $Node[$key] }
        return $ordered
    }
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $ordered = [ordered]@{}
        foreach ($prop in @($Node.PSObject.Properties | Sort-Object -Property Name)) { $ordered[$prop.Name] = ConvertTo-McpCanonicalNode -Node $prop.Value }
        return $ordered
    }
    if (($Node -is [System.Collections.IEnumerable]) -and -not ($Node -is [string])) {
        return @(foreach ($item in $Node) { ConvertTo-McpCanonicalNode -Node $item })
    }
    return $Node
}

function Set-McpManifest {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [switch]$WhatIf
    )
    Assert-McpExactKeys -Object $Value -Expected @('schemaVersion', 'packageVersion', 'launchers', 'clients', 'e2e') -Context 'install-manifest.json'
    $path = Get-McpManifestPath
    if ($WhatIf -and -not (Test-Path -LiteralPath (Split-Path -Parent $path) -PathType Container)) {
        return [pscustomobject]@{
            Status     = 'planned'
            Path       = $path
            BackupPath = $null
            Hash       = $null
            ByteCount  = 0
            Changed    = $true
        }
    }
    if (-not $WhatIf) {
        $null = Ensure-McpManagedRoot
    }
    # Conteudo logico igual (so formatacao diferente, por edicao manual ou outra ferramenta):
    # nao regrava, nao cria backup e nao conta como mudanca. Um JSON invalido cai no caminho
    # normal de escrita, como antes.
    $sameLogical = $false
    if (Test-McpRegularFile -Path $path) {
        try {
            $existingNorm = (ConvertTo-McpCanonicalNode -Node (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json) | ConvertTo-Json -Depth 30 -Compress)
            $newNorm = (ConvertTo-McpCanonicalNode -Node ($Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json) | ConvertTo-Json -Depth 30 -Compress)
            $sameLogical = ($existingNorm -ceq $newNorm)
        } catch {
            $sameLogical = $false
        }
    }
    if ($sameLogical) {
        $existingBytes = [System.IO.File]::ReadAllBytes($path)
        $writeResult = [pscustomobject]@{
            Status     = 'unchanged'
            Path       = $path
            BackupPath = $null
            Hash       = Get-McpBytesHash -Bytes $existingBytes
            ByteCount  = $existingBytes.Length
            Changed    = $false
        }
    } else {
        $writeResult = Write-McpJsonFile -Path $path -Value $Value -WhatIf:$WhatIf
    }
    # ACL so-dono tambem em unchanged (repair): espelha Set-McpConfig.
    if (-not $WhatIf -and (Test-McpRegularFile -Path $path)) {
        $null = Set-McpAcl -Path $path
    }
    return $writeResult
}

function Get-McpManifestClient {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Client
    )
    if ($null -eq $Manifest.clients) {
        return $null
    }
    if ($Manifest.clients -is [System.Collections.IDictionary]) {
        if ($Manifest.clients.Contains($Client)) {
            return $Manifest.clients[$Client]
        }
        return $null
    }
    $property = $Manifest.clients.PSObject.Properties[$Client]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Add-McpManifestClientHash {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Client,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Hash,
        [datetime]$LastWriteUtc = [DateTime]::UtcNow
    )
    if ($null -eq $Manifest.clients) {
        $Manifest.clients = [ordered]@{}
    }
    if ($Manifest.clients -isnot [System.Collections.IDictionary]) {
        $Manifest.clients = ConvertTo-McpOrdered -Value $Manifest.clients
    }
    $current = Get-McpManifestClient -Manifest $Manifest -Client $Client
    $hashes = @()
    if ($null -ne $current -and $null -ne $current.hashes) {
        $hashes = @($current.hashes)
    }
    $newHashes = @($Hash)
    foreach ($existing in $hashes) {
        if ($newHashes -notcontains $existing) {
            $newHashes += $existing
        }
    }
    if ($newHashes.Count -gt 10) {
        $newHashes = @($newHashes[0..9])
    }
    $Manifest.clients[$Client] = [ordered]@{
        path             = $Path
        hashes           = $newHashes
        # Ticks em vez de string ISO: o ConvertFrom-Json converte datas ISO em
        # DateTime e o ConvertTo-Json as reescreve com precisao variavel,
        # quebrando a idempotencia do manifesto.
        lastWriteUtcTicks = $LastWriteUtc.Ticks
    }
    return $Manifest
}

function Remove-McpManifestClient {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Client
    )
    if ($null -ne $Manifest.clients) {
        if ($Manifest.clients -is [System.Collections.IDictionary]) {
            if ($Manifest.clients.Contains($Client)) {
                $Manifest.clients.Remove($Client)
            }
        } else {
            $property = $Manifest.clients.PSObject.Properties[$Client]
            if ($null -ne $property) {
                $Manifest.clients.PSObject.Properties.Remove($Client)
            }
        }
    }
    return $Manifest
}

function Get-McpManifestLauncher {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Version
    )
    foreach ($launcher in @($Manifest.launchers)) {
        if ([string]$launcher.version -eq $Version) {
            return $launcher
        }
    }
    return $null
}

function Set-McpManifestLauncher {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Sentinel,
        [Parameter(Mandatory = $true)][string]$Hash
    )
    $launchers = @($Manifest.launchers | Where-Object { [string]$_.version -ne $Version })
    $launchers += [ordered]@{
        version  = $Version
        path     = $Path
        sentinel = $Sentinel
        sha256   = $Hash
    }
    $Manifest.launchers = $launchers
    return $Manifest
}

function Test-McpClientInstalled {
    param([Parameter(Mandatory = $true)][ValidateSet('opencode', 'codex')][string]$Client)
    $profile = Get-McpProfileRoot
    if ($Client -eq 'opencode') {
        $root = Join-Path $profile '.config\opencode'
        if (Test-McpRegularFile -Path (Join-Path $root 'opencode.json')) { return $true }
        if (Test-McpRegularFile -Path (Join-Path $root 'opencode.jsonc')) { return $true }
        return (Get-McpCommandInfo -Name 'opencode' -VersionArguments @('--version')).Present
    }
    if (Test-McpRegularFile -Path (Join-Path $profile '.codex\config.toml')) { return $true }
    return (Get-McpCommandInfo -Name 'codex' -VersionArguments @('--version')).Present
}

function Test-McpCommandVersionOutput {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )

    $pattern = switch -Regex ($Name) {
        '^pwsh$' { '^\s*\d+\.\d+(?:\.\d+){0,2}\s*$'; break }
        '^(node|npm)$' { '^\s*v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?\s*$'; break }
        '^(python|py)$' { '^\s*Python\s+\d+\.\d+(?:\.\d+)?\s*$'; break }
        '^opencode$' { '^\s*opencode\s+v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?\s*$'; break }
        '^codex$' { '^\s*codex-cli\s+\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\s*$'; break }
        '^(nvm|fnm|volta|winget)$' { '^\s*(?:(?:nvm|fnm|volta|winget)\s+)?v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?\s*$'; break }
        default { return $false }
    }

    foreach ($line in @($Text -split '\r?\n')) {
        if ([regex]::IsMatch($line, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Invoke-McpCommandVersionProbe {
    <#
    .SYNOPSIS
        Sonda um executavel sem abrir janela de console (CreateNoWindow).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$VersionArguments = @('--version'),
        [int]$TimeoutMs = 8000
    )
    $probe = Invoke-XpzProcessProbe -FilePath $Path -ArgumentList $VersionArguments -TimeoutMs $TimeoutMs
    if (-not $probe.Succeeded) { return $null }
    $text = ([string]$probe.Output).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text
}

function Get-McpCommandInfo {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$VersionArguments = @('--version')
    )
    $commands = @(Get-Command -Name $Name -All -ErrorAction SilentlyContinue)
    if ($commands.Count -eq 0) {
        return [pscustomobject]@{
            Present = $false
            Stub    = $false
            Name    = $Name
            Path    = $null
            Version = $null
        }
    }
    if ($Name -eq 'pwsh') {
        # Os clientes gravam o comando literal 'pwsh' e o resolvem pelo PATH: audita-se o mesmo
        # executavel, o primeiro na ordem do PATH (Get-Command -All preserva essa ordem). Se ele
        # nao for utilizavel, o cliente tambem falharia; nao se procura outro mais adiante.
        $ranked = @($commands | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Source) } | Select-Object -First 1)
    } else {
        # node/npm/python: o install grava caminho absoluto, entao se prefere fora de WindowsApps.
        # Nessa pasta ficam o stub da Store e executaveis de pacotes versionados de outros apps
        # (o caminho muda na atualizacao do pacote): sao recusados sem sondar.
        $ranked = @($commands | Sort-Object @(
                @{ Expression = { if ([string]$_.Source -match '\\WindowsApps\\') { 1 } else { 0 } } },
                @{ Expression = { [string]$_.Source } }
            ))
    }
    $sawWindowsAppsStub = $false
    $lastWaPath = $null
    foreach ($command in $ranked) {
        $path = [string]$command.Source
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $isWindowsApps = $path -match '\\WindowsApps\\'
        if ($isWindowsApps -and $Name -ne 'pwsh') {
            $sawWindowsAppsStub = $true
            $lastWaPath = $path
            continue
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $fileInfo = Get-Item -LiteralPath $path -Force
        if ($fileInfo.Length -eq 0) {
            if ($isWindowsApps) {
                $sawWindowsAppsStub = $true
                $lastWaPath = $path
            }
            continue
        }
        $versionText = Invoke-McpCommandVersionProbe -Path $path -VersionArguments $VersionArguments
        if ([string]::IsNullOrWhiteSpace($versionText) -or -not (Test-McpCommandVersionOutput -Name $Name -Text $versionText)) {
            if ($isWindowsApps) {
                $sawWindowsAppsStub = $true
                $lastWaPath = $path
            }
            continue
        }
        return [pscustomobject]@{
            Present = $true
            Stub    = $false
            Name    = $Name
            Path    = $path
            Version = $versionText
        }
    }
    return [pscustomobject]@{
        Present = $false
        Stub    = $sawWindowsAppsStub
        Name    = $Name
        Path    = $lastWaPath
        Version = $null
    }
}

function Get-McpPrerequisites {
    $pwsh = Get-McpCommandInfo -Name 'pwsh' -VersionArguments @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
    $node = Get-McpCommandInfo -Name 'node' -VersionArguments @('--version')
    $npm = Get-McpCommandInfo -Name 'npm' -VersionArguments @('--version')
    $python = Get-McpCommandInfo -Name 'python' -VersionArguments @('--version')
    if (-not $python.Present) {
        $python = Get-McpCommandInfo -Name 'py' -VersionArguments @('-3', '--version')
    }

    $pwshVersion = $null
    $pwshCompatible = $false
    if ($pwsh.Present -and -not [string]::IsNullOrWhiteSpace($pwsh.Version)) {
        $match = [regex]::Match([string]$pwsh.Version, '(\d+)\.(\d+)(?:\.(\d+))?')
        if ($match.Success) {
            $build = if ($match.Groups[3].Success) { [int]$match.Groups[3].Value } else { 0 }
            $pwshVersion = [version]::new([int]$match.Groups[1].Value, [int]$match.Groups[2].Value, $build)
            $pwshCompatible = $pwshVersion -ge [version]'7.4.0'
        }
    }

    $nodeVersion = $null
    $nodeCompatible = $false
    if ($node.Present -and -not [string]::IsNullOrWhiteSpace($node.Version)) {
        $match = [regex]::Match($node.Version, 'v?(\d+)\.(\d+)\.(\d+)')
        if ($match.Success) {
            $nodeVersion = [version]::new([int]$match.Groups[1].Value, [int]$match.Groups[2].Value, [int]$match.Groups[3].Value)
            $nodeCompatible = $nodeVersion -ge [version]'22.0.0'
        }
    }

    $pythonVersion = $null
    $pythonCompatible = $false
    if ($python.Present -and -not [string]::IsNullOrWhiteSpace($python.Version)) {
        $match = [regex]::Match($python.Version, '(\d+)\.(\d+)')
        if ($match.Success) {
            $pythonVersion = [version]::new([int]$match.Groups[1].Value, [int]$match.Groups[2].Value)
            $pythonCompatible = $pythonVersion -ge [version]'3.11'
        }
    }

    $versionManagers = @()
    foreach ($manager in @('nvm', 'fnm', 'volta')) {
        $info = Get-McpCommandInfo -Name $manager -VersionArguments @('--version')
        if ($info.Present) {
            $versionManagers += $manager
        }
    }

    $winget = Get-McpCommandInfo -Name 'winget' -VersionArguments @('--version')
    return [pscustomobject]@{
        Pwsh             = $pwsh
        Node             = $node
        Npm              = $npm
        Python           = $python
        PwshVersion      = $pwshVersion
        PwshCompatible   = $pwshCompatible
        NodeVersion      = $nodeVersion
        NodeCompatible   = $nodeCompatible
        PythonVersion    = $pythonVersion
        PythonCompatible = $pythonCompatible
        VersionManagers  = $versionManagers
        Winget           = $winget
    }
}

function Get-McpPrerequisiteFindings {
    param([Parameter(Mandatory = $true)]$Prerequisites)
    $findings = [System.Collections.Generic.List[object]]::new()
    if (-not $Prerequisites.Pwsh.Present) {
        $findings.Add((New-McpFinding -Code 'pwsh_ausente' -Class 'blocking' -Message 'pwsh 7.4+ nao encontrado ou nao utilizavel no PATH.')) | Out-Null
    } elseif (-not [bool]$Prerequisites.PwshCompatible) {
        $verLabel = if ($null -ne $Prerequisites.PwshVersion) { [string]$Prerequisites.PwshVersion } else { [string]$Prerequisites.Pwsh.Version }
        $findings.Add((New-McpFinding -Code 'pwsh_ausente' -Class 'blocking' -Message "pwsh $verLabel nao atende >= 7.4.")) | Out-Null
    }
    if (-not $Prerequisites.Node.Present) {
        if ($Prerequisites.Node.Stub) {
            $findings.Add((New-McpFinding -Code 'node_path_nao_resolve' -Class 'blocking' -Message 'node no PATH so existe em WindowsApps (stub da Microsoft Store ou executavel de pacote versionado de outro app); esse caminho e recusado sem sondagem. Instale o Node fora de WindowsApps.')) | Out-Null
        } else {
            $findings.Add((New-McpFinding -Code 'node_ausente' -Class 'blocking' -Message 'node nao encontrado no PATH.')) | Out-Null
        }
    } elseif (-not $Prerequisites.NodeCompatible) {
        $findings.Add((New-McpFinding -Code 'node_incompativel' -Class 'blocking' -Message "node $($Prerequisites.Node.Version) nao atende >= 22.")) | Out-Null
    }
    if ($Prerequisites.Node.Present -and -not $Prerequisites.Npm.Present) {
        $findings.Add((New-McpFinding -Code 'node_npm_ausente' -Class 'blocking' -Message 'node presente sem npm utilizavel; instalacao tratada como corrompida.')) | Out-Null
    }
    if (-not $Prerequisites.PythonCompatible) {
        $findings.Add((New-McpFinding -Code 'python_indisponivel' -Class 'warn' -Message 'Python 3.11+ nao encontrado; o adaptador do Codex cai em edicao_manual_necessaria.')) | Out-Null
    }
    return @($findings)
}

function New-McpFinding {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][ValidateSet('blocking', 'warn')][string]$Class,
        [Parameter(Mandatory = $true)][string]$Message,
        [AllowNull()][string]$Client = $null,
        $Details = $null
    )
    return [pscustomobject]@{
        code     = $Code
        class    = $Class
        message  = $Message
        client   = $Client
        details  = $Details
    }
}

function Resolve-McpTrapFailure {
    <#
    .SYNOPSIS
        Classifica excecao/mensagem de trap MCP em codigo de achado e exit.
    .DESCRIPTION
        Lock/corrida/ACL mapeiam para exit 67 (catalogo). Demais falhas internas → 69.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message)
    if ($Message -match 'XPZ_MCP_LOCKED') {
        return [pscustomobject]@{ Code = 'lock'; Class = 'blocking'; ExitCode = 67; Message = $Message }
    }
    if ($Message -match 'XPZ_MCP_RACE') {
        return [pscustomobject]@{ Code = 'race'; Class = 'blocking'; ExitCode = 67; Message = $Message }
    }
    if ($Message -match '(?i)ACL_NAO_APLICAVEL|acl_nao_aplicavel|XPZ_MCP_ACL') {
        return [pscustomobject]@{ Code = 'acl_nao_aplicavel'; Class = 'blocking'; ExitCode = 67; Message = $Message }
    }
    return [pscustomobject]@{ Code = 'erro_interno'; Class = 'blocking'; ExitCode = 69; Message = $Message }
}

function New-McpCredentialProbe {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][string]$Secret
    )
    $question = [ordered]@{
        type         = 'noul'
        instructions = 'This is a health probe; the statement is true.'
    }
    $body = [ordered]@{
        model     = $Model
        state     = 'xpz-mcp-integrations-setup credential probe'
        questions = [ordered]@{
            xpz_mcp_probe = $question
        }
    } | ConvertTo-Json -Depth 10 -Compress
    # Redirecionamento nao e seguido: a chave so vai para a URL configurada. O aviso de
    # redirecionamento excedido e nao-terminante (SilentlyContinue) para devolver a resposta 3xx;
    # sem isso, $ErrorActionPreference='Stop' transforma o aviso em excecao.
    try {
        $response = Invoke-WebRequest -Uri $BaseUrl -Method Post -Headers @{ Authorization = "Bearer $Secret" } `
            -ContentType 'application/json' -Body $body -SkipHttpErrorCheck -TimeoutSec 20 `
            -MaximumRedirection 0 -ErrorAction SilentlyContinue
    } catch {
        return [pscustomobject]@{ endpointReachable = $false; credentialVerified = $false; status = $null; reason = 'request_failed' }
    }
    if ($null -eq $response) {
        return [pscustomobject]@{ endpointReachable = $false; credentialVerified = $false; status = $null; reason = 'request_failed' }
    }
    $statusCode = [int]$response.StatusCode
    # 3xx: o endereco configurado nao e o endpoint real; por isso nao conta como alcancavel.
    $endpointReachable = -not ($statusCode -ge 300 -and $statusCode -lt 400)
    $credentialVerified = $false
    if ($statusCode -eq 200) {
        try {
            $parsed = $response.Content | ConvertFrom-Json -AsHashtable
            $answers = $parsed['answers']
            if ($answers -is [System.Collections.IDictionary] -and $answers.Contains('xpz_mcp_probe')) {
                $answer = $answers['xpz_mcp_probe']
                if ($answer -is [System.Collections.IDictionary] -and $answer.Contains('noul')) {
                    $noul = $answer['noul']
                    if ($noul -is [int] -or $noul -is [long] -or $noul -is [double] -or $noul -is [decimal]) {
                        $value = [double]$noul
                        if ($value -ge 0 -and $value -le 1) {
                            $credentialVerified = $true
                        }
                    }
                }
            }
        } catch {
            $credentialVerified = $false
        }
    }
    return [pscustomobject]@{
        endpointReachable    = $endpointReachable
        credentialVerified   = $credentialVerified
        status               = [int]$response.StatusCode
        reason               = $(if ($credentialVerified) { 'answers_ok' } elseif ([int]$response.StatusCode -ge 300 -and [int]$response.StatusCode -lt 400) { 'redirect_nao_seguido' } elseif ($endpointReachable) { 'endpoint_only' } else { 'request_failed' })
    }
}

function Write-McpInternalFailure {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message,
        [ValidateSet('audit', 'mutation', 'vendor', 'credential')][string]$Kind = 'mutation',
        [string]$ActionName = 'internal-error'
    )
    $classified = Resolve-McpTrapFailure -Message $Message
    $finding = [ordered]@{ code = [string]$classified.Code; class = [string]$classified.Class; message = [string]$classified.Message }
    $result = [ordered]@{
        schemaVersion  = 1
        kind           = "xpz-mcp-integrations-setup-$Kind"
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        exitCode       = [int]$classified.ExitCode
        findings       = @($finding)
    }
    $reportHint = if ([string]$classified.Code -eq 'erro_interno') {
        'Reporte o erro interno'
    } else {
        "Trate o achado '$($classified.Code)' (exit $($classified.ExitCode))"
    }
    switch ($Kind) {
        'audit' {
            $result.overall = 'INTEGRATIONS_GAPS'
            $result.nextActions = @("$reportHint; nenhum diagnostico completo foi produzido.")
        }
        'mutation' {
            $result.action = $ActionName
            $result.overall = 'INTEGRATIONS_GAPS'
            $result.changed = $false
            $result.planned = $false
            $result.clients = [ordered]@{}
            $result.vendor = $null
            $result.launcher = $null
            $result.config = $null
            $result.credential = $null
            $result.nextActions = @("$reportHint; nenhuma alteracao foi confirmada.")
        }
        'vendor' {
            $result.status = $(if ([string]$classified.Code -eq 'erro_interno') { 'internal_error' } else { [string]$classified.Code })
            $result.version = $null
            $result.vendorDir = $null
            $result.entryPath = $null
            $result.integrity = $null
            $result.logPath = $null
            $result.npmExitCode = $null
            $result.blockingReasons = @([string]$classified.Message)
        }
        'credential' {
            $result.action = $ActionName
            $result.status = 'failed'
            $result.written = $false
            $result.planned = $false
            $result.credential = [ordered]@{ exists = $false; source = 'vault-dpapi' }
            $result.nextActions = @("$reportHint; a credencial nao foi alterada.")
        }
    }
    [pscustomobject]$result | ConvertTo-Json -Depth 20
    exit ([int]$classified.ExitCode)
}

function Get-McpExitCodePrecedence {
    param([string]$RepoRoot = (Get-McpRepoRoot))
    if ($null -ne $script:McpExitCodePrecedenceCache) {
        return @($script:McpExitCodePrecedenceCache)
    }
    $catalog = Get-McpExitCodeCatalog -RepoRoot $RepoRoot
    $precedence = @($catalog.precedence | ForEach-Object { [int]$_ })
    if ($precedence.Count -eq 0) {
        throw 'XPZ_MCP_EXIT_PRECEDENCE_MISSING: campo precedence ausente ou vazio'
    }
    $script:McpExitCodePrecedenceCache = $precedence
    return @($precedence)
}

function Get-McpExitCodeRank {
    param([Parameter(Mandatory = $true)][int]$Code)
    $precedence = @(Get-McpExitCodePrecedence)
    $index = [Array]::IndexOf($precedence, $Code)
    if ($index -lt 0) {
        return $precedence.Count + 1
    }
    return $index
}

function Get-McpExitCodeForFindings {
    param([object[]]$Findings = @())
    $blocking = @($Findings | Where-Object { $_.class -eq 'blocking' })
    if ($blocking.Count -eq 0) {
        return 0
    }
    $map = @{
        credencial_ausente        = 61
        credencial_ilegivel       = 61
        config_ausente            = 62
        config_invalido           = 62
        endpoint_nao_confirmado   = 62
        endpoint_invalido         = 62
        node_ausente              = 63
        node_npm_ausente          = 63
        node_incompativel         = 63
        node_path_nao_resolve     = 63
        pwsh_ausente              = 63
        vendor_ausente            = 64
        vendor_divergente         = 64
        vendor_falhou             = 64
        launcher_ausente          = 65
        launcher_divergente       = 65
        entrada_quebrada          = 66
        entrada_divergente        = 66
        entrada_em_conflito       = 66
        edicao_manual_necessaria  = 67
        acl_nao_aplicavel         = 67
        credencial_ambigua        = 67
        lock                      = 67
        race                      = 67
        manifesto_corrompido      = 67
        atualizacao_sem_aprovacao = 67
        client_obrigatorio        = 67
        acao_invalida             = 67
        dados_compartilhados_em_uso = 67
        python_indisponivel       = 68
    }
    $codes = @()
    foreach ($finding in $blocking) {
        if ($map.ContainsKey([string]$finding.code)) {
            $codes += [int]$map[[string]$finding.code]
        } else {
            $codes += 60
        }
    }
    $precedence = @(Get-McpExitCodePrecedence)
    foreach ($code in $precedence) {
        if ($codes -contains $code) {
            return $code
        }
    }
    # Codigo blocking fora da precedencia (ex.: 68 se algum dia virar blocking).
    foreach ($code in $codes) {
        if ($code -ne 0) {
            return $code
        }
    }
    return 60
}

function Resolve-McpGapsExitCode {
    <#
    .SYNOPSIS
        Exit code para overall=INTEGRATIONS_GAPS: nunca 0.
    .DESCRIPTION
        Get-McpExitCodeForFindings devolve 0 quando so ha warns (ou nenhum
        blocking). Gaps estruturais (cliente pedido nao escrito, etc.) precisam
        de piso 60 conforme o catalogo (GAPS sem codigo especifico).
    #>
    param(
        [Parameter(Mandatory = $true)][ValidateSet('INTEGRATIONS_OK', 'INTEGRATIONS_GAPS')][string]$Overall,
        [object[]]$Findings = @()
    )
    if ($Overall -eq 'INTEGRATIONS_OK') {
        return 0
    }
    $code = Get-McpExitCodeForFindings -Findings $Findings
    if ($code -eq 0) {
        return 60
    }
    return $code
}

function Get-McpStateRank {
    param([Parameter(Mandatory = $true)][string]$State)
    $order = @(
        'nao_configurado',
        'escrito',
        'recarga_pendente',
        'boot_ok',
        'endpoint_alcancavel',
        'credencial_verificada',
        'e2e_opt_in_confirmado'
    )
    $index = [Array]::IndexOf($order, $State)
    if ($index -lt 0) {
        return 0
    }
    return $index
}

function Test-McpStateAtLeast {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][string]$Minimum
    )
    return (Get-McpStateRank -State $State) -ge (Get-McpStateRank -State $Minimum)
}

function Get-McpExitCodeCatalogPath {
    param([string]$RepoRoot = (Get-McpRepoRoot))
    return (Join-Path (Resolve-McpFullPath -Path $RepoRoot) $script:McpExitCodesRelativePath)
}

function Get-McpExitCodeCatalog {
    param([string]$RepoRoot = (Get-McpRepoRoot))
    $path = Get-McpExitCodeCatalogPath -RepoRoot $RepoRoot
    if (-not (Test-McpRegularFile -Path $path)) {
        throw "XPZ_MCP_EXIT_CATALOG_MISSING: $path"
    }
    return (Get-McpJsonFile -Path $path)
}

function Format-McpRedactedUrl {
    param([Parameter(Mandatory = $true)][string]$Url)
    try {
        $uri = [Uri]::new($Url)
        return ('{0}://{1}/<redacted>' -f $uri.Scheme, $uri.Host)
    } catch {
        return '<invalid-url>'
    }
}
