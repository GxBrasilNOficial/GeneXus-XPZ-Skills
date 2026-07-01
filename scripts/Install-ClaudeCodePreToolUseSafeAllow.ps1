#requires -Version 7.4
<#
.SYNOPSIS
Instalador (DEPLOY) do daemon+cliente PreToolUse (auto-allow) do Claude Code. PASSO G / G2.1.
Contrato de producao: invocado pela skill xpz-skills-setup (integracao efetiva = Passo G3, PENDENTE),
NUNCA standalone em producao; hoje rodavel standalone em dev/manual. Solucao especifica do
Claude Code; nao se aplica a Codex/Cursor/OpenCode. Maquina-local, Windows x64.

.DESCRIPTION
Instalador com dois modos. Sem -Wire (DEPLOY, default): deposita o produto de runtime numa subpasta unica
da raiz marcada e NAO toca o settings.json. Com -Wire observe|enforce|off (WIRE, G2.2): grava/remove o hook
PreToolUse no ~/.claude/settings.json apontando p/ o EXE deployado (merge cirurgico + backup; ver
Invoke-PtuWire). O DEPLOY:

 1. Computa o buildContractPin esperado do .cs CORRENTE rodando o gerador versionado
    (Generate-ClaudeCodePtuBuildPin.ps1) num OutPath temporario -- sem buildar.
 2. Decide rebuild: reusa se (sem -Force) o EXE e a DLL existem E ambos emitem o pin esperado;
    senao, rebuilda (dotnet build da DLL + publish.bat do EXE NativeAOT) e revalida o pin.
 3. Gate de seguranca §8: roda SO quando rebuildou (salvo -SkipGate); se nao passar, ABORTA sem depositar.
 4. Deploy: cria/limpa <repo>\.ptu-safe-allow\ com exe + PtuCanon.dll + os 5 scripts de runtime
    (daemon, support, identity, classify.py, shlexloop.py); cria o marcador .ptu-safe-allow-root na
    raiz e limpa marcadores orfaos. Layout identico ao que o gate §8 monta em pasta temporaria.

