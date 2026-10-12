#requires -Version 7.4

<#
.SYNOPSIS
  Suporte (dot-source) para os self-tests da rotina pre-push de pasta paralela de
  KB (skill xpz-kb-parallel-pre-push): cria repos git temporarios de fixture e
  invoca o script-alvo isolando o seu `exit`.

.DESCRIPTION
  Os motores da Fase 1/2 sao git-based (git -C <RepoRoot> diff BaseRef..HEAD), entao
  os self-tests precisam de um repo git real e descartavel. Este suporte concentra
  a montagem do repo, a gravacao/commit de fixtures e a invocacao do motor em um
  pwsh-filho (para que o `exit` do motor nao derrube o self-test). Sem dependencia
  de rede: a BaseRef e sempre um SHA local, nunca origin/*.

  Nao e um self-test; nao emite sentinela. E dot-sourced pelos Test-*SelfTest.ps1.
#>

Set-StrictMode -Version Latest

$script:XpzSelfTestUtf8NoBom = New-Object System.Text.UTF8Encoding($false)

function New-XpzPrePushSelfTestRepo {
  <# Cria um repo git temporario na branch main, com user.* local e sem assinatura. Retorna a raiz. #>
  param([Parameter(Mandatory)][string]$Slug)
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-prepush-$Slug-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $root -Force)
  & git -C $root init -q --initial-branch=main 2>$null
  if ($LASTEXITCODE -ne 0) {
    # git < 2.28 nao tem --initial-branch: init e renomeia.
    & git -C $root init -q 2>$null
    & git -C $root checkout -q -B main 2>$null
  }
  & git -C $root config user.email 'selftest@example.invalid' 2>$null
  & git -C $root config user.name  'XPZ SelfTest' 2>$null
  & git -C $root config commit.gpgsign false 2>$null
  & git -C $root config core.autocrlf false 2>$null
  return $root
}

function Set-XpzPrePushSelfTestFile {
  <# Grava (UTF-8 sem BOM) um arquivo no repo de fixture, criando subpastas. #>
  param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$RelPath,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )
  $full = Join-Path $Root $RelPath
  $dir = Split-Path -Parent $full
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  [System.IO.File]::WriteAllText($full, $Content, $script:XpzSelfTestUtf8NoBom)
}

function Remove-XpzPrePushSelfTestPath {
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$RelPath)
  Remove-Item -LiteralPath (Join-Path $Root $RelPath) -Force -Recurse -ErrorAction SilentlyContinue
}

function New-XpzPrePushSelfTestCommit {
  <# git add -A + commit; retorna o SHA do HEAD resultante. #>
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Message)
  & git -C $Root add -A 2>$null
  & git -C $Root commit -q -m $Message --allow-empty 2>$null
  return ([string](& git -C $Root rev-parse HEAD 2>$null)).Trim()
}

function Invoke-XpzSelfTestScript {
  <#
    Roda um script-alvo em pwsh-filho (isola o `exit`), capturando stdout e exit.
    Retorna { exit, stdout, json } (json = stdout parseado, ou $null se nao for JSON).
    Args sao passados como lista posicional/nomeada ja montada pelo chamador.
  #>
  param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string[]]$ScriptArgs = @()
  )
  $stdout = & pwsh -NoProfile -File $ScriptPath @ScriptArgs 2>$null | Out-String
  $code = $LASTEXITCODE
  $json = $null
  if ($stdout -and $stdout.Trim()) {
    try { $json = $stdout | ConvertFrom-Json } catch { $json = $null }
  }
  return [pscustomobject]@{ exit = $code; stdout = $stdout; json = $json }
}
