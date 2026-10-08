#requires -Version 7.4
<#
.SYNOPSIS
    Prova sintetica repetivel de read/grep via opencode debug agent, sem modelo.
.DESCRIPTION
    Usa a politica FINAL Markdown e o instalador em JSONC sintetico. Nao modifica
    configuracao global. Runtime redirecionado no filho nao e isolamento absoluto.
    OutputDirectory deve ser novo; guarda stdout/stderr e recibo para inspecao.
    Estas provas debug nao substituem os fixtures behavioral com opencode run.
#>
[CmdletBinding()]
param([string] $OpenCodeExe, [string] $OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'OpenCodeCliSupport.ps1')
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')
$exe = Resolve-OpenCodeExe -Override $OpenCodeExe
$version = Get-OpenCodeVersionFromExe -Exe $exe
if (-not $OutputDirectory) { $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) ('gx-env-final-' + [guid]::NewGuid().ToString('N')) }
if (Test-Path -LiteralPath $OutputDirectory) { throw 'BLOCK: OutputDirectory deve ser novo.' }
$root = [IO.Directory]::CreateDirectory($OutputDirectory).FullName
$workspace = Join-Path $root 'workspace'
$runtime = Join-Path $root 'runtime'
$configDir = Join-Path $runtime 'config/opencode'
$source = Join-Path $PSScriptRoot '../.opencode/agent/reviewer-ro.md'
$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($dir in @($workspace, $configDir, (Join-Path $workspace 'sub'), (Join-Path $workspace '.opencode/agent'), (Join-Path $root 'outside'))) { [void][IO.Directory]::CreateDirectory($dir) }
Copy-Item -LiteralPath $source -Destination (Join-Path $workspace '.opencode/agent/reviewer-ro.md')
& git -C $workspace init --quiet
if ($LASTEXITCODE -ne 0) { throw 'BLOCK: git init sintetico falhou.' }
$files = @('.env', '.env.local', 'service.env', 'service.env.production', '.env.example', '.env.example.local', 'service.env.example', 'README.md', 'sub/.env', 'sub/.env.local', 'sub/.env.example', '.env~/ordinary.txt')
foreach ($file in $files) {
    $path = Join-Path $workspace $file
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    [IO.File]::WriteAllText($path, "SYNTHETIC_ENV_SENTINEL=$file`n", $utf8)
}
$outside = Join-Path $root 'outside/ordinary.txt'
[IO.File]::WriteAllText($outside, "SYNTHETIC_ENV_SENTINEL=outside`n", $utf8)
$jsonc = Join-Path $configDir 'opencode.jsonc'
[IO.File]::WriteAllText($jsonc, '{"plugin":[],"mcp":{},"instructions":[],"agent":{"probe-perm":{"mode":"all","permission":{"webfetch":"deny"}},"probe-tools":{"mode":"all","tools":{"webfetch":false}}}}', $utf8)
& (Join-Path $PSScriptRoot 'Install-OpenCodeReviewerRoAgent.ps1') -JsoncPath $jsonc -AgentMarkdownPath $source | Out-Null
$results = [Collections.Generic.List[object]]::new()
function Invoke-SyntheticCli {
    param([string] $Name, [string[]] $Argv, [string] $Cwd = $workspace, [bool] $GlobalOnly = $false)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exe; $psi.WorkingDirectory = $Cwd; $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    foreach ($key in @($psi.Environment.Keys)) {
        if ($key -match '(?i)(API.?KEY|TOKEN|SECRET|PASSWORD|OTEL_|^OPENCODE_|^XDG_)') { [void]$psi.Environment.Remove($key) }
    }
    foreach ($dim in @('CONFIG','DATA','CACHE','STATE')) { $psi.Environment['XDG_' + $dim + '_HOME'] = Join-Path $runtime $dim.ToLowerInvariant() }
    $psi.Environment['OPENCODE_CONFIG_DIR'] = $configDir
    $psi.Environment['OPENCODE_TEST_HOME'] = Join-Path $runtime 'home'
    $psi.Environment['OPENCODE_DISABLE_PROJECT_CONFIG'] = $GlobalOnly.ToString().ToLowerInvariant()
    foreach ($flag in @('OPENCODE_DISABLE_CLAUDE_CODE_PROMPT','OPENCODE_DISABLE_MODELS_FETCH','OPENCODE_DISABLE_AUTOUPDATE','OPENCODE_DISABLE_PRUNE','OPENCODE_PURE')) { $psi.Environment[$flag] = 'true' }
    $psi.Environment['TEMP'] = Join-Path $runtime 'tmp'; $psi.Environment['TMP'] = $psi.Environment['TEMP']
    [void][IO.Directory]::CreateDirectory($psi.Environment['TEMP'])
    foreach ($arg in $Argv) { [void]$psi.ArgumentList.Add($arg) }
    $p = [Diagnostics.Process]::new(); $p.StartInfo = $psi
    [void]$p.Start(); $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(45000)) { $p.Kill($true); throw "BLOCK: timeout $Name" }
    $stdout = $out.GetAwaiter().GetResult(); $stderr = $err.GetAwaiter().GetResult(); $code = $p.ExitCode; $p.Dispose()
    [IO.File]::WriteAllText((Join-Path $root "$Name.stdout.txt"), $stdout, $utf8)
    [IO.File]::WriteAllText((Join-Path $root "$Name.stderr.txt"), $stderr, $utf8)
    return @{ stdout = $stdout; stderr = $stderr; exit = $code }
}
foreach ($globalOnly in @($false, $true)) {
    $prefix = if ($globalOnly) { 'global' } else { 'markdown' }
    $al = Invoke-SyntheticCli -Name "$prefix-agentlist" -Argv @('agent','list') -GlobalOnly $globalOnly
    if ($al.exit -ne 0) { throw "BLOCK: agent list $prefix" }
    $rules = Get-OpenCodeReviewerRoBlockFromAgentList -Lines @($al.stdout -split '\r?\n' | Where-Object { $_.Length -gt 0 })
    $check = Test-OpenCodeReviewerRoEffectiveRules -Rules $rules
    if (-not $check.ok) { throw "BLOCK: $prefix $($check.detail)" }
    foreach ($case in @(
        @{ name='env'; path='.env'; deny=$true },
        @{ name='sub-local'; path='sub/.env.local'; deny=$true },
        @{ name='service'; path='service.env.production'; deny=$true },
        @{ name='uppercase'; path='.ENV'; deny=$true },
        @{ name='example'; path='.env.example'; deny=$false },
        @{ name='sub-example'; path='sub/.env.example'; deny=$false },
        @{ name='example-local'; path='.env.example.local'; deny=$true },
        @{ name='service-example'; path='service.env.example'; deny=$true },
        @{ name='source'; path='README.md'; deny=$false },
        @{ name='absolute'; path=(Join-Path $workspace '.env'); deny=$true },
        @{ name='dotdot'; path='sub/../.env'; deny=$true },
        @{ name='backslash'; path='sub\.env.local'; deny=$true },
        @{ name='outside'; path=$outside; deny=$true }
    )) {
        $name = "$prefix-$($case.name)"
        $r = Invoke-SyntheticCli -Name $name -Argv @('debug','agent','reviewer-ro','--tool','read','--params',(@{filePath=$case.path} | ConvertTo-Json -Compress)) -GlobalOnly $globalOnly
        $denied = $r.stderr -match 'The user has specified a rule which prevents|Tool read is disabled'
        $sentinel = $r.stdout.Contains('SYNTHETIC_ENV_SENTINEL')
        $ok = if ($case.deny) { $denied -and -not $sentinel } else { $r.exit -eq 0 -and $sentinel }
        $results.Add([ordered]@{name=$name; pass=$ok; denied=$denied; sentinel=$sentinel; exit=$r.exit})
    }
    $r = Invoke-SyntheticCli -Name "$prefix-grep" -Argv @('debug','agent','reviewer-ro','--tool','grep','--params','{"pattern":"SYNTHETIC_ENV_SENTINEL"}') -GlobalOnly $globalOnly
    $results.Add([ordered]@{name="$prefix-grep"; pass=($r.stderr -match 'Tool grep is disabled' -and -not $r.stdout.Contains('SYNTHETIC_ENV_SENTINEL')); exit=$r.exit})
}
# Worktree != cwd: permissao do exemplo exato na raiz ainda casa ../.env.example.
foreach ($case in @(@{name='subcwd-env';path='../.env';deny=$true}, @{name='subcwd-example';path='../.env.example';deny=$false})) {
    $r = Invoke-SyntheticCli -Name $case.name -Cwd (Join-Path $workspace 'sub') -Argv @('debug','agent','reviewer-ro','--tool','read','--params',(@{filePath=$case.path} | ConvertTo-Json -Compress))
    $ok = if ($case.deny) { $r.stderr -match 'The user has specified a rule which prevents' -and -not $r.stdout.Contains('SYNTHETIC_ENV_SENTINEL') } else { $r.exit -eq 0 -and $r.stdout.Contains('SYNTHETIC_ENV_SENTINEL') }
    $results.Add([ordered]@{name=$case.name;pass=$ok;exit=$r.exit})
}
foreach ($tool in @('glob','read','list')) {
    $params = switch ($tool) { 'glob' { @{pattern='**/*'} } 'read' { @{filePath=$workspace} } 'list' { @{path=$workspace} } }
    $r = Invoke-SyntheticCli -Name "names-$tool" -Argv @('debug','agent','reviewer-ro','--tool',$tool,'--params',($params | ConvertTo-Json -Compress))
    $results.Add([ordered]@{name="names-$tool";pass=($r.exit -eq 0 -or ($tool -eq 'list' -and $r.stderr -match 'Tool list not found'));namesVisible=($r.stdout -match '\.env');toolAbsent=($r.stderr -match 'Tool list not found')})
}
$receipt = [ordered]@{cliVersion=$version;mechanism='opencode debug agent';modelCalled=$false;root=$root;results=@($results);pass=(@($results | Where-Object { -not $_.pass }).Count -eq 0)}
[IO.File]::WriteAllText((Join-Path $root 'receipt.json'), ($receipt | ConvertTo-Json -Depth 8), $utf8)
$receipt | ConvertTo-Json -Depth 8
if (-not $receipt.pass) { throw "BLOCK: provas de conteudo falharam; veja $root" }
