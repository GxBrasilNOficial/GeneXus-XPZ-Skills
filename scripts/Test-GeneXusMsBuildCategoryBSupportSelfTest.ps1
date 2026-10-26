#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusMsBuildCategoryBSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusMsBuildCategoryBSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

if (-not (Test-GeneXusMsBuildCategoryBPresent -MsBuildErrors @('error : test') -InvalidTypesRejected @())) {
    throw 'Test-GeneXusMsBuildCategoryBPresent deveria ser true com exportErrors'
}

if (Test-GeneXusMsBuildCategoryBPresent -MsBuildErrors @() -InvalidTypesRejected @()) {
    throw 'Test-GeneXusMsBuildCategoryBPresent deveria ser false sem sinais'
}

$downgraded = Resolve-GeneXusMsBuildCategoryBExitCode `
    -BaseExitCode 0 `
    -MsBuildExitCode 0 `
    -MsBuildErrors @('error : WorkWithForWeb is not a valid type.') `
    -InvalidTypesRejected @('WorkWithForWeb')

if ($downgraded -ne 48) {
    throw "Esperava exit 48; obtido: $downgraded"
}

$unchanged = Resolve-GeneXusMsBuildCategoryBExitCode `
    -BaseExitCode 41 `
    -MsBuildExitCode 1 `
    -MsBuildErrors @('error : x') `
    -InvalidTypesRejected @()

if ($unchanged -ne 41) {
    throw "BaseExitCode 41 deveria ser preservado; obtido: $unchanged"
}

$reasons = @(Get-GeneXusMsBuildCategoryBBlockingReasons -MsBuildErrors @('error : a') -InvalidTypesRejected @('TipoX') -StageLabel 'Export')
if ($reasons.Count -lt 2) {
    throw "Esperava pelo menos 2 blocking reasons; obtido: $($reasons.Count)"
}



