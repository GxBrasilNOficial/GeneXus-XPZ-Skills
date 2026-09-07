#requires -Version 7.4

<#
.SYNOPSIS
    Auditoria deterministica do registro global das skills XPZ nas ferramentas de
    agente instaladas, mais o freshness do MCP global do Cursor.

.DESCRIPTION
    Mecaniza os passos de inventario, deteccao de instalacao e classificação do
    WORKFLOW de xpz-skills-setup. NÃO cria nem remove vinculos: apenas audita e
    classifica. As ações de resolucao continuam a cargo do agente, após confirmacao
    explicita do usuário.

    Classificação por skill x ferramenta instalada:
      OK                          vinculo valido em diretório nativo da ferramenta
      coberta_por_compatibilidade vinculo valido apenas em diretório lido por compat
      ausente                     nenhum vinculo valido encontrado
      quebrada                    vinculo presente, mas alvo inexistente
      copia_opaca                 pasta real (nao link) onde deveria haver vinculo
      fonte_desatualizada         link valido, mas alvo != fonte preferida atual

    Regras especiais (espelham xpz-skills-setup/SKILL.md):
      - Codex indexa DOIS ambitos USER (.codex/skills e .agents/skills); presenca
        em qualquer um conta como OK.
      - OpenCode exige vinculo nativo (.config/opencode/skills ou .agents/skills);
        não conta compatibilidade com .claude/skills.
      - Cursor: nativo obrigatorio apenas em ~/.cursor/skills; .agents/.claude/.codex
        sao compat e coberta_por_compatibilidade marca REGISTRATION_GAPS.

    Orfas: vinculos sob um diretório de skills cujo alvo aponta para DENTRO do
    repositório de skills XPZ, mas cujo nome não está mais no inventario da raiz.
    Vinculos para outros repositórios não contam como orfas do repo XPZ.

    Skills externas gerenciadas (`nexa`, `gam`) em externalSkills / externalOverall:
      - nexa: fonte preferida = a mais nova entre GeneXus-Skills-From-Zip\nexa e
        %LOCALAPPDATA%\Programs\GeneXus\GeneXus4Agents\payload\skills\nexa
        (empate → From-Zip). Bootstrap git (labels NEXA_*) só para roots From-Zip;
        junction correto ao payload Gx4A nao exige From-Zip em detectedRoots.
      - gam: fonte preferida unica = GeneXus4Agents\payload\skills\gam.
      - Copia opaca (Directory) ou link para alvo != preferida → EXTERNAL_SKILLS_GAPS.
      - Marcadores .skill-managed-nexa / .skill-managed-gam (quando existirem) sao
        evidencia corroborante exposta no recibo; nao substituem a classificacao.

    Freshness do MCP do Cursor (Candidato B): compara o server.py instalado com o
    canonico do repositório e valida config.json/registro em mcp.json.

.OUTPUTS
    Texto legivel por padrão; objeto JSON com -AsJson. Campos "overall" e os
    "label" são destinados a interpretacao por agente.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,

    [ValidateSet('compacta', 'expansiva')]
    [string]$Strategy = 'compacta',

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -Name XpzNativeLong -Namespace Xpz -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern uint GetLongPathName(string lpszShortPath, System.Text.StringBuilder lpszLongPath, uint cchBuffer);
'@ -ErrorAction SilentlyContinue | Out-Null

function ConvertTo-LongPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    try {
        $sb = New-Object System.Text.StringBuilder 1024
        $n = [Xpz.XpzNativeLong]::GetLongPathName($Path, $sb, [uint32]1024)
        if ($n -gt 0 -and $n -lt 1024) { return $sb.ToString() }
    }
    catch { }
    return $Path
}

function Resolve-RepoRoot {
    param([string]$Requested)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        return (Resolve-Path -LiteralPath $Requested).Path
    }
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw 'BLOCK: nao foi possivel inferir a raiz do repositorio a partir de PSScriptRoot.'
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Get-ProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'BLOCK: USERPROFILE nao definido.'
    }
    return $env:USERPROFILE
}

function Test-UsableCliOnPath {
    param([string]$Name)
    $cmds = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmds) { return $false }
    foreach ($cmd in @($cmds)) {
        if ([string]::IsNullOrWhiteSpace($cmd.Source)) { continue }
        if ($cmd.Source -match '\\WindowsApps\\') { continue }
        if (Test-Path -LiteralPath $cmd.Source -PathType Leaf) {
            try {
                if ((Get-Item -LiteralPath $cmd.Source).Length -gt 0) {
                    return $true
                }
            } catch {}
        }
    }
    return $false
}