O pin da DLL e' lido num pwsh FILHO (carrega, emite, morre) para NAO travar o .dll de um rebuild.
Tudo FAIL-CLOSED: qualquer etapa que falhe -> excecao -> nada e' depositado.
#>
[CmdletBinding()]
param(
    [switch] $Force,     # rebuilda mesmo com o pin batendo
    [switch] $SkipGate,  # pula o gate §8 (apenas iteracao de dev)
    # WIRE (G2.2): grava/remove o hook PreToolUse no ~/.claude/settings.json apontando p/ o EXE deployado.
    # Com -Wire, o script SO faz a operacao de wire (nao deploya/rebuilda/roda gate). Modos:
    #   observe -> hook com args ["--observe"] (passivo: mede o fio, SEMPRE abstem);
    #   enforce -> hook com args [] (modo real: allow/abster de verdade);
    #   off     -> remove o hook do produto (reversao; o backup timestamped tambem reverte).
    [ValidateSet('observe', 'enforce', 'off')]
    [string] $Wire,
    # So com -Wire. Default ~/.claude/settings.json. Serve p/ testar o merge numa COPIA sem tocar o real.
    [string] $SettingsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scripts = $PSScriptRoot
$repo    = Split-Path -Parent $scripts

# Fontes / saidas de build
$csPath      = Join-Path $repo    'ptu-native\PtuCanon.cs'
$genScript   = Join-Path $scripts 'Generate-ClaudeCodePtuBuildPin.ps1'
$targetsPath = Join-Path $repo    'ptu-native\BuildPin.targets'
$libCsproj   = Join-Path $repo    'ptu-native\lib\ptu-lib.csproj'
$exeSrc      = Join-Path $repo    'ptu-native\client\bin\x64\Release\net8.0\win-x64\publish\ptu-client.exe'
$dllSrc      = Join-Path $repo    'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$publishBat  = Join-Path $repo    'ptu-native\client\publish.bat'
$gateScript  = Join-Path $scripts 'Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1'

# Deploy
$deployDir  = Join-Path $repo '.ptu-safe-allow'
$markerName = '.ptu-safe-allow-root'
$markerPath = Join-Path $repo $markerName

# Runtime a depositar (o MESMO subconjunto que o gate §8 monta em temp).
$runtimeScripts = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1',
    'ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1',
    'Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)

# ---------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------
function Get-PtuCsprojProp {
    # Le uma prop <Name>valor</Name> do csproj (regex simples; o csproj e' controlado por nos).
    param([string] $CsprojPath, [string] $Name)
    $raw = [System.IO.File]::ReadAllText($CsprojPath)
    $m = [regex]::Match($raw, "<$Name>\s*([^<]+?)\s*</$Name>")
    if (-not $m.Success) { throw "prop canonica nao encontrada no csproj: $Name ($CsprojPath)" }
    return $m.Groups[1].Value.Trim()
}

function Get-PtuExpectedPin {
    # Roda o gerador versionado com os MESMOS args dos .csproj para um OutPath temp e captura o pin
    # (stdout). Sem buildar. Limpa o temp.
    param([string] $InvariantGlobalization, [string] $TargetFramework, [string] $LangVersion)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-pin-" + [System.Guid]::NewGuid().ToString('N') + ".g.cs")
    try {
        $pin = & pwsh -NoProfile -NonInteractive -File $genScript `
            -CsPath $csPath -GeneratorPath $genScript -TargetsPath $targetsPath `
            -InvariantGlobalization $InvariantGlobalization -TargetFramework $TargetFramework -LangVersion $LangVersion `
            -OutPath $tmp
        if ($LASTEXITCODE -ne 0) { throw "gerador do pin falhou (exit $LASTEXITCODE)" }
        return ([string]$pin).Trim()
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

function Get-PtuExePin {
    # Pin embutido no EXE via modo diagnostico --emit-pin (stdout). $null se o EXE nao existe/falha.
    param([string] $ExePath)
    if (-not (Test-Path -LiteralPath $ExePath)) { return $null }
    try {
        $out = & $ExePath '--emit-pin'
        if ($LASTEXITCODE -ne 0) { return $null }
        return ([string]$out).Trim()
    } catch { return $null }
}

function Get-PtuDllPin {
    # Le o pin da DLL num pwsh FILHO (carrega via Add-Type, emite, morre) -> NAO trava o .dll para um
    # rebuild posterior no processo do install. $null se ausente/falha. (Path do repo e' limpo, sem aspas.)
    param([string] $DllPath)
    if (-not (Test-Path -LiteralPath $DllPath)) { return $null }
    try {
        $out = & pwsh -NoProfile -NonInteractive -Command "try { Add-Type -Path '$DllPath'; [Ptu.BuildPin]::Value } catch { '' }"
        return ([string]$out).Trim()
    } catch { return $null }
}

function Invoke-PtuRebuild {
    Write-Host 'ptu-install: rebuildando DLL (dotnet build) + EXE NativeAOT (publish.bat)...'
    & dotnet build $libCsproj -c Release -nodeReuse:false -p:UseSharedCompilation=false --no-incremental -v minimal
    if ($LASTEXITCODE -ne 0) { throw "dotnet build da DLL falhou (exit $LASTEXITCODE)" }
    # publish.bat carrega vcvars e publica o EXE. cmd /c dentro do pwsh (sem o mangling do git bash).
    & cmd.exe /c $publishBat
    if ($LASTEXITCODE -ne 0) { throw "publish.bat do EXE falhou (exit $LASTEXITCODE)" }
}

function Invoke-PtuGate {
    # Roda o gate §8 como processo FILHO (isola exit/estado; ~10 min). Sucesso = exit 0 + linha 'OK:'.
    # O gate e' sensivel a timing/carga (testes de staleness com respawn+watchdog+Start-Sleep): uma falha
    # isolada costuma ser FLAKINESS da maquina (req vira defer por daemon lento), nao regressao. Tenta
    # ate 2x; so aborta se as DUAS falharem -- flakiness some no retry, falha real persiste.
    $maxTries = 2
    for ($try = 1; $try -le $maxTries; $try++) {
        Write-Host "ptu-install: rodando o gate de seguranca §8 (tentativa $try/$maxTries; pode levar ~10 min)..."
        $out = & pwsh -NoProfile -NonInteractive -File $gateScript
        $code = $LASTEXITCODE
        $okLine = @($out) | Where-Object { $_ -match '^OK:' }
        if ($code -eq 0 -and $okLine) {
            Write-Host 'ptu-install: gate §8 VERDE.'
            return
        }
        Write-Host "ptu-install: gate §8 FALHOU na tentativa $try (exit=$code)."
        if ($try -lt $maxTries) { Write-Host 'ptu-install: nova tentativa (flakiness de timing costuma sumir no retry)...' }
    }
    throw "gate §8 NAO passou apos $maxTries tentativas -- deploy ABORTADO, nada foi depositado."
}

function Get-PtuBuildPids {
    # PIDs de processos de build atuais. Usado no snapshot-diff que remove a contencao AUTO-INFLIGIDA
    # pelo rebuild (o NativeAOT publish deixa workers dotnet orfaos que competem por CPU com o gate §8,
    # sensivel a timing -> req vira defer -> gate falha). build-server shutdown NAO pega esses workers.
    return @(Get-Process -Name dotnet, MSBuild, VBCSCompiler -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Id)
}

function Clear-PtuBuildResiduals {
    # Mata SO os processos de build surgidos DURANTE o rebuild (diff vs o snapshot pre-rebuild) -> preserva
    # build pre-existente (ex.: um build do usuario ja em curso). Depois desliga os build servers
    # gerenciados e da um settle curto para a maquina assentar antes do gate.
    param([int[]] $Before)
    & dotnet build-server shutdown 2>&1 | Out-Null
    $now = @(Get-Process -Name dotnet, MSBuild, VBCSCompiler -ErrorAction SilentlyContinue)
    $killed = 0
    foreach ($p in $now) {
        if ($p.Id -notin $Before) { try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $killed++ } catch {} }
    }
    Start-Sleep -Seconds 2
    Write-Host "ptu-install: residuais de build limpos ($killed processo(s) do rebuild)."
}

function Get-PtuHookBlockText {
    # Linhas do bloco canonico do hook PreToolUse do produto, indentado p/ o settings.json (2 espacos por
    # nivel; a chave hooks fica no nivel 1, entao PreToolUse comeca com 4 espacos). O 'command' leva o path
    # do EXE com backslashes escapados p/ JSON. Termina com '],' pois o bloco e' inserido ANTES da 1a chave
    # existente do objeto hooks. EOL aplicado pelo chamador (join).
    param([string] $ExePath, [string] $Mode)
    $escaped = $ExePath.Replace('\', '\\')
    $argsJson = if ($Mode -eq 'observe') { '["--observe"]' } else { '[]' }
    return @(
        '    "PreToolUse": ['
        '      {'
        '        "matcher": "Bash",'
        '        "hooks": ['
        '          {'
        '            "type": "command",'
        '            "command": "' + $escaped + '",'
        '            "args": ' + $argsJson + ','
        '            "timeout": 10'
        '          }'
        '        ]'
        '      }'
        '    ],'
    )
}

function Invoke-PtuWire {
    # Merge cirurgico TEXTUAL (por linhas ancoradas) do hook PreToolUse no settings.json. Preserva o resto
    # do arquivo byte-a-byte (permissions.allow, SessionStart, etc.). Fail-closed: valida o JSON de entrada
    # e o de saida; se o resultado nao parseia, NAO grava. Backup timestamped antes de qualquer gravacao.
    # LIMITACAO CONHECIDA (verificada 2026-07-01): reconhece SO o formato multi-linha canonico do objeto
    # hooks e do bloco PreToolUse (o mesmo que este script grava, e o que o Claude Code usa). Um PreToolUse
    # pre-existente em formato compacto/inline -> aborta fail-closed por "formato inesperado" (NUNCA corrompe
    # o arquivo); robustez a formatos arbitrarios e' frente futura (ver 999).
    param([string] $Mode, [string] $DeployDir, [string] $SettingsPath)
    if (-not (Test-Path -LiteralPath $SettingsPath)) { throw "settings.json nao encontrado: $SettingsPath" }
    $exe = Join-Path $DeployDir 'ptu-client.exe'
    if ($Mode -ne 'off' -and -not (Test-Path -LiteralPath $exe)) {
        throw "EXE deployado ausente: $exe -- rode o deploy (Install sem -Wire) antes do wire."
    }

    $raw = [System.IO.File]::ReadAllText($SettingsPath)
    try { $null = $raw | ConvertFrom-Json } catch { throw "settings.json de entrada invalido (nao parseia): $($_.Exception.Message)" }

    $eol = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = @($raw -split "`r?`n")

    # Localiza a chave hooks (nivel 1) e um PreToolUse existente (+ seu fechamento no nivel da chave: 4
    # espacos + ']' com virgula opcional). O produto controla a formatacao do bloco que grava.
    $hooksIdx = -1; $preIdx = -1; $preEndIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($hooksIdx -lt 0 -and $lines[$i] -match '^\s{2}"hooks"\s*:\s*\{') { $hooksIdx = $i }
        if ($preIdx -lt 0 -and $lines[$i] -match '^\s{4}"PreToolUse"\s*:\s*\[') { $preIdx = $i }
    }
    if ($preIdx -ge 0) {
        for ($j = $preIdx + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match '^\s{4}\],?\s*$') { $preEndIdx = $j; break }
        }
        if ($preEndIdx -lt 0) { throw "PreToolUse encontrado mas o fechamento (4 espacos + ']') nao -- formato inesperado; abortado." }
        $existing = ($lines[$preIdx..$preEndIdx] -join "`n")
        if ($existing -notmatch 'ptu-client\.exe') {
            throw "ja existe um hook PreToolUse que NAO e' deste produto (sem ptu-client.exe) -- abortado p/ nao mexer em hook de terceiro."
        }
    }

    # Remove o bloco existente do produto (se houver), preservando o resto.
    if ($preIdx -ge 0) {
        $out = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($i -lt $preIdx -or $i -gt $preEndIdx) { [void]$out.Add($lines[$i]) } }
        $lines = @($out.ToArray())
        # o hooksIdx pode ter mudado se o PreToolUse estava antes; re-localiza.
        $hooksIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s{2}"hooks"\s*:\s*\{') { $hooksIdx = $i; break } }
    }

    if ($Mode -eq 'off') {
        if ($preIdx -lt 0) { Write-Host 'ptu-install: -Wire off -> nenhum hook PreToolUse do produto presente (idempotente).' }
    }
    else {
        if ($hooksIdx -lt 0) { throw "objeto 'hooks' nao encontrado no settings.json -- formato inesperado; abortado (esperado um bloco `"hooks`": { ... })." }
        $block = Get-PtuHookBlockText -ExePath $exe -Mode $Mode
        $merged = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            [void]$merged.Add($lines[$i])
            if ($i -eq $hooksIdx) { foreach ($b in $block) { [void]$merged.Add($b) } }
        }
        $lines = @($merged.ToArray())
    }

    $newText = ($lines -join $eol)
    try { $null = $newText | ConvertFrom-Json } catch { throw "resultado do wire NAO parseia como JSON -- nada gravado. Erro: $($_.Exception.Message)" }

    # backup UNICO e recuperavel: timestamp (ordenavel/legivel p/ reverter) + sufixo GUID curto (unicidade
    # garantida sem loop de sondagem, mesmo com multiplos wires no mesmo segundo). Copy nao-overwrite ainda
    # e' a guarda final (colisao praticamente impossivel -> falha em vez de sobrescrever).
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $suffix = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
    $backup = "$SettingsPath.ptu-backup-$stamp-$suffix"
    [System.IO.File]::Copy($SettingsPath, $backup, $false)
    [System.IO.File]::WriteAllText($SettingsPath, $newText, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host "ptu-install: wire=$Mode aplicado em $SettingsPath"
    Write-Host "  backup    : $backup"
    if ($Mode -ne 'off') { Write-Host "  hook      : PreToolUse[matcher=Bash] -> $exe $(if ($Mode -eq 'observe') { '--observe' } else { '(enforce)' })" }
}

# ---------------------------------------------------------------------------------------------------
# WIRE (G2.2): com -Wire, SO mexe no settings.json (nao deploya). Deploy tem de ter sido feito antes.
# ---------------------------------------------------------------------------------------------------
if ($PSBoundParameters.ContainsKey('Wire')) {
    $sp = if ([string]::IsNullOrWhiteSpace($SettingsPath)) { Join-Path $env:USERPROFILE '.claude\settings.json' } else { $SettingsPath }
    Invoke-PtuWire -Mode $Wire -DeployDir $deployDir -SettingsPath $sp
    Write-Host "OK: Install-ClaudeCodePreToolUseSafeAllow.ps1 (wire=$Wire)"
    exit 0
}

# ---------------------------------------------------------------------------------------------------
# 1. Pin esperado do .cs corrente (sem buildar)
# ---------------------------------------------------------------------------------------------------
foreach ($p in @($csPath, $genScript, $targetsPath, $libCsproj, $publishBat, $gateScript)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "arquivo do produto ausente: $p" }
}

$ig = Get-PtuCsprojProp -CsprojPath $libCsproj -Name 'InvariantGlobalization'
$tf = Get-PtuCsprojProp -CsprojPath $libCsproj -Name 'TargetFramework'
$lv = Get-PtuCsprojProp -CsprojPath $libCsproj -Name 'LangVersion'
$expectedPin = Get-PtuExpectedPin -InvariantGlobalization $ig -TargetFramework $tf -LangVersion $lv
if ([string]::IsNullOrWhiteSpace($expectedPin)) { throw "nao foi possivel computar o pin esperado" }
Write-Host "ptu-install: pin esperado do .cs corrente = $expectedPin"

# ---------------------------------------------------------------------------------------------------
# 2. Decidir rebuild (reuso condicional ao pin) + 3. gate quando rebuilda
# ---------------------------------------------------------------------------------------------------
$exePin = Get-PtuExePin -ExePath $exeSrc
$dllPin = Get-PtuDllPin -DllPath $dllSrc
$needRebuild = $Force.IsPresent -or ($exePin -cne $expectedPin) -or ($dllPin -cne $expectedPin)

if ($needRebuild) {
    if ($Force.IsPresent) { Write-Host 'ptu-install: -Force -> rebuild.' }
    else { Write-Host "ptu-install: pin divergente (exe=$exePin dll=$dllPin) -> rebuild." }
    $buildPidsBefore = @(Get-PtuBuildPids)   # snapshot pre-rebuild (preserva build pre-existente)
    Invoke-PtuRebuild
    Clear-PtuBuildResiduals -Before $buildPidsBefore   # remove a contencao auto-infligida antes do gate
    $exePin = Get-PtuExePin -ExePath $exeSrc
    $dllPin = Get-PtuDllPin -DllPath $dllSrc
    if ($exePin -cne $expectedPin -or $dllPin -cne $expectedPin) {
        throw "pos-rebuild: pin ainda divergente (esperado=$expectedPin exe=$exePin dll=$dllPin)"
    }
    if ($SkipGate.IsPresent) { Write-Host 'ptu-install: -SkipGate -> gate §8 PULADO (apenas dev).' }
    else { Invoke-PtuGate }
} else {
    Write-Host "ptu-install: binarios ja batem o pin ($expectedPin) -> reuso; sem rebuild, sem gate."
}

# ---------------------------------------------------------------------------------------------------
# 4. Deploy (copia plana) + marcador + limpeza de orfaos. NAO toca o settings.json.
# ---------------------------------------------------------------------------------------------------
foreach ($f in $runtimeScripts) {
    if (-not (Test-Path -LiteralPath (Join-Path $scripts $f))) { throw "script de runtime ausente: $f" }
}

if (Test-Path -LiteralPath $deployDir) { Remove-Item -LiteralPath $deployDir -Recurse -Force }
New-Item -ItemType Directory -Path $deployDir -Force | Out-Null
Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $deployDir 'ptu-client.exe') -Force
Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $deployDir 'PtuCanon.dll') -Force
foreach ($f in $runtimeScripts) {
    Copy-Item -LiteralPath (Join-Path $scripts $f) -Destination (Join-Path $deployDir $f) -Force
}

# Marcador unico na raiz; limpa orfaos (qualquer .ptu-safe-allow-root ABAIXO do repo que nao seja o oficial).
$orphans = @(Get-ChildItem -Path $repo -Recurse -Force -Filter $markerName -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $markerPath })
foreach ($o in $orphans) { Remove-Item -LiteralPath $o.FullName -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path -LiteralPath $markerPath)) { [System.IO.File]::WriteAllText($markerPath, '') }

# ---------------------------------------------------------------------------------------------------
# Relatorio
# ---------------------------------------------------------------------------------------------------
$mode = if ($needRebuild) { 'rebuild' } else { 'reuso' }
Write-Host ''
Write-Host 'ptu-install: DEPLOY concluido.'
Write-Host "  raiz marcada  : $markerPath"
Write-Host "  deploy        : $deployDir"
Write-Host "  pin           : $expectedPin"
Write-Host "  modo          : $mode"
if ($orphans.Count -gt 0) { Write-Host "  orfaos limpos : $($orphans.Count)" }
Write-Host '  settings.json : INTOCADO (fio NAO instalado; a Fase 3/G2.2 grava o hook sob ordem explicita).'
Write-Host 'OK: Install-ClaudeCodePreToolUseSafeAllow.ps1 (deploy)'