# Caso conhecido do compressor de estaticos (dispensa da Categoria B). Dados sao genericos.
# Pre-requisito: node no PATH (a verificacao node --check por arquivo corrigido depende dele).
if (-not (Get-Command -Name node -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'ASSERT_FAILED: node e pre-requisito deste self-test (node --check por arquivo corrigido).'
}
. (Join-Path $PSScriptRoot 'GeneXusMsBuildGamPlatformsSupport.ps1')

$staticRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('catb-static-selftest-' + [System.Guid]::NewGuid().ToString('N'))
$kbRoot = Join-Path $staticRoot 'KbGenerica'
$webDir = Join-Path $kbRoot 'AmbienteA\web'
$jsPath = Join-Path $webDir 'arquivo-generico.js'
$otherPath = Join-Path $webDir 'outro-generico.js'
$validJs = 'var x = 1;'
[System.IO.Directory]::CreateDirectory($webDir) | Out-Null
[System.IO.File]::WriteAllText($jsPath, $validJs, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($otherPath, $validJs, [System.Text.UTF8Encoding]::new($false))

$gamLine = "C:\Program Files\dotnet\sdk\Microsoft.NET.Publish.targets(297,5): error MSB3491: Nao foi possivel gravar. Access to the path 'C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\build\x.tog~' is denied.  [C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\NetCorePostgreSQL\GxDeps.csproj]"

function New-StaticCompressorFixture {
    param([string]$WebDir)

    return [string[]]@(
        'Comprimindo arquivos estaticos ...',
        "arquivo-generico.js(1793): Expected '}': -",
        $gamLine,
        'arquivo-generico.js(1903): Syntax error : } [C:\exemplo\buildall.msbuild]',
        '  arquivo-generico.js(1903): Expected expression: )',
        'C:\exemplo\buildall.msbuild(40,5): warning : Some files could not be compressed.',
        '  Success with warnings',
        'PostBuild-Gx: app_offline.htm removido - site religado.',
        ('Fix-GxNegativeDomainKeys: raiz = {0}' -f $WebDir),
        '[APLICADO] .js varridos=2966 | arquivos com chave negativa em gx.domain=1 | chaves corrigidas=1',
        '    arquivo-generico.js -> 1 chave(s)',
        ('Verify-GxJs: raiz         = {0}  (via argumento)' -f $WebDir),
        'Verify-GxJs: verificados 2176 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2237 ms',
        '  > Build All Task Sucesso',
        '  __BUILDALL_DONE__=true'
    )
}

function New-StaticCompressorMultiFixture {
    param([string]$WebDir)

    return [string[]]@(
        'Comprimindo arquivos estaticos ...',
        "arquivo-generico.js(1000): Expected '}': -",
        'arquivo-generico.js(1051): Syntax error : } [C:\exemplo\buildall.msbuild]',
        "outro-generico.js(1795): Expected '}': -",
        'outro-generico.js(1905): Syntax error : } [C:\exemplo\buildall.msbuild]',
        'C:\exemplo\buildall.msbuild(40,5): warning : Some files could not be compressed.',
        'PostBuild-Gx: app_offline.htm removido - site religado.',
        ('Fix-GxNegativeDomainKeys: raiz = {0}' -f $WebDir),
        '[APLICADO] .js varridos=2969 | arquivos com chave negativa em gx.domain=2 | chaves corrigidas=2',
        '    arquivo-generico.js -> 1 chave(s)',
        '    outro-generico.js -> 1 chave(s)',
        ('Verify-GxJs: raiz         = {0}  (via argumento)' -f $WebDir),
        'Verify-GxJs: verificados 2179 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 2197 ms',
        '  > Build All Task Sucesso',
        '  __BUILDALL_DONE__=true'
    )
}

function Invoke-StaticCompressorCase {
    param(
        [string[]]$Lines,
        [string[]]$ErrLines = @(),
        [int]$ExitCode = 0,
        [bool]$KbOpen = $true,
        [bool]$TimedOut = $false,
        [bool]$BuildAllDone = $true,
        [string]$Blocking = '',
        [string]$Root,
        [bool]$MetadataPresent = $false,
        [string]$ExpectedWebDir = ''
    )

    $noise = @(@($Lines) + @($ErrLines) | Where-Object { $_ -and (Test-GamPlatformsStdoutNoiseLine -Line $_) })
    return Test-GeneXusStaticCompressorKnownCase `
        -StdOutLines $Lines `
        -StdErrLines $ErrLines `
        -GamNoiseLines $noise `
        -MsBuildExitCode $ExitCode `
        -KbOpen $KbOpen `
        -TimedOut $TimedOut `
        -BuildAllDone $BuildAllDone `
        -DetectedBlockingPattern $Blocking `
        -KbRoot $Root `
        -MetadataPresent $MetadataPresent `
        -ExpectedWebDir $ExpectedWebDir
}

function Remove-StaticCompressorLines {
    param([string[]]$Lines, [string]$Needle)

    return [string[]]@($Lines | Where-Object { -not $_.Contains($Needle) })
}

function Replace-StaticCompressorLines {
    param([string[]]$Lines, [string]$Needle, [string]$Old, [string]$New)

    return [string[]]@($Lines | ForEach-Object {
        if ($_.Contains($Needle)) { $_.Replace($Old, $New) } else { $_ }
    })
}

function Assert-StaticCompressorRefused {
    param([string]$Name, [object]$Result)

    if ($Result.recognized) {
        throw "ASSERT_FAILED: caso deveria ser recusado: $Name"
    }
}

$base = New-StaticCompressorFixture -WebDir $webDir
if (-not (Test-GamPlatformsStdoutNoiseLine -Line $gamLine)) {
    throw 'ASSERT_FAILED: a linha MSB3491 do fixture deveria ser ruido GAM.'
}

# Positivos.
$positive = Invoke-StaticCompressorCase -Lines $base -Root $kbRoot
if (-not $positive.recognized) {
    throw "ASSERT_FAILED: caso conhecido deveria ser reconhecido: $($positive.reason)"
}
if (@($positive.files).Count -ne 1 -or $positive.files[0].fileName -ne 'arquivo-generico.js' -or [int]$positive.chavesCorrigidas -ne 1) {
    throw 'ASSERT_FAILED: arquivos ou contagem do caso reconhecido inesperados.'
}
if ([string]::IsNullOrWhiteSpace($positive.nodeVersion)) {
    throw 'ASSERT_FAILED: versao do node nao registrada no resultado.'
}
$positiveWithMapping = Invoke-StaticCompressorCase -Lines $base -Root $kbRoot -MetadataPresent $true -ExpectedWebDir $webDir
if (-not $positiveWithMapping.recognized) {
    throw 'ASSERT_FAILED: metadata com mapeamento igual a raiz do Fix deveria ser reconhecido.'
}
$positiveStderrNoise = Invoke-StaticCompressorCase -Lines $base -ErrLines @($gamLine) -Root $kbRoot
if (-not $positiveStderrNoise.recognized) {
    throw 'ASSERT_FAILED: ruido GAM no stderr nao deveria impedir a dispensa.'
}
$spaceLines = [string[]]@($base | ForEach-Object { if ($_ -like '*arquivo-generico.js(1793): Expected*') { "C:\Meu Dir\arquivo-generico.js(1793): Expected '}': -" } else { $_ } })
$positiveSpacePath = Invoke-StaticCompressorCase -Lines $spaceLines -Root $kbRoot
if (-not $positiveSpacePath.recognized) {
    throw "ASSERT_FAILED: linha Expected com caminho contendo espaco deveria ser aceita: $($positiveSpacePath.reason)"
}
$multiLines = New-StaticCompressorMultiFixture -WebDir $webDir
$multi = Invoke-StaticCompressorCase -Lines $multiLines -Root $kbRoot
if (-not $multi.recognized) {
    throw "ASSERT_FAILED: caso com dois arquivos deveria ser reconhecido: $($multi.reason)"
}
if (@($multi.files).Count -ne 2 -or [int]$multi.chavesCorrigidas -ne 2) {
    throw 'ASSERT_FAILED: caso com dois arquivos com contagem inesperada.'
}

# Negativos: cada um deve manter exit 48 (caso nao reconhecido).
Assert-StaticCompressorRefused -Name 'sem linha APLICADO' -Result (Invoke-StaticCompressorCase -Lines (Remove-StaticCompressorLines -Lines $base -Needle '[APLICADO]') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'chaves corrigidas=0' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle '[APLICADO]' -Old 'chaves corrigidas=1' -New 'chaves corrigidas=0') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'Verify com invalidos' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle 'Verify-GxJs: verificados' -Old 'invalidos: 0' -New 'invalidos: 1') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'erro de codigo CS adicional' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'C:\exemplo\gerado.cs(2342,15): error CS0019: operador invalido')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'erro MSB fora do GAM' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'C:\exemplo\buildall.msbuild(10,5): error MSB4018: falha ao carregar o alvo.')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'erro NETSDK (seis letras)' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'C:\exemplo\projeto.csproj : error NETSDK1004: arquivo de ativos nao encontrado.')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'SyntaxError do JScript fora do caso' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'SyntaxError: unexpected token')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'TypeError fora do caso' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'TypeError: nao e funcao')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'GxError com dois-pontos' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'GxError : falha de geracao')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'linha NuGet sob GAM contada pelo classificador' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'C:\exemplo\NuGet.targets(120,5): error : Access to the path is denied.')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'excecao nao tratada na saida' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Unhandled exception: System.IO.IOException')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'IOException em nome de classe' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'System.IO.IOException: arquivo em uso')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'NullReferenceException' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Object reference: NullReferenceException na geracao')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'linha Failed na saida' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Failed: Build All')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'falha em portugues na saida' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Falha ao gravar o relatorio')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'acesso negado fora do GAM' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Acesso negado ao arquivo de configuracao')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'erro de sintaxe no stderr' -Result (Invoke-StaticCompressorCase -Lines $base -ErrLines @('arquivo-generico.js(1903): Syntax error : } [C:\exemplo\buildall.msbuild]') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'erro com codigo no stderr' -Result (Invoke-StaticCompressorCase -Lines $base -ErrLines @('C:\exemplo\buildall.msbuild(1,1): error : falha') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'mensagem de outro arquivo sem a palavra Expected' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'outro-generico.js(1790): Unterminated string constant')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'Expected de arquivo fora dos erros' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + "outro-generico.js(1790): Expected '}': -")) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'mensagem de arquivo sem numero de linha' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'arquivo-generico.js: Unexpected token')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'palavra Invalid isolada' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Invalid option supplied')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'palavra missing isolada' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Missing reference to module')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'palavra Fatal isolada' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Fatal: estado inesperado')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'linha de stack trace' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + '   at System.IO.File.Open(String path)')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'Could not load fora do caso' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Could not load file or assembly GeneXus.Core')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'contorno afetou dois arquivos com um erro' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle '[APLICADO]' -Old 'gx.domain=1' -New 'gx.domain=2') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'soma de chaves diferente da soma por arquivo' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle '[APLICADO]' -Old 'chaves corrigidas=1' -New 'chaves corrigidas=2') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'contorno de outro arquivo' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle '-> 1 chave(s)' -Old 'arquivo-generico.js' -New 'outro-generico.js') -Root $kbRoot)
$verifyLine = 'Verify-GxJs: verificados 2176 .js (modulos pulados: 389 | placeholders pulados: 0) | invalidos: 0 | tempo: 1 ms'
Assert-StaticCompressorRefused -Name 'Verify antes do APLICADO' -Result (Invoke-StaticCompressorCase -Lines ([string[]](@($verifyLine) + @(Remove-StaticCompressorLines -Lines $base -Needle 'Verify-GxJs: verificados'))) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'sem __BUILDALL_DONE__' -Result (Invoke-StaticCompressorCase -Lines (Remove-StaticCompressorLines -Lines $base -Needle '__BUILDALL_DONE__') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'sem Build All Task Sucesso' -Result (Invoke-StaticCompressorCase -Lines (Remove-StaticCompressorLines -Lines $base -Needle 'Build All Task Sucesso') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'msBuildExitCode diferente de zero' -Result (Invoke-StaticCompressorCase -Lines $base -ExitCode 1 -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'duas linhas Syntax error do mesmo arquivo' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'arquivo-generico.js(1950): Syntax error : } [C:\exemplo\buildall.msbuild]')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'duas linhas de correcao do mesmo arquivo (multi)' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($multiLines + '    arquivo-generico.js -> 1 chave(s)')) -Root $kbRoot)
$orderLines = [string[]]((@($multiLines[0..7]) + @('    outro-generico.js -> 1 chave(s)') + @($multiLines[8]) + @($multiLines[9]) + @($multiLines[11..($multiLines.Count - 1)])))
Assert-StaticCompressorRefused -Name 'linha de correcao antes do APLICADO (ordem)' -Result (Invoke-StaticCompressorCase -Lines $orderLines -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'linha por arquivo ausente (multi)' -Result (Invoke-StaticCompressorCase -Lines (Remove-StaticCompressorLines -Lines $multiLines -Needle 'outro-generico.js -> 1') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'raiz do Verify diferente do Fix' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle 'Verify-GxJs: raiz' -Old $webDir -New (Join-Path $kbRoot 'Outra\web')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'Syntax error sem o fechamento esperado' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle 'Syntax error' -Old 'Syntax error : }' -New 'Syntax error : {') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'padrao de alerta detectado pelo wrapper' -Result (Invoke-StaticCompressorCase -Lines $base -Blocking 'Access denied' -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'timeout' -Result (Invoke-StaticCompressorCase -Lines $base -TimedOut $true -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'KB nao abriu' -Result (Invoke-StaticCompressorCase -Lines $base -KbOpen $false -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'metadata presente sem mapeamento do environment' -Result (Invoke-StaticCompressorCase -Lines $base -Root $kbRoot -MetadataPresent $true)
Assert-StaticCompressorRefused -Name 'raiz diferente do environment validado' -Result (Invoke-StaticCompressorCase -Lines $base -Root $kbRoot -MetadataPresent $true -ExpectedWebDir (Join-Path $kbRoot 'AmbienteB\web'))
Assert-StaticCompressorRefused -Name 'raiz fora da KB em build' -Result (Invoke-StaticCompressorCase -Lines $base -Root (Join-Path $staticRoot 'OutraKb'))

# Arquivo com o mesmo nome em subpasta: localizacao ambigua, nao pode dispensar.
$subDir = Join-Path $webDir 'sub'
try {
    [System.IO.Directory]::CreateDirectory($subDir) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $subDir 'arquivo-generico.js'), $validJs, [System.Text.UTF8Encoding]::new($false))
    Assert-StaticCompressorRefused -Name 'arquivo com nome ambiguo na raiz do Fix' -Result (Invoke-StaticCompressorCase -Lines $base -Root $kbRoot)
}
finally {
    Remove-Item -LiteralPath $subDir -Recurse -Force -ErrorAction SilentlyContinue
}

# node --check: arquivo corrigido com sintaxe invalida nao pode ser dispensado.
try {
    [System.IO.File]::WriteAllText($jsPath, 'var x = ;', [System.Text.UTF8Encoding]::new($false))
    Assert-StaticCompressorRefused -Name 'node --check falha no arquivo corrigido' -Result (Invoke-StaticCompressorCase -Lines $base -Root $kbRoot)
}
finally {
    [System.IO.File]::WriteAllText($jsPath, $validJs, [System.Text.UTF8Encoding]::new($false))
}


Assert-StaticCompressorRefused -Name 'erro em portugues fora do caso' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Erro ao gravar o relatorio de saida')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'nao foi possivel fora do GAM' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Nao foi possivel concluir a geracao do arquivo de saida')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'motivo de bloqueio ja registrado pelo wrapper' -Result (Test-GeneXusStaticCompressorKnownCase -StdOutLines $base -StdErrLines @() -GamNoiseLines @($gamLine) -MsBuildExitCode 0 -KbOpen $true -TimedOut $false -BuildAllDone $true -DetectedBlockingPattern '' -BlockingReasonCount 1 -KbRoot $kbRoot -MetadataPresent $false -ExpectedWebDir '')
$hashCheck = Invoke-StaticCompressorCase -Lines $base -Root $kbRoot
if (-not $hashCheck.recognized -or [string]::IsNullOrWhiteSpace($hashCheck.files[0].sha256) -or [string]::IsNullOrWhiteSpace($hashCheck.files[0].lastWriteUtc)) {
    throw 'ASSERT_FAILED: o arquivo reconhecido deveria registrar sha256 e data de modificacao.'
}
Assert-StaticCompressorRefused -Name 'sufixo com falha depois do colchete da linha de sintaxe' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle 'Syntax error : }' -Old 'Syntax error : } [C:\exemplo\buildall.msbuild]' -New 'Syntax error : } [C:\exemplo\buildall.msbuild] Failed: detalhe') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'sufixo de texto livre na linha de sintaxe' -Result (Invoke-StaticCompressorCase -Lines (Replace-StaticCompressorLines -Lines $base -Needle 'Syntax error : }' -Old 'Syntax error : } [C:\exemplo\buildall.msbuild]' -New 'Syntax error : } operacao extra') -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'portugues acentuado nao foi possivel' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Não foi possível concluir a geração do arquivo de saída')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'mensagem nao prevista no mesmo arquivo com erro' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'arquivo-generico.js(1950): Unterminated string constant')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'NuGet sob GAM (caminho real) contado pelo classificador' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'C:\Program Files (x86)\GeneXus\GeneXus18\Library\GAM\Platforms\NetCorePostgreSQL\NuGet.targets(120,5): error : Access to the path is denied.')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'permission denied fora do caso' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Permission denied ao acessar o diretorio de saida')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'could not copy fora do caso' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + 'Could not copy the output file')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'resumo 0 Error(s) do MSBuild recusa (conservador)' -Result (Invoke-StaticCompressorCase -Lines ([string[]]($base + '    0 Error(s)')) -Root $kbRoot)
Assert-StaticCompressorRefused -Name 'sem marca de compressao antes dos erros' -Result (Invoke-StaticCompressorCase -Lines (Remove-StaticCompressorLines -Lines $base -Needle 'Comprimindo arquivos') -Root $kbRoot)
$classifierMismatch = Test-GeneXusStaticCompressorKnownCase -StdOutLines $base -StdErrLines @() -GamNoiseLines @($gamLine) -MsBuildExitCode 0 -KbOpen $true -TimedOut $false -BuildAllDone $true -DetectedBlockingPattern '' -BlockingReasonCount 0 -ClassifierErrorCount 2 -KbRoot $kbRoot -MetadataPresent $false -ExpectedWebDir ''
Assert-StaticCompressorRefused -Name 'classificador contou mais erros que a regra reconhece' -Result $classifierMismatch
$countOne = Test-GeneXusStaticCompressorKnownCase -StdOutLines $base -StdErrLines @() -GamNoiseLines @($gamLine) -MsBuildExitCode 0 -KbOpen $true -TimedOut $false -BuildAllDone $true -DetectedBlockingPattern '' -BlockingReasonCount 0 -ClassifierErrorCount 1 -KbRoot $kbRoot -MetadataPresent $false -ExpectedWebDir ''
if (-not $countOne.recognized) {
    throw "ASSERT_FAILED: classificador contou 1 erro e o caso deveria ser reconhecido: $($countOne.reason)"
}
$roundtripCases = @(
    @{ Name = 'compilou limpo'; Exit = 0; Ok = $true; Json = [pscustomobject]@{ status = 'compilou limpo' }; Expected = 'roundtrip-ok' },
    @{ Name = 'pendente'; Exit = 0; Ok = $true; Json = [pscustomobject]@{ status = 'operacao concluida, pendente de confirmacao funcional' }; Expected = 'roundtrip-pendente-confirmacao' },
    @{ Name = 'json ilegivel'; Exit = 0; Ok = $false; Json = $null; Expected = 'roundtrip-pendente-confirmacao' },
    @{ Name = 'json ausente'; Exit = 0; Ok = $true; Json = $null; Expected = 'roundtrip-pendente-confirmacao' },
    @{ Name = 'categoria B bloqueada'; Exit = 0; Ok = $true; Json = [pscustomobject]@{ status = 'compilou limpo'; msBuildCategoryBBlocked = $true }; Expected = 'roundtrip-pendente-confirmacao' },
    @{ Name = 'falha de pos-processamento'; Exit = 0; Ok = $true; Json = [pscustomobject]@{ status = 'compilou limpo'; postProcessingFailed = $true }; Expected = 'roundtrip-pendente-confirmacao' },
    @{ Name = 'exit do BuildAll 48'; Exit = 48; Ok = $true; Json = [pscustomobject]@{ status = 'compilou limpo' }; Expected = 'build-failed-or-blocked' }
)
foreach ($case in $roundtripCases) {
    $got = Get-GeneXusRoundtripStatus -ExitCode $case.Exit -BuildJsonOk $case.Ok -BuildJson $case.Json
    if ($got -ne $case.Expected) {
        throw "ASSERT_FAILED: roundtrip '$($case.Name)' esperado $($case.Expected), obtido $got"
    }
}

# T1-a / T1-b: CssProperties conhecido (com Trim/indentacao) vs outro "foi negado."
$cssTrimmed = "O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado."
$cssIndented = "  $cssTrimmed"
$cssRecognized = Test-GeneXusStaticCompressorKnownCase `
    -StdOutLines ([string[]]($base + $cssIndented)) `
    -StdErrLines @() `
    -GamNoiseLines @($gamLine, $cssTrimmed) `
    -MsBuildExitCode 0 -KbOpen $true -TimedOut $false -BuildAllDone $true `
    -DetectedBlockingPattern '' -BlockingReasonCount 0 -ClassifierErrorCount 1 `
    -KbRoot $kbRoot -MetadataPresent $false -ExpectedWebDir ''
if (-not $cssRecognized.recognized) {
    throw "ASSERT_FAILED: T1-a CssProperties indentado com line Trim no ruido deveria reconhecer: $($cssRecognized.reason)"
}
Assert-StaticCompressorRefused -Name 'T1-b outro caminho foi negado' -Result (
    Test-GeneXusStaticCompressorKnownCase `
        -StdOutLines ([string[]]($base + "O acesso ao caminho 'C:\outro\arquivo.json' foi negado.")) `
        -StdErrLines @() `
        -GamNoiseLines @($gamLine, $cssTrimmed) `
        -MsBuildExitCode 0 -KbOpen $true -TimedOut $false -BuildAllDone $true `
        -DetectedBlockingPattern '' -BlockingReasonCount 0 -ClassifierErrorCount 1 `
        -KbRoot $kbRoot -MetadataPresent $false -ExpectedWebDir ''
)

# T1-f: recognized sobrevive a ConvertTo-Json -Depth 3 (caminho de fallback).
$depthProbe = [pscustomobject]@{
    staticCompressorKnownCase = [pscustomobject]@{
        recognized = $true
        reason     = $null
        files      = @([pscustomobject]@{ fileName = 'arquivo-generico.js'; sha256 = 'abc' })
    }
}
$depthBack = ($depthProbe | ConvertTo-Json -Depth 3 | ConvertFrom-Json)
if ($depthBack.staticCompressorKnownCase.recognized -ne $true) {
    throw 'ASSERT_FAILED: T1-f ConvertTo-Json -Depth 3 deveria preservar staticCompressorKnownCase.recognized=$true'
}

Remove-Item -LiteralPath $staticRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'MSBUILD_CATEGORY_B_SUPPORT_SELFTEST_OK'