function Test-ToolInstalled {
    param([string]$Tool)
    $profileRoot = Get-ProfileRoot
    switch ($Tool) {
        'ClaudeCode' {
            if (Get-Command claude -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\settings.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.claude\CLAUDE.md') -PathType Leaf) { return $true }
            return $false
        }
        'Codex' {
            if (Get-Command codex -ErrorAction SilentlyContinue) { return $true }
            if (Test-Path -LiteralPath (Join-Path $profileRoot '.codex\config.toml') -PathType Leaf) { return $true }
            return $false
        }
        'Cursor' {
            if (Get-Command cursor -ErrorAction SilentlyContinue) { return $true }
            $cursorRoot = Join-Path $profileRoot '.cursor'
            if (-not (Test-Path -LiteralPath $cursorRoot -PathType Container)) { return $false }
            foreach ($name in @('mcp.json', 'skills-cursor', 'rules')) {
                if (Test-Path -LiteralPath (Join-Path $cursorRoot $name)) { return $true }
            }
            return $false
        }
        'OpenCode' {
            if (Get-Command opencode -ErrorAction SilentlyContinue) { return $true }
            $configDir = Join-Path $profileRoot '.config\opencode'
            if (Test-Path -LiteralPath (Join-Path $configDir 'opencode.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $configDir 'opencode.jsonc') -PathType Leaf) { return $true }
            return $false
        }
        'Antigravity' {
            if (Test-UsableCliOnPath -Name 'agy') { return $true }
            if (Test-UsableCliOnPath -Name 'antigravity') { return $true }
            $geminiConfigDir = Join-Path $profileRoot '.gemini\config'
            if (Test-Path -LiteralPath (Join-Path $geminiConfigDir 'config.json') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $geminiConfigDir 'AGENTS.md') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $geminiConfigDir 'GEMINI.md') -PathType Leaf) { return $true }
            $geminiDir = Join-Path $profileRoot '.gemini'
            if (Test-Path -LiteralPath (Join-Path $geminiDir 'AGENTS.md') -PathType Leaf) { return $true }
            if (Test-Path -LiteralPath (Join-Path $geminiDir 'GEMINI.md') -PathType Leaf) { return $true }
            return $false
        }
    }
    return $false
}

function Get-LinkTarget {
    param([System.IO.FileSystemInfo]$Item)
    $target = $Item.Target
    if ($null -eq $target) { return '' }
    $arr = @($target)
    if ($arr.Count -eq 0) { return '' }
    return [string]$arr[0]
}

function Get-EntryInfo {
    param([string]$DirPath, [string]$Name)

    $full = Join-Path $DirPath $Name
    $info = [ordered]@{
        present     = $false
        linkType    = ''
        target      = ''
        targetValid = $false
    }
    if (-not (Test-Path -LiteralPath $full)) { return $info }

    $info.present = $true
    $item = Get-Item -LiteralPath $full -Force
    if ($item.LinkType) {
        $info.linkType = [string]$item.LinkType
        $info.target = Get-LinkTarget -Item $item
        $info.targetValid = (-not [string]::IsNullOrWhiteSpace($info.target)) -and (Test-Path -LiteralPath $info.target)
    }
    else {
        # Pasta/arquivo real (não e link). Conta como presente e valido.
        $info.linkType = 'Directory'
        $info.target = $full
        $info.targetValid = $true
    }
    return $info
}

function Get-SkillToolStatus {
    # Classifica UMA skill em UMA ferramenta, aplicando as mesmas regras nativo/compat
    # do loop interno. Usado para as skills externas gerenciadas (ex.: nexa), que vivem
    # fora do repo XPZ mas são auditadas por nome.
    param(
        [Parameter(Mandatory = $true)][string]$Skill,
        [Parameter(Mandatory = $true)]$ToolDef,
        [Parameter(Mandatory = $true)][string]$ProfileRoot
    )

    $status = 'ausente'; $linkType = ''; $target = ''

    foreach ($rel in $ToolDef.Native) {
        $entry = Get-EntryInfo -DirPath (Join-Path $ProfileRoot $rel) -Name $Skill
        if ($entry.present) {
            if ($entry.targetValid) {
                return [ordered]@{ status = 'OK'; linkType = $entry.linkType; target = $entry.target }
            }
            else {
                $status = 'quebrada'; $linkType = $entry.linkType; $target = $entry.target
            }
        }
    }

    if ($status -eq 'ausente') {
        foreach ($rel in $ToolDef.Compat) {
            $entry = Get-EntryInfo -DirPath (Join-Path $ProfileRoot $rel) -Name $Skill
            if ($entry.present -and $entry.targetValid) {
                return [ordered]@{ status = 'coberta_por_compatibilidade'; linkType = $entry.linkType; target = $entry.target }
            }
        }
    }

    return [ordered]@{ status = $status; linkType = $linkType; target = $target }
}

function ConvertTo-NormalizedUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $u = $Url.Trim().ToLowerInvariant()
    $u = $u.TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    return $u
}

function Find-GitExecutable {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )
    foreach ($c in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($c) -and (Test-Path -LiteralPath $c -PathType Leaf)) {
            return $c
        }
    }
    return $null
}

