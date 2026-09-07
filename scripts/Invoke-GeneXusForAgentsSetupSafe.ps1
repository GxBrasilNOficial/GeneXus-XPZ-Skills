#requires -Version 7.4

<#
.SYNOPSIS
    Wrapper seguro do GeneXus for Agents: roda o setup (opcional) e reaplica
    junctions/symlinks de nexa/gam para o payload oficial.

.DESCRIPTION
    O gx4a-setup oficial copia pastas reais de nexa/gam nos diretórios de skills
    das ferramentas e remove symlinks/junctions existentes. Este script:
      1) executa o instalador quando -SetupPath e informado (salvo -RepairOnly);
      2) remove copia opaca / vinculo desatualizado;
      3) cria symlink (fallback junction) para
         %LOCALAPPDATA%\Programs\GeneXus\GeneXus4Agents\payload\skills\<nexa|gam>;
      4) opcionalmente revalida com Test-XpzSkillsRegistration.ps1.

    Nao impede o setup de copiar se ele for executado fora deste wrapper.
    Dono normativo: xpz-skills-setup/SKILL.md (opcao C / GENEXUS FOR AGENTS).

.PARAMETER SetupPath
    Caminho do instalador (ex.: gx4a-setup.exe baixado do Canary). Obrigatorio
    salvo -RepairOnly.

.PARAMETER SetupArgumentList
    Argumentos extras repassados ao instalador.

.PARAMETER RepairOnly
    Nao executa o setup; so reaplica os vinculos ao payload.

.PARAMETER Strategy
    compacta (padrao): .claude, .agents, .config/opencode, .gemini/config e
    sempre .cursor/skills (nativo Cursor obrigatorio). Inclui .codex/skills
    somente para nexa (Codex tambem coberto via .agents).
    expansiva: o mesmo conjunto e tambem .codex/skills para gam (alem de nexa).

.PARAMETER Skills
    Quais skills reparar. Default: nexa e gam.

.PARAMETER SkipAudit
    Nao invoca Test-XpzSkillsRegistration.ps1 ao final.

.PARAMETER AsJson
    Emite recibo JSON na saida padrao.

.EXAMPLE
    pwsh -NoProfile -File scripts/Invoke-GeneXusForAgentsSetupSafe.ps1 -RepairOnly -AsJson

.EXAMPLE
    pwsh -NoProfile -File scripts/Invoke-GeneXusForAgentsSetupSafe.ps1 -SetupPath "$env:USERPROFILE\Downloads\gx4a-setup.exe"
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$SetupPath,

    [string[]]$SetupArgumentList = @(),

    [switch]$RepairOnly,

    [ValidateSet('compacta', 'expansiva')]
    [string]$Strategy = 'compacta',

    [ValidateSet('nexa', 'gam')]
    [string[]]$Skills = @('nexa', 'gam'),

    [switch]$SkipAudit,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProfileRoot {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'BLOCK: USERPROFILE nao definido.'
    }
    return $env:USERPROFILE
}

function Get-GeneXus4AgentsRoot {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'BLOCK: LOCALAPPDATA nao definido.'
    }
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

function Get-LinkTargetPath {
    param([System.IO.FileSystemInfo]$Item)
    if (-not $Item.LinkType) { return '' }
    $target = $Item.Target
    if ($null -eq $target) { return '' }
    $arr = @($target)
    if ($arr.Count -eq 0) { return '' }
    return [string]$arr[0]
}

function Get-PreferredSkillPath {
    param([Parameter(Mandatory = $true)][string]$SkillName)
    $root = Get-GeneXus4AgentsRoot
    $path = Join-Path $root ('payload\skills\' + $SkillName)
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw ("BLOCK: payload da skill '{0}' nao encontrado: {1}" -f $SkillName, $path)
    }
    $skillMd = Join-Path $path 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
        throw ("BLOCK: SKILL.md ausente no payload: {0}" -f $skillMd)
    }
    return (Get-Item -LiteralPath $path).FullName
}

