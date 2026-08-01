#requires -Version 7.4
<#
.SYNOPSIS
    Cria um import_file.xml a partir de uma frente local da pasta paralela da KB.

.DESCRIPTION
    Wrapper fino para scripts\New-XpzImportPackage.py. Mantem um ponto de entrada
    PowerShell curto para allowlist local, deixando a montagem XML no motor Python.
    Para Panel, o resultado JSON inclui information quando o par level/layout e
    confirmado pelo template comparavel e warnings quando o par não e confirmado
    ou não ha template comparavel.

    O gate de drift frente-vs-acervo (Test-GeneXusFrontAcervoDrift.ps1) e SEMPRE
    executado ANTES de chamar o motor Python (fail-closed). -AcervoPath explicito
    vence; quando omitido, o acervo canonico <RepoRoot>/ObjetosDaKbEmXml e usado.
    Sem acervo resolvido, o empacotamento e bloqueado — o gate nunca e pulado por
    omissao. Se o gate retornar status fail ou alert, o empacotamento e abortado.
    O campo acervoResolvedBy no JSON indica como o acervo foi resolvido
    (explicit ou convention).

.PARAMETER RepoRoot
    Raiz da pasta paralela da KB.

.PARAMETER FrontName
    Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD.

.PARAMETER NN
    Rodada curta do pacote. Default: 01.

.PARAMETER TemplatePackagePath
    Pacote import_file.xml ou XPZ real comparavel para clonar KMW, Source,
    Dependencies e ObjectsIdentityMapping. Quando o template trouxer Attributes
    de topo e a frente não trouxer atributos explicitos, o motor preserva esses
    Attributes. Quando omitido, o motor usa envelope mínimo derivado de
    kb-source-metadata.md. Para Panel, especialmente Panel SD, preferir template
    real exportado pela IDE da mesma KB; par confirmado e reportado em information.

.PARAMETER AcervoPath
    Caminho para a pasta do acervo oficial (ObjetosDaKbEmXml). Opcional: quando
    omitido, o acervo canonico <RepoRoot>/ObjetosDaKbEmXml e resolvido
    automaticamente. O gate de drift frente-vs-acervo roda sempre antes do
    empacotamento; sem acervo explicito nem canonico, o empacotamento e
    bloqueado (fail-closed). Se o gate detectar que um XML da frente está mais
    antigo que o homonimo no acervo (front-older-than-acervo) ou Object/@type
    divergente para o mesmo guid (front-object-type-drift), o empacotamento e
    abortado. O gate também bloqueia remocao forte de trailing whitespace herdado
    contra baseline por GUID unico (front-textual-fidelity-trim-removal-churn);
    essa protecao e parcial, não um detector completo de whitespace,
    reindentacao ou EOL. O finding front-textual-fidelity-info e apenas
    informativo quando havia baseline unico por GUID, mas a leitura/decodificacao
    UTF-8 comparavel falhou. Findings warn (front-equals-acervo ou
    lastupdate-unparseable) também bloqueiam esta chamada automática ate
    confirmacao/resolucao fora do wrapper; front-object-type-drift exige decisao
    humana, sem autocopia/bump.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [string]$AcervoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-XpzPackageJson {
    param([Parameter(Mandatory = $true)][object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 10)
}

function Write-XpzPackageJsonAndExit {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )
    ConvertTo-XpzPackageJson -InputObject $InputObject
    exit $ExitCode
}

trap {
    $failure = [ordered]@{
        status = 'erro'
        exitCode = 90
        stage = 'powershell-wrapper'
        blockingReasons = @($_.Exception.Message)
        warnings = @()
    }
    Write-XpzPackageJsonAndExit -InputObject $failure -ExitCode 90
}

$enginePath = Join-Path $PSScriptRoot 'New-XpzImportPackage.py'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'preflight'
        blockingReasons = @("motor Python nao encontrado: $enginePath")
        warnings = @()
    }) -ExitCode 20
}

# Resolucao do acervo (fail-closed): -AcervoPath explicito vence; senao, acervo
# canonico <RepoRoot>/ObjetosDaKbEmXml. Sem acervo resolvido, o empacotamento e
# bloqueado — o gate de drift de lastUpdate nunca e pulado por omissao.
# Footgun nomeado: import com lastUpdate menor ou igual ao objeto vivo na KB
# passa em silencio (exitCode 0, sem efeito) e desperdica um ciclo import+build.
$acervoResolvedBy = $null
$acervoEffective  = $null
if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
    $acervoEffective  = (Resolve-Path -LiteralPath $AcervoPath -ErrorAction Stop).Path
    $acervoResolvedBy = 'explicit'
} else {
    $conventionAcervo = Join-Path $RepoRoot 'ObjetosDaKbEmXml'
    if (Test-Path -LiteralPath $conventionAcervo -PathType Container) {
        $acervoEffective  = (Resolve-Path -LiteralPath $conventionAcervo).Path
        $acervoResolvedBy = 'convention'
    } else {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
            status = 'bloqueado'
            exitCode = 20
            stage = 'front-acervo-drift'
            repoRoot = $RepoRoot
            frontName = $FrontName
            acervoResolvedBy = $null
            blockingReasons = @("Acervo nao informado e acervo canonico ausente em '$conventionAcervo'. O gate de drift de lastUpdate nao pode ser pulado por omissao: informe -AcervoPath apontando para ObjetosDaKbEmXml. Footgun: import com lastUpdate menor ou igual ao objeto vivo na KB passa em silencio (exitCode 0, sem efeito) e desperdica um ciclo import+build.")
            warnings = @()
        }) -ExitCode 20
    }
}