function Get-RepoOriginUrl {
    param(
        [Parameter(Mandatory = $true)][string]$GitExe,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) { return '' }
    $out = & $GitExe -C $RepoRoot remote get-url origin 2>&1
    if ($LASTEXITCODE -ne 0) { return '' }
    return ((@($out) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
}

function Get-NexaCanonicalRepoRoot {
    param([Parameter(Mandatory = $true)][string]$XpzRoot)

    $parent = [System.IO.Path]::GetDirectoryName($XpzRoot)
    return (Join-Path $parent 'GeneXus-Skills-From-Zip')
}

function Get-GeneXus4AgentsRoot {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { return '' }
    return (Join-Path $env:LOCALAPPDATA 'Programs\GeneXus\GeneXus4Agents')
}

function Test-SamePath {
    param([string]$A, [string]$B)
    if ([string]::IsNullOrWhiteSpace($A) -or [string]::IsNullOrWhiteSpace($B)) { return $false }
    try {
        $pa = [System.IO.Path]::GetFullPath($A)
        $pb = [System.IO.Path]::GetFullPath($B)
        return [string]::Equals($pa, $pb, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

function Get-SkillMdVersion {
    param([string]$SkillDir)
    $skillMd = Join-Path $SkillDir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) { return '' }
    $lines = @(Get-Content -LiteralPath $skillMd -TotalCount 40 -ErrorAction SilentlyContinue)
    if ($lines.Count -eq 0) { return '' }
    $inFm = $false
    foreach ($line in $lines) {
        if ($line -eq '---') {
            if (-not $inFm) { $inFm = $true; continue }
            break
        }
        if (-not $inFm) { continue }
        if ($line -match '^\s*version:\s*["'']?([^"''\s]+)["'']?\s*$') {
            return [string]$Matches[1]
        }
    }
    return ''
}

function Get-SkillSourceCandidate {
    param(
        [AllowEmptyString()][string]$SkillDir,
        [Parameter(Mandatory = $true)][string]$Kind
    )
    $info = [ordered]@{
        path           = $SkillDir
        kind           = $Kind
        present        = $false
        version        = ''
        skillMdTimeUtc = $null
    }
    if ([string]::IsNullOrWhiteSpace($SkillDir)) { return $info }
    if (-not (Test-Path -LiteralPath $SkillDir -PathType Container)) { return $info }
    $skillMd = Join-Path $SkillDir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) { return $info }
    $info.present = $true
    $info.version = Get-SkillMdVersion -SkillDir $SkillDir
    $info.skillMdTimeUtc = (Get-Item -LiteralPath $skillMd).LastWriteTimeUtc
    return $info
}

function Compare-SkillSourceFreshness {
    # 1 => A mais nova; -1 => B mais nova; 0 => empate.
    param($A, $B)
    if (-not [bool]$A.present -and -not [bool]$B.present) { return 0 }
    if ([bool]$A.present -and -not [bool]$B.present) { return 1 }
    if ([bool]$B.present -and -not [bool]$A.present) { return -1 }

    $verA = $null
    $verB = $null
    $hasA = -not [string]::IsNullOrWhiteSpace([string]$A.version) -and [version]::TryParse([string]$A.version, [ref]$verA)
    $hasB = -not [string]::IsNullOrWhiteSpace([string]$B.version) -and [version]::TryParse([string]$B.version, [ref]$verB)
    if ($hasA -and $hasB) {
        if ($verA -gt $verB) { return 1 }
        if ($verB -gt $verA) { return -1 }
    }
    elseif ($hasA -and -not $hasB) { return 1 }
    elseif ($hasB -and -not $hasA) { return -1 }

    if ($null -ne $A.skillMdTimeUtc -and $null -ne $B.skillMdTimeUtc) {
        if ($A.skillMdTimeUtc -gt $B.skillMdTimeUtc) { return 1 }
        if ($B.skillMdTimeUtc -gt $A.skillMdTimeUtc) { return -1 }
    }
    return 0
}

function Resolve-NexaPreferredSource {
    param([Parameter(Mandatory = $true)][string]$XpzRoot)

    $fromZipRoot = Get-NexaCanonicalRepoRoot -XpzRoot $XpzRoot
    $fromZip = Get-SkillSourceCandidate -SkillDir (Join-Path $fromZipRoot 'nexa') -Kind 'from-zip'
    $gx4aRoot = Get-GeneXus4AgentsRoot
    $payloadDir = if ([string]::IsNullOrWhiteSpace($gx4aRoot)) { '' } else { Join-Path $gx4aRoot 'payload\skills\nexa' }
    $payload = Get-SkillSourceCandidate -SkillDir $payloadDir -Kind 'gx4a-payload'

    $cmp = Compare-SkillSourceFreshness -A $payload -B $fromZip
    if ($cmp -gt 0) {
        $preferred = $payload
    }
    elseif ($cmp -lt 0) {
        $preferred = $fromZip
    }
    elseif ([bool]$fromZip.present) {
        $preferred = $fromZip
    }
    else {
        $preferred = $payload
    }

    return [ordered]@{
        preferredPath    = if ([bool]$preferred.present) { [string]$preferred.path } else { '' }
        preferredKind    = if ([bool]$preferred.present) { [string]$preferred.kind } else { 'missing' }
        preferredVersion = [string]$preferred.version
        fromZip          = $fromZip
        gx4aPayload      = $payload
        fromZipRepoRoot  = $fromZipRoot
        gx4aRoot         = $gx4aRoot
    }
}

function Resolve-GamPreferredSource {
    $gx4aRoot = Get-GeneXus4AgentsRoot
    $payloadDir = if ([string]::IsNullOrWhiteSpace($gx4aRoot)) { '' } else { Join-Path $gx4aRoot 'payload\skills\gam' }
    $payload = Get-SkillSourceCandidate -SkillDir $payloadDir -Kind 'gx4a-payload'
    return [ordered]@{
        preferredPath    = if ([bool]$payload.present) { [string]$payload.path } else { '' }
        preferredKind    = if ([bool]$payload.present) { 'gx4a-payload' } else { 'missing' }
        preferredVersion = [string]$payload.version
        fromZip          = $null
        gx4aPayload      = $payload
        fromZipRepoRoot  = ''
        gx4aRoot         = $gx4aRoot
    }
}

function Get-Gx4aSkillManagedPaths {
    param([Parameter(Mandatory = $true)][string]$SkillName)
    $root = Get-GeneXus4AgentsRoot
    if ([string]::IsNullOrWhiteSpace($root)) { return @() }
    $marker = Join-Path $root ('.skill-managed-' + $SkillName)
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { return @() }
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @(Get-Content -LiteralPath $marker -ErrorAction SilentlyContinue)) {
        $t = ([string]$line).Trim()
        if ($t -match '^[A-Za-z]:\\' -or $t -match '^\\\\') {
            [void]$paths.Add($t)
        }
    }
    return @($paths)
}

function Refine-ExternalToolStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [string]$LinkType,
        [string]$Target,
        [string]$PreferredPath
    )

    if ($Status -ne 'OK' -and $Status -ne 'coberta_por_compatibilidade') {
        return [ordered]@{ status = $Status; linkType = $LinkType; target = $Target; reason = '' }
    }
    if ([string]::IsNullOrWhiteSpace($PreferredPath)) {
        return [ordered]@{ status = $Status; linkType = $LinkType; target = $Target; reason = '' }
    }
    if ($LinkType -eq 'Directory') {
        return [ordered]@{ status = 'copia_opaca'; linkType = $LinkType; target = $Target; reason = 'directory-not-link' }
    }
    if (-not (Test-SamePath -A $Target -B $PreferredPath)) {
        return [ordered]@{ status = 'fonte_desatualizada'; linkType = $LinkType; target = $Target; reason = 'target-not-preferred' }
    }
    return [ordered]@{ status = $Status; linkType = $LinkType; target = $Target; reason = '' }
}