function Get-SkillLinkDestinationRels {
    param(
        [Parameter(Mandatory = $true)][string]$SkillName,
        [Parameter(Mandatory = $true)][string]$StrategyName
    )

    # Compacta + .agents (Codex/OpenCode/Antigravity) + .cursor (nativo Cursor obrigatorio).
    $rels = [System.Collections.Generic.List[string]]::new()
    [void]$rels.Add('.claude\skills')
    [void]$rels.Add('.agents\skills')
    [void]$rels.Add('.config\opencode\skills')
    [void]$rels.Add('.gemini\config\skills')
    [void]$rels.Add('.cursor\skills')

    if ($SkillName -eq 'nexa' -or $StrategyName -eq 'expansiva') {
        [void]$rels.Add('.codex\skills')
    }

    # Dedup preservando ordem
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $rels) {
        if ($seen.Add($r)) { [void]$out.Add($r) }
    }
    return @($out)
}

function New-SkillLinkToPreferred {
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath,
        [Parameter(Mandatory = $true)][string]$PreferredPath
    )

    $parent = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $action = 'create'
    $linkTypeUsed = ''
    if (Test-Path -LiteralPath $LinkPath) {
        $item = Get-Item -LiteralPath $LinkPath -Force
        if ($item.LinkType) {
            $current = Get-LinkTargetPath -Item $item
            if (Test-SamePath -A $current -B $PreferredPath) {
                return [ordered]@{
                    path = $LinkPath; action = 'unchanged'; linkType = [string]$item.LinkType
                    target = $PreferredPath; error = ''
                }
            }
            if ($PSCmdlet.ShouldProcess($LinkPath, 'Remover vinculo desatualizado')) {
                Remove-Item -LiteralPath $LinkPath -Force
                $action = 'retarget'
            }
            else {
                return [ordered]@{
                    path = $LinkPath; action = 'skipped'; linkType = [string]$item.LinkType
                    target = $current; error = 'ShouldProcess recusou remocao do vinculo'
                }
            }
        }
        else {
            # Pasta real (copia opaca). Nunca seguir para dentro do payload.
            $full = $item.FullName
            if (Test-SamePath -A $full -B $PreferredPath) {
                throw ("BLOCK: recusa apagar a propria fonte preferida: {0}" -f $full)
            }
            if ($PSCmdlet.ShouldProcess($LinkPath, 'Remover copia opaca da skill')) {
                Remove-Item -LiteralPath $LinkPath -Recurse -Force
                $action = 'replace-copy'
            }
            else {
                return [ordered]@{
                    path = $LinkPath; action = 'skipped'; linkType = 'Directory'
                    target = $full; error = 'ShouldProcess recusou remocao da copia opaca'
                }
            }
        }
    }

    if (-not $PSCmdlet.ShouldProcess($LinkPath, ("Criar vinculo -> {0}" -f $PreferredPath))) {
        return [ordered]@{
            path = $LinkPath; action = 'skipped'; linkType = ''; target = ''; error = 'ShouldProcess recusou criacao'
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $PreferredPath -ErrorAction Stop | Out-Null
        $linkTypeUsed = 'SymbolicLink'
    }
    catch {
        New-Item -ItemType Junction -Path $LinkPath -Target $PreferredPath -ErrorAction Stop | Out-Null
        $linkTypeUsed = 'Junction'
    }

    return [ordered]@{
        path = $LinkPath; action = $action; linkType = $linkTypeUsed
        target = $PreferredPath; error = ''
    }
}

function Invoke-Gx4aSetup {
    param(
        [Parameter(Mandatory = $true)][string]$ExePath,
        [string[]]$ArgumentList
    )

    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        throw ("BLOCK: SetupPath nao encontrado: {0}" -f $ExePath)
    }
    $full = (Get-Item -LiteralPath $ExePath).FullName
    if (-not $PSCmdlet.ShouldProcess($full, 'Executar GeneXus for Agents setup')) {
        return [ordered]@{ ran = $false; exitCode = $null; path = $full; skipped = $true }
    }

    $args = @()
    if ($null -ne $ArgumentList -and @($ArgumentList).Count -gt 0) {
        $args = @($ArgumentList)
    }

    $p = Start-Process -FilePath $full -ArgumentList $args -Wait -PassThru -NoNewWindow
    return [ordered]@{
        ran = $true
        exitCode = [int]$p.ExitCode
        path = $full
        skipped = $false
    }
}

