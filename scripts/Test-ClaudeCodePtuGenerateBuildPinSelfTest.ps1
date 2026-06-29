#requires -Version 7.4
<#
.SYNOPSIS
Self-test do gerador do buildContractPin (scripts/Generate-ClaudeCodePtuBuildPin.ps1), Passo B do
daemon PreToolUse (auto-allow) do Claude Code. Sentinela de sucesso: "OK:" na ultima linha.

.DESCRIPTION
Parte A (gerador isolado, via fixtures passados como -CsPath/-GeneratorPath/-TargetsPath + props):
  - determinismo (mesmo material -> mesmo pin);
  - normalizacao: CRLF vs LF, CR isolado vs LF, com BOM vs sem BOM -> MESMO pin;
  - props: caixa/espaco variados (Trim + ToLowerInvariant) -> MESMO pin;
  - locale: CurrentCulture tr-TR -> MESMO pin (ToLowerInvariant, nao ToLower cultural);
  - sensibilidade: mudar QUALQUER chunk (cs, gerador, targets, cada uma das 3 props) -> pin MUDA.
Parte B (§5l via caminho MSBuild REAL, projeto fixture temporario isolado): build -> BuildPin.g.cs
  gerado; editar SO o .targets -> rebuild -> pin MUDA e o .g.cs e reescrito (prova que mudanca no
  .targets nao deixa o .g.cs stale por incrementalidade).
