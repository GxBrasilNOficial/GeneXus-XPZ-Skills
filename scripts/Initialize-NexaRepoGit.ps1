#requires -Version 7.4

<#
.SYNOPSIS
    Garante que exista um clone local do repositório que hospeda a skill `nexa`,
    ligado ao remoto oficial no GitHub (GxBrasilNOficial/genexus-skills-from-zip).

.DESCRIPTION
    A skill `nexa` NÃO e um repositório próprio: vive como subpasta do repositório
    comunitário `GeneXus-Skills-From-Zip` (snapshot importado dos zips oficiais
    GeneXus). Esta skill (xpz-skills-setup) gerencia apenas `nexa` por nome.

    Diferenca em relacao a Initialize-XpzSkillsRepoGit.ps1: aquele bootstrap liga
    uma pasta JÁ existente (vinda de ZIP) e PROIBE clonar; aqui o repositório nexa
    pode nem existir na maquina, entao CLONAR e comportamento legitimo.

    Fluxo deterministico:
      1. Garante o executavel Git (instala via winget quando ausente e permitido).
      2. Resolve a raiz do repo nexa:
         a. parâmetro -NexaRepoRoot explicito; senao
         b. deteccao: le o alvo de qualquer vinculo global já existente de `nexa`
            (o vinculo aponta para <repo>\nexa; a raiz e a pasta-pai); senao
         c. default: pasta-irma da raiz XPZ (<pai-da-raiz-XPZ>\GeneXus-Skills-From-Zip).
         Em migração de clone legado (origin != oficial), NEXA_REMOTE_MISMATCH bloqueia
         sem reescrever o remoto; chamar de novo com -NexaRepoRoot = pasta canônica.
      3. Se a raiz já for repositório Git: confere se origin aponta para o oficial
         (tolera remotos extras, ex.: um `fork` pessoal). origin ausente -> adiciona.
      4. Se a pasta não existir ou estiver vazia: CLONA o oficial para a raiz.
      5. Se a pasta existir com conteúdo mas SEM .git: bloqueia (não sobrescreve).
      6. Confere se a subpasta da skill `nexa` existe no repo resolvido.

.OUTPUTS
    Texto legivel por padrão; objeto JSON com -AsJson. O campo "label" e
    deterministico e destinado a interpretacao por agente.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$NexaRepoRoot,

    [string]$NexaOfficialRemoteUrl = 'https://github.com/GxBrasilNOficial/genexus-skills-from-zip.git',

    [string]$DefaultBranch = 'main',

    [string]$NexaSkillName = 'nexa',

    [bool]$InstallGitIfMissing = $true,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GitExe = $null

function Write-Result {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Messages = @(),
        [string]$Remote = '',
        [string]$Branch = '',
        [string]$RepoRoot = '',
        [string]$SkillName = '',
        [string]$SkillPath = '',
        [bool]$SkillPresent = $false
    )

    $result = [ordered]@{
        status       = $Status
        label        = $Label
        remote       = $Remote
        branch       = $Branch
        repoRoot     = $RepoRoot
        skillName    = $SkillName
        skillPath    = $SkillPath
        skillPresent = $SkillPresent
        messages     = @($Messages)
    }

    if ($AsJson) {
        $result | ConvertTo-Json -Depth 6 | Write-Output
    }
    else {
        Write-Output ('{0}: {1}' -f $Status, $Label)
        if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) { Write-Output ('  repo: {0}' -f $RepoRoot) }
        if (-not [string]::IsNullOrWhiteSpace($SkillPath)) {
            Write-Output ('  skill {0}: {1} (presente={2})' -f $SkillName, $SkillPath, $SkillPresent)
        }
        foreach ($m in $Messages) { Write-Output ('  - {0}' -f $m) }
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string[]]$GitArgs,
        [switch]$AllowFailure
    )

    $out = & $script:GitExe @GitArgs 2>&1
    $code = $LASTEXITCODE
    $text = (@($out) | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "BLOCK: git $($GitArgs -join ' ') falhou (exit $code): $text"
    }
    return [pscustomobject]@{ ExitCode = $code; Text = $text }
}