function Get-ExternalRepoBootstrapState {
    param(
        [AllowEmptyString()][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$OfficialUrl,
        [Parameter(Mandatory = $true)][string]$SkillName,
        [string]$GitExe
    )

    $skillPath = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { '' } else { Join-Path $RepoRoot $SkillName }
    $result = [ordered]@{
        repoRoot     = $RepoRoot
        label        = 'NEXA_REPO_MISSING'
        originUrl    = ''
        originOk     = $false
        skillPresent = $false
        skillPath    = $skillPath
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { return $result }

    if (Test-Path -LiteralPath $skillPath -PathType Container) {
        $result.skillPresent = (Test-Path -LiteralPath (Join-Path $skillPath 'SKILL.md') -PathType Leaf)
    }

    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) { return $result }

    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
        $children = @(Get-ChildItem -LiteralPath $RepoRoot -Force -ErrorAction SilentlyContinue)
        if ($children.Count -gt 0) {
            $result.label = 'NEXA_DIR_NOT_REPO'
        }
        return $result
    }

    if ([string]::IsNullOrWhiteSpace($GitExe)) {
        $result.label = 'GIT_UNAVAILABLE'
        return $result
    }

    $originUrl = Get-RepoOriginUrl -GitExe $GitExe -RepoRoot $RepoRoot
    if ([string]::IsNullOrWhiteSpace($originUrl)) {
        $result.label = 'NEXA_ORIGIN_MISSING'
        return $result
    }

    $result.originUrl = $originUrl
    $officialNorm = ConvertTo-NormalizedUrl -Url $OfficialUrl
    $originNorm = ConvertTo-NormalizedUrl -Url $originUrl
    if ($originNorm -eq $officialNorm) {
        $result.originOk = $true
        $result.label = 'NEXA_ALREADY_LINKED'
    }
    else {
        $result.label = 'NEXA_REMOTE_MISMATCH'
    }
    return $result
}

# --- Setup --------------------------------------------------------------------
$root = Resolve-RepoRoot -Requested $RepoRoot
$profileRoot = Get-ProfileRoot

# Inventario: subpastas da raiz que contem SKILL.md
$inventory = @(
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
        ForEach-Object { $_.Name } | Sort-Object
)
$inventorySet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $inventory) { [void]$inventorySet.Add($s) }

# Mapa de diretórios por ferramenta (nativo + compatibilidade)
# Cursor: nativo exigido e so ~/.cursor/skills (compacta e expansiva). .agents/.claude/.codex
# entram como compat — coberta_por_compatibilidade conta como REGISTRATION_GAPS.
$toolDefs = @(
    [ordered]@{ Name = 'ClaudeCode'; Native = @('.claude\skills'); Compat = @() },
    [ordered]@{ Name = 'Codex'; Native = @('.codex\skills', '.agents\skills'); Compat = @() },
    [ordered]@{ Name = 'Cursor'; Native = @('.cursor\skills'); Compat = @('.agents\skills', '.claude\skills', '.codex\skills') },
    [ordered]@{ Name = 'OpenCode'; Native = @('.config\opencode\skills', '.agents\skills'); Compat = @() },
    [ordered]@{ Name = 'Antigravity'; Native = @('.gemini\config\skills', '.agents\skills'); Compat = @() }
)