# --- Main --------------------------------------------------------------------
$profileRoot = Get-ProfileRoot
$gx4aRoot = Get-GeneXus4AgentsRoot
$scriptRoot = $PSScriptRoot
$auditScript = Join-Path $scriptRoot 'Test-XpzSkillsRegistration.ps1'

$setupResult = [ordered]@{ ran = $false; exitCode = $null; path = ''; skipped = $true }
if (-not $RepairOnly) {
    if ([string]::IsNullOrWhiteSpace($SetupPath)) {
        $defaultSetup = Join-Path $gx4aRoot 'payload\gx4a-setup.exe'
        if (Test-Path -LiteralPath $defaultSetup -PathType Leaf) {
            $SetupPath = $defaultSetup
        }
        else {
            throw 'BLOCK: informe -SetupPath ou use -RepairOnly (payload\gx4a-setup.exe nao encontrado).'
        }
    }
    $setupResult = Invoke-Gx4aSetup -ExePath $SetupPath -ArgumentList $SetupArgumentList
    if ([bool]$setupResult.ran -and $null -ne $setupResult.exitCode -and [int]$setupResult.exitCode -ne 0) {
        throw ("BLOCK: setup terminou com exit {0}: {1}" -f $setupResult.exitCode, $setupResult.path)
    }
}

$linkResults = [System.Collections.Generic.List[object]]::new()
foreach ($skill in @($Skills)) {
    $preferred = Get-PreferredSkillPath -SkillName $skill
    $destRels = Get-SkillLinkDestinationRels -SkillName $skill -StrategyName $Strategy
    foreach ($rel in $destRels) {
        $linkPath = Join-Path $profileRoot (Join-Path $rel $skill)
        $one = New-SkillLinkToPreferred -LinkPath $linkPath -PreferredPath $preferred
        $one['skill'] = $skill
        [void]$linkResults.Add($one)
    }
}

$audit = $null
if (-not $SkipAudit) {
    if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) {
        throw ("BLOCK: motor de auditoria ausente: {0}" -f $auditScript)
    }
    $json = & $auditScript -Strategy $Strategy -AsJson | Out-String
    $audit = $json | ConvertFrom-Json
}

$failedLinks = @($linkResults | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.error) })
$label = 'GX4A_SETUP_SAFE_OK'
if ($failedLinks.Count -gt 0) {
    $label = 'GX4A_SETUP_SAFE_PARTIAL'
}
if ($null -ne $audit -and [string]$audit.externalOverall -eq 'EXTERNAL_SKILLS_GAPS') {
    $label = 'GX4A_SETUP_SAFE_AUDIT_GAPS'
}

$result = [ordered]@{
    label           = $label
    repairOnly      = [bool]$RepairOnly
    strategy        = $Strategy
    gx4aRoot        = $gx4aRoot
    setup           = $setupResult
    links           = @($linkResults)
    failedLinkCount = $failedLinks.Count
    externalOverall = if ($null -ne $audit) { [string]$audit.externalOverall } else { $null }
    note            = 'Se o gx4a-setup rodar fora deste wrapper, as copias opacas podem voltar; use -RepairOnly ou repita o wrapper.'
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
    if ($label -ne 'GX4A_SETUP_SAFE_OK') { exit 2 }
    exit 0
}

Write-Output ("LABEL: {0}" -f $label)
Write-Output ("Strategy: {0} | RepairOnly: {1}" -f $Strategy, [bool]$RepairOnly)
if ([bool]$setupResult.ran) {
    Write-Output ("Setup: exit={0} path={1}" -f $setupResult.exitCode, $setupResult.path)
}
elseif ([bool]$setupResult.skipped -and -not $RepairOnly) {
    Write-Output 'Setup: skipped (ShouldProcess)'
}
Write-Output 'Links:'
foreach ($l in $linkResults) {
    Write-Output ("  [{0}] {1,-12} {2} -> {3} ({4})" -f $l.skill, $l.action, $l.path, $l.target, $l.linkType)
    if (-not [string]::IsNullOrWhiteSpace([string]$l.error)) {
        Write-Output ("           error: {0}" -f $l.error)
    }
}
if ($null -ne $audit) {
    Write-Output ("Audit externalOverall: {0}" -f $audit.externalOverall)
}
Write-Output $result.note
if ($label -ne 'GX4A_SETUP_SAFE_OK') { exit 2 }
exit 0