function ConvertTo-NormalizedUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $u = $Url.Trim().ToLowerInvariant()
    $u = $u.TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    return $u
}

function Update-SessionPathFromEnvironment {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($machine)) { $parts += $machine }
    if (-not [string]::IsNullOrWhiteSpace($user)) { $parts += $user }
    if ($parts.Count -gt 0) { $env:Path = $parts -join ';' }
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

function Get-LinkTarget {
    param([System.IO.FileSystemInfo]$Item)
    $target = $Item.Target
    if ($null -eq $target) { return '' }
    $arr = @($target)
    if ($arr.Count -eq 0) { return '' }
    return [string]$arr[0]
}

function Find-ExistingNexaRepoRoot {
    param([string]$SkillName)

    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) { return $null }
    $profileRoot = $env:USERPROFILE
    $skillDirs = @(
        '.claude\skills', '.codex\skills', '.agents\skills',
        '.cursor\skills', '.config\opencode\skills'
    )
    foreach ($rel in $skillDirs) {
        $full = Join-Path (Join-Path $profileRoot $rel) $SkillName
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) { continue }
        $tgt = ''
        if ($item.LinkType) { $tgt = Get-LinkTarget -Item $item }
        if ([string]::IsNullOrWhiteSpace($tgt)) { continue }
        # O vinculo aponta para <repo>\<SkillName>; a raiz do repo e a pasta-pai.
        $repoCandidate = [System.IO.Path]::GetDirectoryName($tgt)
        if (-not [string]::IsNullOrWhiteSpace($repoCandidate) -and (Test-Path -LiteralPath $repoCandidate -PathType Container)) {
            return $repoCandidate
        }
    }
    return $null
}

function Resolve-XpzRepoRoot {
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw 'BLOCK: nao foi possivel inferir a raiz XPZ a partir de PSScriptRoot.'
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Resolve-NexaRepoRoot {
    param([string]$Requested, [string]$SkillName)

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        # Pode ainda não existir (alvo de clone); normaliza sem exigir existência.
        return [System.IO.Path]::GetFullPath($Requested)
    }
    $detected = Find-ExistingNexaRepoRoot -SkillName $SkillName
    if (-not [string]::IsNullOrWhiteSpace($detected)) {
        return (Resolve-Path -LiteralPath $detected).Path
    }
    # Default: pasta-irma da raiz XPZ.
    $xpzRoot = Resolve-XpzRepoRoot
    $parent = [System.IO.Path]::GetDirectoryName($xpzRoot)
    return (Join-Path $parent 'GeneXus-Skills-From-Zip')
}

function Test-DirectoryEmpty {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $true }
    $children = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    return ($children.Count -eq 0)
}

function Get-SkillState {
    param([string]$RepoRoot, [string]$SkillName)

    $skillPath = Join-Path $RepoRoot $SkillName
    $present = (Test-Path -LiteralPath (Join-Path $skillPath 'SKILL.md') -PathType Leaf)
    return [pscustomobject]@{ Path = $skillPath; Present = $present }
}