$toolsReport = @()
$sumOk = 0; $sumMissing = 0; $sumBroken = 0; $sumCompat = 0

foreach ($def in $toolDefs) {
    $installed = Test-ToolInstalled -Tool $def.Name
    $skillsStatus = @()

    if ($installed) {
        foreach ($skill in $inventory) {
            $status = 'ausente'; $linkType = ''; $target = ''

            foreach ($rel in $def.Native) {
                $dir = Join-Path $profileRoot $rel
                $entry = Get-EntryInfo -DirPath $dir -Name $skill
                if ($entry.present) {
                    if ($entry.targetValid) { $status = 'OK'; $linkType = $entry.linkType; $target = $entry.target; break }
                    else { $status = 'quebrada'; $linkType = $entry.linkType; $target = $entry.target }
                }
            }

            if ($status -eq 'ausente') {
                foreach ($rel in $def.Compat) {
                    $dir = Join-Path $profileRoot $rel
                    $entry = Get-EntryInfo -DirPath $dir -Name $skill
                    if ($entry.present -and $entry.targetValid) {
                        $status = 'coberta_por_compatibilidade'; $linkType = $entry.linkType; $target = $entry.target; break
                    }
                }
            }

            switch ($status) {
                'OK' { $sumOk++ }
                'coberta_por_compatibilidade' { $sumCompat++ }
                'quebrada' { $sumBroken++ }
                'ausente' { $sumMissing++ }
            }

            $skillsStatus += [ordered]@{ name = $skill; status = $status; linkType = $linkType; target = $target }
        }
    }

    $toolsReport += [ordered]@{
        name      = $def.Name
        installed = $installed
        native    = @($def.Native | ForEach-Object { Join-Path $profileRoot $_ })
        compat    = @($def.Compat | ForEach-Object { Join-Path $profileRoot $_ })
        skills    = $skillsStatus
    }
}

# Orfas: varrer cada diretório de skills conhecido uma única vez (deduplicado por caminho canonico)
$rootNorm = (ConvertTo-LongPath -Path $root).TrimEnd('\').ToLowerInvariant()
$allDirs = [System.Collections.Generic.List[string]]::new()
$seenCanonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($rel in @('.claude\skills', '.codex\skills', '.agents\skills', '.cursor\skills', '.config\opencode\skills', '.gemini\config\skills')) {
    $fullDir = Join-Path $profileRoot $rel
    if (Test-Path -LiteralPath $fullDir -PathType Container) {
        $canonical = (Resolve-Path -LiteralPath $fullDir).Path
        $canonLong = (ConvertTo-LongPath -Path $canonical).TrimEnd('\').ToLowerInvariant()
        if (-not $seenCanonical.Contains($canonLong)) {
            [void]$seenCanonical.Add($canonLong)
            [void]$allDirs.Add($fullDir)
        }
    }
}
$orphans = @()
foreach ($dir in $allDirs) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    foreach ($child in (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
        if ($inventorySet.Contains($child.Name)) { continue }
        $childItem = Get-Item -LiteralPath $child.FullName -Force -ErrorAction SilentlyContinue
        if ($null -eq $childItem) { continue }
        $tgt = Get-LinkTarget -Item $childItem
        if ([string]::IsNullOrWhiteSpace($tgt)) { continue }
        # Normaliza o alvo para caminho longo (expande short names 8.3) antes de comparar.
        $tgtResolved = (ConvertTo-LongPath -Path $tgt).TrimEnd('\').ToLowerInvariant()
        if ($tgtResolved.StartsWith($rootNorm)) {
            $orphans += [ordered]@{ dir = $dir; name = $child.Name; target = $tgt }
        }
    }
}

# --- Freshness do MCP do Cursor (Candidato B) ---------------------------------
function Get-CursorMcpReport {
    param([string]$ProfileRoot, [string]$RepoRoot)

    $report = [ordered]@{
        label              = 'MCP_NOT_INSTALLED'
        serverHashMatches  = $false
        agentsPath         = ''
        agentsPathValid    = $false
        registeredInMcpJson = $false
    }

    $mcpDir = Join-Path $ProfileRoot '.cursor\xpz-global-instructions-mcp'
    $installedServer = Join-Path $mcpDir 'server.py'
    $configPath = Join-Path $mcpDir 'config.json'
    $mcpJsonPath = Join-Path $ProfileRoot '.cursor\mcp.json'
    $repoServer = Join-Path $RepoRoot 'scripts\cursor-global-instructions-mcp\server.py'

    if (-not (Test-Path -LiteralPath $installedServer -PathType Leaf)) {
        return $report
    }

    # registro em mcp.json
    if (Test-Path -LiteralPath $mcpJsonPath -PathType Leaf) {
        try {
            $mcpJson = Get-Content -LiteralPath $mcpJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $mcpJson.mcpServers -and
                $null -ne $mcpJson.mcpServers.PSObject.Properties['xpz-global-instructions']) {
                $report.registeredInMcpJson = $true
            }
        }
        catch { }
    }

    # agentsPath
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $cfg = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $cfg.agentsPath -and -not [string]::IsNullOrWhiteSpace([string]$cfg.agentsPath)) {
                $report.agentsPath = [string]$cfg.agentsPath
                $report.agentsPathValid = Test-Path -LiteralPath $report.agentsPath -PathType Leaf
            }
        }
        catch { }
    }

    # hash do server
    if (Test-Path -LiteralPath $repoServer -PathType Leaf) {
        $installedHash = (Get-FileHash -LiteralPath $installedServer).Hash
        $repoHash = (Get-FileHash -LiteralPath $repoServer).Hash
        $report.serverHashMatches = ($installedHash -eq $repoHash)
    }

    if (-not $report.registeredInMcpJson -or -not $report.agentsPathValid) {
        $report.label = 'MCP_CONFIG_INVALID'
    }
    elseif (-not $report.serverHashMatches) {
        $report.label = 'MCP_SERVER_STALE'
    }
    else {
        $report.label = 'MCP_OK'
    }
    return $report
}