Tudo em diretorio temporario, limpo no fim. Nao toca arquivos versionados do repo.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gen = Join-Path $PSScriptRoot 'Generate-ClaudeCodePtuBuildPin.ps1'
if (-not (Test-Path -LiteralPath $gen)) { throw "gerador ausente: $gen" }

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-True {
    param([bool] $Cond, [string] $Msg)
    if (-not $Cond) { $script:failures.Add($Msg) }
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
function Write-Bytes {
    param([string] $Path, [byte[]] $Bytes)
    [System.IO.File]::WriteAllBytes($Path, $Bytes)
}
function Write-Text {
    # Grava texto com encoding/EOL exatos (sem normalizacao do cmdlet).
    param([string] $Path, [string] $Text, [switch] $Bom)
    $enc = [System.Text.UTF8Encoding]::new($Bom.IsPresent)
    [System.IO.File]::WriteAllBytes($Path, $enc.GetBytes($Text))
}

function Invoke-Gen {
    # Invoca o gerador real e devolve o pin (ultima linha do stdout).
    param([string] $Cs, [string] $Gp, [string] $Tg, [string] $Ig, [string] $Tf, [string] $Lv, [string] $Out)
    $out = & $gen -CsPath $Cs -GeneratorPath $Gp -TargetsPath $Tg -InvariantGlobalization $Ig -TargetFramework $Tf -LangVersion $Lv -OutPath $Out
    return ([string](@($out)[-1])).Trim()
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-buildpin-selftest-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null

try {
    # ---------- Parte A: gerador isolado ----------
    $aDir = Join-Path $root 'A'
    New-Item -ItemType Directory -Path $aDir -Force | Out-Null

    $csLf  = Join-Path $aDir 'cs_lf.txt'
    $genFx = Join-Path $aDir 'gen_fixture.txt'
    $tgFx  = Join-Path $aDir 'targets_fixture.txt'
    $outA  = Join-Path $aDir 'out.g.cs'

    Write-Text -Path $csLf  -Text "namespace X {`n  class C { }`n}`n"
    Write-Text -Path $genFx -Text "# gerador fixture`nlinha 2`n"
    Write-Text -Path $tgFx  -Text "<Project>`n  <!-- targets fixture -->`n</Project>`n"

    $base = Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA
    Assert-True ($base -match '^[0-9a-f]{64}$') "A: pin baseline nao e SHA256 hex lowercase: '$base'"

    # determinismo
    $base2 = Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA
    Assert-True ($base -ceq $base2) "A: nao-deterministico (2 chamadas, mesmo material)"

    # EOL: CRLF (mesmo texto) -> mesmo pin
    $csCrlf = Join-Path $aDir 'cs_crlf.txt'
    Write-Text -Path $csCrlf -Text "namespace X {`r`n  class C { }`r`n}`r`n"
    $pCrlf = Invoke-Gen -Cs $csCrlf -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA
    Assert-True ($base -ceq $pCrlf) "A: CRLF mudou o pin (deveria normalizar p/ LF)"

    # CR isolado -> mesmo pin
    $csCr = Join-Path $aDir 'cs_cr.txt'
    Write-Text -Path $csCr -Text "namespace X {`r  class C { }`r}`r"
    $pCr = Invoke-Gen -Cs $csCr -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA
    Assert-True ($base -ceq $pCr) "A: CR isolado mudou o pin (deveria normalizar p/ LF)"

    # BOM -> mesmo pin
    $csBom = Join-Path $aDir 'cs_bom.txt'
    Write-Text -Path $csBom -Text "namespace X {`n  class C { }`n}`n" -Bom
    $pBom = Invoke-Gen -Cs $csBom -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA
    Assert-True ($base -ceq $pBom) "A: BOM mudou o pin (deveria ser stripado)"

    # props: caixa/espaco -> mesmo pin
    $pProp1 = Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'True'  -Tf 'NET8.0' -Lv ' 12.0 ' -Out $outA
    Assert-True ($base -ceq $pProp1) "A: props caixa/espaco mudaram o pin (deveria Trim+ToLowerInvariant)"

    # locale tr-TR -> mesmo pin (ToLowerInvariant)
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::new('tr-TR')
        $pTr = Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'TRUE' -Tf 'net8.0' -Lv '12.0' -Out $outA
        Assert-True ($base -ceq $pTr) "A: locale tr-TR mudou o pin (deveria usar InvariantCulture)"
    }
    finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }

    # sensibilidade: mudar cada chunk -> pin muda
    $csAlt = Join-Path $aDir 'cs_alt.txt'; Write-Text -Path $csAlt -Text "namespace X {`n  class D { }`n}`n"
    Assert-True ((Invoke-Gen -Cs $csAlt -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA) -cne $base) "A: mudar .cs NAO mudou o pin"

    $genAlt = Join-Path $aDir 'gen_alt.txt'; Write-Text -Path $genAlt -Text "# gerador fixture ALTERADO`nlinha 2`n"
    Assert-True ((Invoke-Gen -Cs $csLf -Gp $genAlt -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA) -cne $base) "A: mudar o gerador NAO mudou o pin"

    $tgAlt = Join-Path $aDir 'targets_alt.txt'; Write-Text -Path $tgAlt -Text "<Project>`n  <!-- targets fixture ALT -->`n</Project>`n"
    Assert-True ((Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgAlt -Ig 'true' -Tf 'net8.0' -Lv '12.0' -Out $outA) -cne $base) "A: mudar o .targets NAO mudou o pin"

    Assert-True ((Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'false' -Tf 'net8.0' -Lv '12.0' -Out $outA) -cne $base) "A: mudar InvariantGlobalization NAO mudou o pin"
    Assert-True ((Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net9.0' -Lv '12.0' -Out $outA) -cne $base) "A: mudar TargetFramework NAO mudou o pin"
    Assert-True ((Invoke-Gen -Cs $csLf -Gp $genFx -Tg $tgFx -Ig 'true' -Tf 'net8.0' -Lv '13.0' -Out $outA) -cne $base) "A: mudar LangVersion NAO mudou o pin"

    # prop vazia -> falha (exit != 0)
    $threw = $false
    try { & $gen -CsPath $csLf -GeneratorPath $genFx -TargetsPath $tgFx -InvariantGlobalization '' -TargetFramework 'net8.0' -LangVersion '12.0' -OutPath $outA 2>$null } catch { $threw = $true }
    Assert-True ($threw -or $LASTEXITCODE -ne 0) "A: prop vazia NAO falhou o gerador"

    # .g.cs gerado: LF, sem BOM, com o pin
    $genBytes = [System.IO.File]::ReadAllBytes($outA)
    $hasBom = ($genBytes.Length -ge 3 -and $genBytes[0] -eq 0xEF -and $genBytes[1] -eq 0xBB -and $genBytes[2] -eq 0xBF)
    $hasCr = @($genBytes | Where-Object { $_ -eq 13 }).Count -gt 0
    Assert-True (-not $hasBom) "A: BuildPin.g.cs gerado com BOM"
    Assert-True (-not $hasCr) "A: BuildPin.g.cs gerado com CR (deveria ser LF)"

    # ---------- Parte B: §5l via caminho MSBuild REAL (projeto fixture isolado) ----------
    $bDir = Join-Path $root 'B'
    New-Item -ItemType Directory -Path $bDir -Force | Out-Null
    Write-Text -Path (Join-Path $bDir 'PtuCanon.cs') -Text "namespace Ptu { public static class Canon { public static string Probe() { return `"x`"; } } }`n"

    $tgReal = Join-Path $bDir 'fixture.targets'
    # Espelha o BuildPin.targets real: caminhos via <PropertyGroup>, nao inline no Command (o Command
    # inline com paths absolutos longos quebra o MSBuild Exec com exit 123; via propriedades, nao).
    $tgContent = @(
        '<Project>',
        '  <PropertyGroup>',
        "    <_GenScript>$gen</_GenScript>",
        '    <_CsSrc>$(MSBuildThisFileDirectory)PtuCanon.cs</_CsSrc>',
        '    <_TgSelf>$(MSBuildThisFileFullPath)</_TgSelf>',
        '  </PropertyGroup>',
        '  <Target Name="GenPin" BeforeTargets="CoreCompile">',
        '    <PropertyGroup><_PinOut>$(MSBuildProjectDirectory)\$(IntermediateOutputPath)BuildPin.g.cs</_PinOut></PropertyGroup>',
        '    <Exec Command="pwsh -NoProfile -NonInteractive -File &quot;$(_GenScript)&quot; -CsPath &quot;$(_CsSrc)&quot; -GeneratorPath &quot;$(_GenScript)&quot; -TargetsPath &quot;$(_TgSelf)&quot; -InvariantGlobalization &quot;$(InvariantGlobalization)&quot; -TargetFramework &quot;$(TargetFramework)&quot; -LangVersion &quot;$(LangVersion)&quot; -OutPath &quot;$(_PinOut)&quot;" />',
        '    <ItemGroup><Compile Include="$(_PinOut)" /></ItemGroup>',
        '  </Target>',
        '</Project>',
        ''
    )
    Write-Text -Path $tgReal -Text ([string]::Join("`n", $tgContent))

    $csproj = @(
        '<Project Sdk="Microsoft.NET.Sdk">',
        '  <PropertyGroup>',
        '    <OutputType>Library</OutputType>',
        '    <TargetFramework>net8.0</TargetFramework>',
        '    <LangVersion>12.0</LangVersion>',
        '    <Nullable>disable</Nullable>',
        '    <InvariantGlobalization>true</InvariantGlobalization>',
        '    <AssemblyName>PtuFixture</AssemblyName>',
        '  </PropertyGroup>',
        '  <Import Project="fixture.targets" />',
        '</Project>',
        ''
    )
    $csprojPath = Join-Path $bDir 'fixture.csproj'
    Write-Text -Path $csprojPath -Text ([string]::Join("`n", $csproj))

    function Get-PinFromBuild {
        param([string] $ProjDir)
        $gcs = Get-ChildItem -Path (Join-Path $ProjDir 'obj') -Recurse -Filter 'BuildPin.g.cs' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $gcs) { return $null }
        $txt = [System.IO.File]::ReadAllText($gcs.FullName)
        $m = [regex]::Match($txt, 'Value = "([0-9a-f]{64})"')
        if (-not $m.Success) { return $null }
        return $m.Groups[1].Value
    }

    # Flags anti-trava: o reuso de nodes do MSBuild trava builds repetidos em sequencia neste host.
    $bflags = @('-c','Release','--no-incremental','-nodeReuse:false','-p:UseSharedCompilation=false','--nologo','-v','quiet')
    $buildLog1 = & dotnet build $csprojPath @bflags 2>&1
    $errLines1 = @($buildLog1 | Where-Object { $_ -match 'error|erro|FALHA' })
    Assert-True ($LASTEXITCODE -eq 0) "B: 1o build do fixture falhou: $([string]::Join(' || ', $errLines1))"
    $pinB1 = Get-PinFromBuild -ProjDir $bDir
    Assert-True ($null -ne $pinB1 -and $pinB1 -match '^[0-9a-f]{64}$') "B: nao extraiu pin do 1o build"

    # Editar SO o .targets (insere comentario ANTES de </Project>, mantendo XML valido; NAO toca o .cs)
    # -> pin deve mudar no rebuild, provando que o .targets entra no material e nao fica stale.
    $tgText = [System.IO.File]::ReadAllText($tgReal)
    $tgText = $tgText.Replace('</Project>', "  <!-- mutacao para o teste de invalidacao do 5l -->`n</Project>")
    [System.IO.File]::WriteAllText($tgReal, $tgText, $utf8NoBom)
    $buildLog2 = & dotnet build $csprojPath @bflags 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "B: 2o build (apos editar .targets) falhou"
    $pinB2 = Get-PinFromBuild -ProjDir $bDir
    Assert-True ($null -ne $pinB2 -and $pinB2 -cne $pinB1) "B: editar SO o .targets NAO mudou o pin (staleness do .g.cs - gap do 5l)"
}
finally {
    if ([string]::IsNullOrEmpty($env:PTU_SELFTEST_KEEP)) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Warning "PTU_SELFTEST_KEEP setado; fixture preservado em: $root"
    }
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Error $f -ErrorAction Continue }
    throw "FALHA: Test-ClaudeCodePtuGenerateBuildPinSelfTest ($($failures.Count) assercao(es))"
}
Write-Output "OK: Test-ClaudeCodePtuGenerateBuildPinSelfTest.ps1"