# Gate de drift frente-vs-acervo (sempre executado, antes do motor Python)
$frontDir = Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $FrontName
if (-not (Test-Path -LiteralPath $frontDir -PathType Container)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'front-acervo-drift'
        repoRoot = $RepoRoot
        frontName = $FrontName
        acervoResolvedBy = $acervoResolvedBy
        blockingReasons = @("Pasta da frente nao encontrada: $frontDir")
        warnings = @()
    }) -ExitCode 20
}
$driftGatePath = Join-Path $PSScriptRoot 'Test-GeneXusFrontAcervoDrift.ps1'
if (-not (Test-Path -LiteralPath $driftGatePath -PathType Leaf)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'front-acervo-drift'
        repoRoot = $RepoRoot
        frontName = $FrontName
        acervoResolvedBy = $acervoResolvedBy
        blockingReasons = @("gate de drift nao encontrado: $driftGatePath")
        warnings = @()
    }) -ExitCode 20
}
$driftOutput = & $driftGatePath -FrontFolder $frontDir -AcervoFolder $acervoEffective -AsJson 2>&1
$driftResult = $driftOutput | ConvertFrom-Json
if ($driftResult.status -eq 'fail') {
    $failFindings = @($driftResult.findings | Where-Object { $_.severity -eq 'fail' })
    $blockMsgs = @($failFindings | ForEach-Object { $_.message })
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'front-acervo-drift'
        repoRoot = $RepoRoot
        frontName = $FrontName
        acervoResolvedBy = $acervoResolvedBy
        driftStatus = $driftResult.status
        driftFindings = $driftResult.findings
        driftObjectsScanned = $driftResult.objectsScanned
        blockingReasons = @("gate de drift frente-vs-acervo falhou ($($blockMsgs.Count) finding(s) fatal(is)): $($blockMsgs -join '; ')")
        warnings = @()
    }) -ExitCode 20
}
if ($driftResult.status -eq 'alert') {
    $warnFindings = @($driftResult.findings | Where-Object { $_.severity -eq 'warn' })
    $warnMsgs = @($warnFindings | ForEach-Object { $_.message })
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'front-acervo-drift'
        repoRoot = $RepoRoot
        frontName = $FrontName
        acervoResolvedBy = $acervoResolvedBy
        driftStatus = $driftResult.status
        driftFindings = $driftResult.findings
        driftObjectsScanned = $driftResult.objectsScanned
        blockingReasons = @("gate de drift frente-vs-acervo retornou alerta ($($warnMsgs.Count) finding(s) warn): confirmacao explicita ou resolucao manual requerida antes de empacotar. $($warnMsgs -join '; ')")
        warnings = @($warnMsgs)
    }) -ExitCode 20
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'preflight'
        blockingReasons = @('python nao encontrado no PATH para executar New-XpzImportPackage.py')
        warnings = @()
    }) -ExitCode 20
}

$engineArgs = @(
    $enginePath,
    '--repo-root', $RepoRoot,
    '--front-name', $FrontName,
    '--nn', $NN
)

if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) {
    $engineArgs += @('--template-package-path', $TemplatePackagePath)
}

$outputText = (& $pythonCommand.Source @engineArgs 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
$engineExitCode = $LASTEXITCODE

try {
    $result = $outputText | ConvertFrom-Json
} catch {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'erro'
        exitCode = 90
        stage = 'python-engine'
        blockingReasons = @('motor Python retornou saida nao JSON')
        rawOutput = $outputText
        warnings = @()
    }) -ExitCode 90
}

if ($engineExitCode -ne 0) {
    if ($null -eq $result.PSObject.Properties['exitCode']) {
        $result | Add-Member -NotePropertyName exitCode -NotePropertyValue $engineExitCode -Force
    }
    if ($null -eq $result.PSObject.Properties['stage']) {
        $result | Add-Member -NotePropertyName stage -NotePropertyValue 'python-engine' -Force
    }
    Write-XpzPackageJsonAndExit -InputObject $result -ExitCode $engineExitCode
}

if (-not [string]::IsNullOrWhiteSpace([string]$result.outputPath)) {
    . (Join-Path $PSScriptRoot 'GeneXusPackageInventorySupport.ps1')
    $declaredDelta = Get-DeclaredDeltaItemsFromFrontObjectXmls -FrontDir $result.sourceFolder
    $sidecarInventoryPath = ([string]$result.outputPath) + '.package-inventory.json'
    $inventoryBlock = New-PackageInventoryResult `
        -InputPath $result.outputPath `
        -DeclaredDeltaItems $declaredDelta `
        -SidecarInventoryPath $sidecarInventoryPath
    $result | Add-Member -NotePropertyName packageInventory -NotePropertyValue $inventoryBlock.packageInventory -Force
    $result | Add-Member -NotePropertyName inventoryDegraded -NotePropertyValue $inventoryBlock.inventoryDegraded -Force
    $result | Add-Member -NotePropertyName inventoryError -NotePropertyValue $inventoryBlock.inventoryError -Force
}

$result | Add-Member -NotePropertyName acervoResolvedBy -NotePropertyValue $acervoResolvedBy -Force
if ($null -ne $driftResult) {
    $result | Add-Member -NotePropertyName driftStatus -NotePropertyValue $driftResult.status -Force
    $result | Add-Member -NotePropertyName driftFindings -NotePropertyValue $driftResult.findings -Force
    $result | Add-Member -NotePropertyName driftObjectsScanned -NotePropertyValue $driftResult.objectsScanned -Force
}

ConvertTo-XpzPackageJson -InputObject $result