$cursorMcp = Get-CursorMcpReport -ProfileRoot $profileRoot -RepoRoot $root

# --- Skills externas gerenciadas (nexa + gam) ---------------------------------
# nexa: From-Zip comunitário e/ou payload GeneXus for Agents (fonte preferida = mais nova).
# gam: somente payload GeneXus for Agents.
$externalSkillDefs = @(
    [ordered]@{
        name        = 'nexa'
        repo        = 'GeneXus-Skills-From-Zip'
        officialUrl = 'https://github.com/GxBrasilNOficial/genexus-skills-from-zip.git'
        kind        = 'nexa'
    },
    [ordered]@{
        name        = 'gam'
        repo        = 'GeneXus4Agents'
        officialUrl = ''
        kind        = 'gam'
    }
)

$externalSkills = @()
$extHasGap = $false
$gitExe = Find-GitExecutable
foreach ($ext in $externalSkillDefs) {
    if ($ext.kind -eq 'nexa') {
        $preferred = Resolve-NexaPreferredSource -XpzRoot $root
    }
    else {
        $preferred = Resolve-GamPreferredSource
    }

    $managedPaths = @(Get-Gx4aSkillManagedPaths -SkillName $ext.name)
    $perTool = @()
    $detectedRoots = [System.Collections.Generic.List[string]]::new()
    $seenRoots = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $extHasRegistration = $false
    $extHasOpaqueOrStale = $false
    $preferredKind = [string]$preferred.preferredKind
    $preferredPath = [string]$preferred.preferredPath

    foreach ($def in $toolDefs) {
        $installed = Test-ToolInstalled -Tool $def.Name
        if (-not $installed) {
            $perTool += [ordered]@{
                name = $def.Name; installed = $false; status = 'nao_avaliada'
                linkType = ''; target = ''; reason = ''
            }
            continue
        }
        $cls = Get-SkillToolStatus -Skill $ext.name -ToolDef $def -ProfileRoot $profileRoot
        $refined = Refine-ExternalToolStatus -Status $cls.status -LinkType $cls.linkType -Target $cls.target -PreferredPath $preferredPath
        if ($refined.status -eq 'ausente' -or $refined.status -eq 'quebrada') {
            if ($preferredKind -ne 'missing') { $extHasGap = $true }
            elseif ($refined.status -eq 'quebrada') { $extHasGap = $true }
        }
        if ($refined.status -eq 'copia_opaca' -or $refined.status -eq 'fonte_desatualizada') {
            $extHasOpaqueOrStale = $true
            $extHasGap = $true
        }
        # Cursor exige vinculo nativo em ~/.cursor/skills; compat (.agents/.claude/.codex) e gap.
        if ($refined.status -eq 'coberta_por_compatibilidade' -and $def.Name -eq 'Cursor') {
            $extHasGap = $true
        }
        if ($refined.status -eq 'OK' -or $refined.status -eq 'coberta_por_compatibilidade' -or
            $refined.status -eq 'copia_opaca' -or $refined.status -eq 'fonte_desatualizada') {
            $extHasRegistration = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($refined.target)) {
            # Bootstrap git so se aplica a roots From-Zip. Alvo preferido gx4a-payload
            # nao entra em detectedRoots (evita falso NEXA_DIR_NOT_REPO / registro sem root).
            $isPreferredTarget = (Test-SamePath -A $refined.target -B $preferredPath)
            $includeForGitBootstrap = $false
            if ($ext.kind -eq 'nexa') {
                if ($isPreferredTarget) {
                    if ($preferredKind -eq 'from-zip') { $includeForGitBootstrap = $true }
                }
                else {
                    # Alvo nao preferido: so roots que parecem repo (tem .git) ou pasta nexa legada.
                    $parentProbe = [System.IO.Path]::GetDirectoryName($refined.target)
                    if (-not [string]::IsNullOrWhiteSpace($parentProbe) -and (Test-Path -LiteralPath (Join-Path $parentProbe '.git'))) {
                        $includeForGitBootstrap = $true
                    }
                    elseif ($refined.status -eq 'fonte_desatualizada') {
                        $includeForGitBootstrap = $true
                    }
                }
            }
            if ($includeForGitBootstrap) {
                $parent = [System.IO.Path]::GetDirectoryName($refined.target)
                if (-not [string]::IsNullOrWhiteSpace($parent)) {
                    $parentFull = [System.IO.Path]::GetFullPath($parent)
                    if ($seenRoots.Add($parentFull)) {
                        [void]$detectedRoots.Add($parentFull)
                    }
                }
            }
        }
        $perTool += [ordered]@{
            name      = $def.Name
            installed = $true
            status    = $refined.status
            linkType  = $refined.linkType
            target    = $refined.target
            reason    = $refined.reason
        }
    }

    $repoRootCanonical = [string]$preferred.fromZipRepoRoot
    $repoBootstrapCanonical = if ($ext.kind -eq 'nexa') {
        Get-ExternalRepoBootstrapState -RepoRoot $repoRootCanonical -OfficialUrl $ext.officialUrl -SkillName $ext.name -GitExe $gitExe
    }
    else {
        [ordered]@{
            repoRoot = ''; label = 'NEXA_REPO_MISSING'; originUrl = ''
            originOk = $false; skillPresent = $false; skillPath = ''
        }
    }

    $repoRootDetected = ''
    $repoBootstrapDetected = Get-ExternalRepoBootstrapState -RepoRoot '' -OfficialUrl $(if ($ext.officialUrl) { $ext.officialUrl } else { 'https://example.invalid/none.git' }) -SkillName $ext.name -GitExe $gitExe
    $extHasRepoGap = $false
    if ($ext.kind -eq 'nexa') {
        foreach ($rr in $detectedRoots) {
            $st = Get-ExternalRepoBootstrapState -RepoRoot $rr -OfficialUrl $ext.officialUrl -SkillName $ext.name -GitExe $gitExe
            $stFails = (-not [bool]$st.originOk) -or (-not [bool]$st.skillPresent) -or (
                @('NEXA_DIR_NOT_REPO', 'NEXA_ORIGIN_MISSING', 'GIT_UNAVAILABLE') -contains [string]$st.label
            )
            if ($extHasRegistration -and $stFails) { $extHasRepoGap = $true }

            $preferredFails = (-not [bool]$repoBootstrapDetected.originOk) -or (-not [bool]$repoBootstrapDetected.skillPresent) -or (
                @('NEXA_DIR_NOT_REPO', 'NEXA_ORIGIN_MISSING', 'GIT_UNAVAILABLE', 'NEXA_REPO_MISSING') -contains [string]$repoBootstrapDetected.label
            )
            if ([string]::IsNullOrWhiteSpace($repoRootDetected)) {
                $repoRootDetected = $rr
                $repoBootstrapDetected = $st
            }
            elseif ($stFails -and -not $preferredFails) {
                $repoRootDetected = $rr
                $repoBootstrapDetected = $st
            }
        }
        if ($extHasRegistration -and [string]::IsNullOrWhiteSpace($repoRootDetected)) {
            # Com fonte preferida gx4a-payload, ausencia de root git e esperada quando
            # os vinculos ja apontam ao payload (ou so ha copia_opaca sem root git).
            if ($preferredKind -eq 'from-zip') {
                $extHasRepoGap = $true
            }
            elseif ($preferredKind -eq 'missing') {
                $extHasRepoGap = $true
            }
            # preferredKind gx4a-payload: nao exige detectedRoots
        }
    }
    if ($extHasRepoGap) { $extHasGap = $true }
    if ($extHasOpaqueOrStale) { $extHasGap = $true }

    $resolveAction = 'none'
    if ($extHasOpaqueOrStale -or ($extHasGap -and $preferredKind -ne 'missing')) {
        if ($preferredKind -eq 'missing') {
            $resolveAction = 'blocked-no-preferred-source'
        }
        else {
            $resolveAction = 'replace-with-junction-to-preferred'
        }
    }

    $fromZipBehind = $false
    if ($ext.kind -eq 'nexa' -and $preferredKind -eq 'gx4a-payload' -and $null -ne $preferred.fromZip -and [bool]$preferred.fromZip.present) {
        $fromZipBehind = $true
    }

    $externalSkills += [ordered]@{
        name                   = $ext.name
        repo                   = $ext.repo
        officialUrl            = $ext.officialUrl
        kind                   = $ext.kind
        preferredPath          = $preferredPath
        preferredKind          = $preferredKind
        preferredVersion       = [string]$preferred.preferredVersion
        fromZipBehindPreferred = $fromZipBehind
        gx4aManagedPaths       = @($managedPaths)
        resolveAction          = $resolveAction
        repoRootDetected       = $repoRootDetected
        repoRootCanonical      = $repoRootCanonical
        repoBootstrapDetected  = $repoBootstrapDetected
        repoBootstrapCanonical = $repoBootstrapCanonical
        repoOriginOk           = [bool]$repoBootstrapDetected.originOk
        tools                  = $perTool
    }
}
if ($extHasGap) { $externalOverall = 'EXTERNAL_SKILLS_GAPS' } else { $externalOverall = 'EXTERNAL_SKILLS_OK' }