# --- 1. Garantir o executavel Git ---------------------------------------------
$gitPath = Find-GitExecutable
if (-not $gitPath) {
    if (-not $InstallGitIfMissing) {
        return (Write-Result -Status 'BLOCK' -Label 'GIT_MISSING_NO_INSTALL' -Messages @(
                'Git nao encontrado e instalacao automatica desabilitada (-InstallGitIfMissing:$false).',
                'Instale o Git (https://git-scm.com/download/win) ou rode com instalacao habilitada.'))
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        return (Write-Result -Status 'BLOCK' -Label 'GIT_MISSING_NO_INSTALLER' -Messages @(
                'Git ausente e winget indisponivel para instalacao automatica.',
                'Instale o Git manualmente: https://git-scm.com/download/win e reabra a sessao.'))
    }

    if ($PSCmdlet.ShouldProcess('Git.Git', 'Instalar Git via winget')) {
        $wingetArgs = @('install', '--id', 'Git.Git', '-e', '--source', 'winget',
            '--accept-package-agreements', '--accept-source-agreements', '--silent')
        & winget @wingetArgs 2>&1 | Out-Null
        $wingetExit = $LASTEXITCODE

        Update-SessionPathFromEnvironment
        $gitPath = Find-GitExecutable

        if (-not $gitPath) {
            if ($wingetExit -ne 0) {
                return (Write-Result -Status 'BLOCK' -Label 'GIT_INSTALL_FAILED' -Messages @(
                        "winget retornou exit $wingetExit ao instalar Git.Git.",
                        'A instalacao pode exigir elevacao (UAC). Instale manualmente e reabra a sessao.'))
            }
            return (Write-Result -Status 'ACTION_REQUIRED' -Label 'GIT_INSTALLED_REOPEN_SHELL' -Messages @(
                    'Git instalado, mas o PATH desta sessao ainda nao o expoe.',
                    'Reabra a sessao (ou o terminal) e rode o setup novamente.'))
        }
    }
    else {
        return (Write-Result -Status 'ACTION_REQUIRED' -Label 'GIT_INSTALL_SKIPPED' -Messages @(
                'Instalacao do Git nao confirmada (WhatIf). Nenhuma acao executada.'))
    }
}
$script:GitExe = $gitPath

# --- 2. Resolver a raiz alvo do repo nexa -------------------------------------
$officialNorm = ConvertTo-NormalizedUrl -Url $NexaOfficialRemoteUrl
$repoRoot = Resolve-NexaRepoRoot -Requested $NexaRepoRoot -SkillName $NexaSkillName

# --- 3. Pasta já existe e e repositório Git -----------------------------------
$insideCheck = $null
if (Test-Path -LiteralPath $repoRoot -PathType Container) {
    $insideCheck = Invoke-Git -GitArgs @('-C', $repoRoot, 'rev-parse', '--is-inside-work-tree') -AllowFailure
}
$isRepo = ($null -ne $insideCheck -and $insideCheck.ExitCode -eq 0 -and $insideCheck.Text.Trim() -eq 'true')