# --- Veredito -----------------------------------------------------------------
$mcpIsGap = @('MCP_SERVER_STALE', 'MCP_CONFIG_INVALID') -contains $cursorMcp.label
# coberta_por_compatibilidade no Cursor (falta ~/.cursor/skills) conta como gap —
# registro nativo em ~/.cursor/skills e obrigatorio quando o Cursor esta instalado.
$hasGaps = ($sumMissing -gt 0) -or ($sumBroken -gt 0) -or ($sumCompat -gt 0) -or (@($orphans).Count -gt 0) -or $mcpIsGap
if ($hasGaps) { $overall = 'REGISTRATION_GAPS' } else { $overall = 'REGISTRATION_OK' }

$result = [ordered]@{
    overall         = $overall
    externalOverall = $externalOverall
    repoRoot        = $root
    strategy        = $Strategy
    skillsInventory = @($inventory)
    tools           = $toolsReport
    orphans         = @($orphans)
    externalSkills  = @($externalSkills)
    cursorMcp       = $cursorMcp
    summary         = [ordered]@{
        ok              = $sumOk
        coveredByCompat = $sumCompat
        missing         = $sumMissing
        broken          = $sumBroken
        orphans         = @($orphans).Count
        cursorMcp       = $cursorMcp.label
        externalOverall = $externalOverall
    }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8 | Write-Output
    return
}

# Saida legivel
Write-Output ("OVERALL: {0}" -f $overall)
Write-Output ("Repo: {0}" -f $root)
Write-Output ("Inventario: {0} skills | Estrategia: {1}" -f @($inventory).Count, $Strategy)
Write-Output ''
foreach ($t in $toolsReport) {
    if (-not $t.installed) {
        Write-Output ("[{0}] nao instalada" -f $t.name)
        continue
    }
    Write-Output ("[{0}] instalada" -f $t.name)
    foreach ($s in $t.skills) {
        if ($s.status -ne 'OK') {
            Write-Output ("    {0,-28} {1}" -f $s.name, $s.status)
        }
    }
    $okCount = @($t.skills | Where-Object { $_.status -eq 'OK' }).Count
    Write-Output ("    ({0} OK; demais listadas acima, se houver)" -f $okCount)
}
Write-Output ''
if (@($orphans).Count -gt 0) {
    Write-Output 'Orfas (vinculo para o repo sem skill correspondente):'
    foreach ($o in $orphans) { Write-Output ("    {0}  ->  {1}" -f $o.name, $o.target) }
}
else {
    Write-Output 'Orfas: nenhuma'
}
Write-Output ("MCP Cursor: {0} (server atualizado={1}; registrado={2}; agentsPath valido={3})" -f `
        $cursorMcp.label, $cursorMcp.serverHashMatches, $cursorMcp.registeredInMcpJson, $cursorMcp.agentsPathValid)
Write-Output ''
Write-Output ("Skills externas gerenciadas: {0}" -f $externalOverall)
foreach ($ext in $externalSkills) {
    $repoInfo = if ([string]::IsNullOrWhiteSpace($ext.repoRootDetected)) { '(repo local nao detectado)' } else { $ext.repoRootDetected }
    $bootstrapLabel = [string]$ext.repoBootstrapDetected.label
    Write-Output ("  [{0}] repo={1} | preferred={2} ({3} v={4}) | resolve={5}" -f `
            $ext.name, $ext.repo, $ext.preferredKind, $ext.preferredPath, $ext.preferredVersion, $ext.resolveAction)
    Write-Output ("      local={0} | bootstrap={1} | originOk={2}" -f `
            $repoInfo, $bootstrapLabel, $ext.repoOriginOk)
    if (-not [string]::IsNullOrWhiteSpace([string]$ext.repoRootCanonical)) {
        Write-Output ("      canonico={0} | bootstrap={1} | fromZipBehind={2}" -f `
                $ext.repoRootCanonical, $ext.repoBootstrapCanonical.label, $ext.fromZipBehindPreferred)
    }
    if (@($ext.gx4aManagedPaths).Count -gt 0) {
        Write-Output ("      gx4a-managed: {0}" -f ((@($ext.gx4aManagedPaths) | Select-Object -First 4) -join '; '))
    }
    foreach ($pt in $ext.tools) {
        if (-not $pt.installed) { continue }
        if ($pt.status -eq 'OK') {
            Write-Output ("      {0,-12} {1}" -f $pt.name, $pt.status)
        }
        else {
            Write-Output ("      {0,-12} {1} {2}" -f $pt.name, $pt.status, $pt.reason)
        }
    }
}
Write-Output ''
Write-Output ("Resumo: OK={0} compat={1} ausentes={2} quebradas={3} orfas={4} | externas={5}" -f `
        $sumOk, $sumCompat, $sumMissing, $sumBroken, @($orphans).Count, $externalOverall)