if ($isRepo) {
    $skillState = Get-SkillState -RepoRoot $repoRoot -SkillName $NexaSkillName
    $branchInfo = Invoke-Git -GitArgs @('-C', $repoRoot, 'rev-parse', '--abbrev-ref', 'HEAD') -AllowFailure
    $branch = $branchInfo.Text.Trim()

    $originCheck = Invoke-Git -GitArgs @('-C', $repoRoot, 'remote', 'get-url', 'origin') -AllowFailure
    if ($originCheck.ExitCode -ne 0) {
        # Repositório sem origin: ligar ao oficial (nada destrutivo).
        if ($PSCmdlet.ShouldProcess($repoRoot, "Adicionar remote origin -> $NexaOfficialRemoteUrl")) {
            Invoke-Git -GitArgs @('-C', $repoRoot, 'remote', 'add', 'origin', $NexaOfficialRemoteUrl) | Out-Null
            return (Write-Result -Status 'OK' -Label 'NEXA_ORIGIN_ADDED' `
                    -Remote $NexaOfficialRemoteUrl -Branch $branch -RepoRoot $repoRoot `
                    -SkillName $NexaSkillName -SkillPath $skillState.Path -SkillPresent $skillState.Present `
                    -Messages @(
                    'Repositorio nexa ja existia sem origin; remote oficial adicionado.',
                    'Rode git fetch origin para sincronizar referencias.'))
        }
        return (Write-Result -Status 'ACTION_REQUIRED' -Label 'NEXA_ORIGIN_ADD_SKIPPED' -RepoRoot $repoRoot -Messages @(
                'Adicao de origin nao confirmada (WhatIf).'))
    }

    $currentNorm = ConvertTo-NormalizedUrl -Url $originCheck.Text
    if ($currentNorm -eq $officialNorm) {
        $messages = @('A raiz nexa ja e um repositorio Git ligado ao remoto oficial. Nenhuma acao necessaria.')
        if (-not $skillState.Present) {
            $messages += "ATENCAO: subpasta da skill '$NexaSkillName' nao encontrada no repo (SKILL.md ausente)."
        }
        return (Write-Result -Status 'OK' -Label 'NEXA_ALREADY_LINKED' `
                -Remote $originCheck.Text.Trim() -Branch $branch -RepoRoot $repoRoot `
                -SkillName $NexaSkillName -SkillPath $skillState.Path -SkillPresent $skillState.Present `
                -Messages $messages)
    }

    return (Write-Result -Status 'BLOCK' -Label 'NEXA_REMOTE_MISMATCH' `
            -Remote $originCheck.Text.Trim() -RepoRoot $repoRoot -Messages @(
            "origin aponta para outro remoto: $($originCheck.Text.Trim())",
            "Oficial esperado: $NexaOfficialRemoteUrl",
            'Nao alterado automaticamente (o remoto do clone atual nao e reescrito).',
            'Migracao para o canonico: chame de novo com -NexaRepoRoot apontando para a pasta-irma GeneXus-Skills-From-Zip',
            '(caminho canônico da auditoria: repoRootCanonical). Sem -NexaRepoRoot, a deteccao pelo vinculo existente',
            'redetecta este clone legado e repete o BLOCK. Depois recrie os vinculos nexa para <canonico>\nexa.'))
}

# --- 4. Pasta existe, tem conteúdo, mas não e repositório Git -----------------
if ((Test-Path -LiteralPath $repoRoot -PathType Container) -and -not (Test-DirectoryEmpty -Path $repoRoot)) {
    return (Write-Result -Status 'BLOCK' -Label 'NEXA_DIR_NOT_REPO' -RepoRoot $repoRoot -Messages @(
            'A pasta-alvo existe com conteudo, mas nao e um repositorio Git.',
            'Para evitar sobrescrita, nada foi feito. Remova/realoque a pasta ou indique outra via -NexaRepoRoot,',
            'ou ligue-a manualmente ao oficial se o conteudo ja for o repo GeneXus-Skills-From-Zip.'))
}

# --- 5. Pasta inexistente ou vazia: clonar o oficial --------------------------
if (-not $PSCmdlet.ShouldProcess($repoRoot, "Clonar $NexaOfficialRemoteUrl")) {
    return (Write-Result -Status 'ACTION_REQUIRED' -Label 'NEXA_CLONE_SKIPPED' -RepoRoot $repoRoot -Messages @(
            'Clone nao confirmado (WhatIf). Nenhuma acao executada.'))
}

$parentDir = [System.IO.Path]::GetDirectoryName($repoRoot)
if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir -PathType Container)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

Invoke-Git -GitArgs @('clone', '--branch', $DefaultBranch, $NexaOfficialRemoteUrl, $repoRoot) -AllowFailure | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    # Fallback: clone sem --branch (remoto pode usar outra branch default).
    Invoke-Git -GitArgs @('clone', $NexaOfficialRemoteUrl, $repoRoot) | Out-Null
}

$branchInfo = Invoke-Git -GitArgs @('-C', $repoRoot, 'rev-parse', '--abbrev-ref', 'HEAD') -AllowFailure
$branch = $branchInfo.Text.Trim()
$skillState = Get-SkillState -RepoRoot $repoRoot -SkillName $NexaSkillName

$messages = @('Repositorio nexa clonado do oficial.')
if (-not $skillState.Present) {
    $messages += "ATENCAO: subpasta da skill '$NexaSkillName' nao encontrada no clone (SKILL.md ausente)."
}
return (Write-Result -Status 'OK' -Label 'NEXA_REPO_CLONED' `
        -Remote $NexaOfficialRemoteUrl -Branch $branch -RepoRoot $repoRoot `
        -SkillName $NexaSkillName -SkillPath $skillState.Path -SkillPresent $skillState.Present `
        -Messages $messages)
