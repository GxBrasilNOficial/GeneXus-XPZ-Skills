#requires -Version 7.4
<#
.SYNOPSIS
    Executa casos minimos de validação do inventario de wrappers XPZ.

.DESCRIPTION
    Cria uma pasta paralela temporaria e uma pasta temporaria de exemplos para validar
    que divergencia de #requires -Version classifica wrapper como CUSTOMIZADO, sem
    tratar Test-*KbPowerShellRuntime.ps1 como falso positivo. Também valida os sinais
    consultivos de wrappers recomendados ausentes e os sinais bloqueantes de scripts
    legados orfaos, e os motivos de INVENTORY_CUSTOMIZED: missing_AsJson_passthrough
    (K8/K9), consumes_legacy_text_stdout (Update-*KbFromXpz) e forwards_unknown_engine_param
    (repasse a motor compartilhado advanced de parametro nao-declarado; caso end-to-end).
    Valida ainda o diff de superficie wrapper-vs-molde (surface_mismatch -> INVENTORY_CUSTOMIZED;
    reducoes opcionais/ValidateSet -> INVENTORY_SURFACE_ADVISORY) em casos de unidade + end-to-end,
    mais a guarda-regressao que localiza por conteudo o regex de pendencia do agregador
    (Test-XpzSetupAudit.ps1) e falha se ele casar os rotulos de aviso.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$inventoryScriptPath = Join-Path $scriptDir 'Test-XpzWrapperInventory.ps1'
# Dot-source do helper para os casos de UNIDADE do diff de superficie (Get-XpzWrapperSurfaceFinding).
. (Join-Path $scriptDir 'XpzWrapperEngineParamSupport.ps1')
# Fonte unica de encoding UTF-8 sem BOM (norma de reuso; ver 09-inventario, Utf8NoBomEncodingSupport.ps1).
. (Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1')

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw "ASSERT_FAILED: $Message | output=$Text"
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Text -match $Pattern) {
        throw "ASSERT_FAILED: $Message | output=$Text"
    }
}

# --- Auxiliares dos casos de UNIDADE do diff de superficie ---
$script:surfaceFixtureCounter = 0
$script:surfaceUtf8 = Get-Utf8NoBomEncoding

function New-SurfaceFixture {
    param([string]$Dir, [string]$Content)
    $script:surfaceFixtureCounter++
    $p = Join-Path $Dir ('sfx-{0}.ps1' -f $script:surfaceFixtureCounter)
    [System.IO.File]::WriteAllText($p, $Content, $script:surfaceUtf8)
    return $p
}

function Get-SurfaceReasonList {
    param([object[]]$Items)
    if (-not $Items) { return '' }
    return ((@($Items | ForEach-Object { [string]$_.Reason }) | Sort-Object) -join '|')
}

function Assert-Surface {
    # Compara os reasons (ordenados) de Blocking/Advisory de Get-XpzWrapperSurfaceFinding contra o esperado.
    param(
        [string]$Molde,
        [string]$Local,
        [string]$Dir,
        [string[]]$Block = @(),
        [string[]]$Adv = @(),
        [string]$Message
    )
    $moldePath = New-SurfaceFixture -Dir $Dir -Content $Molde
    $localPath = New-SurfaceFixture -Dir $Dir -Content $Local
    $finding = Get-XpzWrapperSurfaceFinding -MoldePath $moldePath -LocalPath $localPath
    $gotB = Get-SurfaceReasonList $finding.Blocking
    $gotA = Get-SurfaceReasonList $finding.Advisory
    $wantB = ((@($Block) | Sort-Object) -join '|')
    $wantA = ((@($Adv) | Sort-Object) -join '|')
    if ($gotB -ne $wantB) { throw "ASSERT_FAILED: $Message (blocking) esperado=[$wantB] obtido=[$gotB]" }
    if ($gotA -ne $wantA) { throw "ASSERT_FAILED: $Message (advisory) esperado=[$wantA] obtido=[$gotA]" }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-wrapper-inventory-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$kbRoot = Join-Path $tempRoot 'Kb'
$scriptsPath = Join-Path $kbRoot 'scripts'
$examplesPath = Join-Path $tempRoot 'examples'

try {
    [void](New-Item -ItemType Directory -Path $scriptsPath -Force)
    [void](New-Item -ItemType Directory -Path $examplesPath -Force)

    @'
## Source/Version

| field | value |
|---|---|
| name | Demo |
'@ | Set-Content -LiteralPath (Join-Path $kbRoot 'kb-source-metadata.md') -Encoding utf8NoBOM

    @'
#requires -Version 7.4
Write-Output "metadata"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Get-KbMetadata.example.ps1') -Encoding utf8NoBOM

    @'
#requires -version 5.1
Write-Output "metadata"
'@ | Set-Content -LiteralPath (Join-Path $scriptsPath 'Get-DemoKbMetadata.ps1') -Encoding utf8NoBOM

    @'
Write-Output "runtime"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Test-KbPowerShellRuntime.example.ps1') -Encoding utf8NoBOM

    @'
Write-Output "runtime"
'@ | Set-Content -LiteralPath (Join-Path $scriptsPath 'Test-DemoKbPowerShellRuntime.ps1') -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern '\bINVENTORY_CUSTOMIZED\b' -Message 'requires divergente deve classificar CUSTOMIZADO'
    Assert-Contains -Text $output -Pattern 'Get-DemoKbMetadata\.ps1\(reason=requires_version_mismatch: local=5\.1 canonical=7\.4\)' -Message 'diagnostico deve identificar wrapper e versoes'
    Assert-NotContains -Text $output -Pattern '\bINVENTORY_OK\b' -Message 'inventario com CUSTOMIZADO nao pode retornar OK'
    Assert-NotContains -Text $output -Pattern 'Test-DemoKbPowerShellRuntime\.ps1\(reason=requires_version_mismatch' -Message 'wrapper de runtime e excecao intencional'

    foreach ($optionalExample in @('New-KbFront', 'Get-KbLastUpdate', 'New-KbImportPackage', 'Resolve-KbIdentity', 'Resolve-KbGeneratedCsPath')) {
        @'
#requires -Version 7.4
Write-Output "optional"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath "$optionalExample.example.ps1") -Encoding utf8NoBOM
    }

    $frontPath = Join-Path $kbRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus\MinhaFrente_11111111-1111-1111-1111-111111111111_20260524'
    $packagesPath = Join-Path $kbRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'
    [void](New-Item -ItemType Directory -Path $frontPath -Force)
    [void](New-Item -ItemType Directory -Path $packagesPath -Force)
    '<Object lastUpdate="2026-05-24T00:00:00.0000000Z" />' |
        Set-Content -LiteralPath (Join-Path $frontPath 'Objeto.xml') -Encoding utf8NoBOM
    '<ExportFile />' |
        Set-Content -LiteralPath (Join-Path $packagesPath 'MinhaFrente_11111111-1111-1111-1111-111111111111_20260524_01.import_file.xml') -Encoding utf8NoBOM
    '| kb (GUID) | 11111111-1111-1111-1111-111111111111 |' |
        Add-Content -LiteralPath (Join-Path $kbRoot 'kb-source-metadata.md') -Encoding utf8NoBOM

    foreach ($scriptName in @(
        'Test-DemoKbFullSnapshot.ps1',
        'Test-DemoFullSnapshot.ps1',
        'Update-DemoKbFromXpz.ps1',
        'Update-DemoFromXpz.ps1',
        'Test-DemoKbIndexGate.ps1',
        'Test-DemoKbGate.ps1'
    )) {
        '#requires -Version 7.4' |
            Set-Content -LiteralPath (Join-Path $scriptsPath $scriptName) -Encoding utf8NoBOM
    }

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern '\bINVENTORY_LEGACY_ORPHANS\b' -Message 'scripts legados lado a lado devem ser reportados'
    Assert-Contains -Text $output -Pattern 'Test-DemoKbIndexGate\.ps1\(legacy=Test-DemoKbGate\.ps1\)' -Message 'gate legado deve apontar para canonico atual'
    Assert-Contains -Text $output -Pattern '\bINVENTORY_RECOMMENDED_MISSING\b' -Message 'wrappers recomendados ausentes devem ser reportados'
    Assert-Contains -Text $output -Pattern 'New-DemoKbFront\.ps1' -Message 'historico de frente deve recomendar wrapper de abertura'
    Assert-Contains -Text $output -Pattern 'Get-DemoKbLastUpdate\.ps1' -Message 'lastUpdate em XML gerado deve recomendar wrapper de timestamp'
    Assert-Contains -Text $output -Pattern 'New-DemoKbImportPackage\.ps1' -Message 'pacote import_file deve recomendar wrapper de pacote'
    Assert-Contains -Text $output -Pattern 'Resolve-DemoKbIdentity\.ps1' -Message 'metadata de identidade deve recomendar wrapper de identidade'

    @'
#requires -Version 7.4
param(
    [Parameter(Mandatory = $true)][string[]]$KbEnvironmentNames,
    [Parameter(Mandatory = $true)][string[]]$KbEnvironmentOutputDirs,
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
Write-Output "deployment"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Set-KbSourceMetadataDeployment.example.ps1') -Encoding utf8NoBOM

    $deploymentStandardPath = Join-Path $scriptsPath 'Set-DemoKbSourceMetadataDeployment.ps1'

    @'
#requires -Version 7.4
param(
    [switch]$InventoryFromKbNativePath,
    [string[]]$KbEnvironmentNames,
    [string[]]$KbEnvironmentOutputDirs,
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=uses_removed_inventory_discovery\)' -Message 'wrapper com InventoryFromKbNativePath deve ser sinalizado como descoberta automatica removida'

    @'
#requires -Version 7.4
param(
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_KbEnvironmentNames\)' -Message 'wrapper sem KbEnvironmentNames deve ser sinalizado'

    @'
#requires -Version 7.4
param(
    [string[]]$KbEnvironmentNames,
    [string]$KbNativePath,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_KbEnvironmentOutputDirs\)' -Message 'wrapper sem KbEnvironmentOutputDirs deve ser sinalizado'

    @'
#requires -Version 7.4
param(
    [string[]]$KbEnvironmentNames,
    [string[]]$KbEnvironmentOutputDirs,
    [string]$InventoryWorkingDirectory
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_KbNativePath_for_msbuild_validation\)' -Message 'wrapper sem KbNativePath deve ser sinalizado'

    @'
#requires -Version 7.4
param(
    [string[]]$KbEnvironmentNames,
    [string[]]$KbEnvironmentOutputDirs,
    [string]$KbNativePath
)
'@ | Set-Content -LiteralPath $deploymentStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Set-DemoKbSourceMetadataDeployment\.ps1\(reason=missing_InventoryWorkingDirectory_for_msbuild_validation\)' -Message 'wrapper sem InventoryWorkingDirectory deve ser sinalizado'

    # K8/K9: molde repassa -AsJson; wrapper local sem -AsJson deve virar CUSTOMIZADO
    @'
#requires -Version 7.4
param([switch]$AsJson)
& $enginePath -AsJson:$AsJson
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Test-KbSetupAudit.example.ps1') -Encoding utf8NoBOM
    @'
#requires -Version 7.4
param([switch]$AsJson)
$forward = @{}
if ($AsJson) { $forward['AsJson'] = $true }
& $engine @forward
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Test-KbIndexGate.example.ps1') -Encoding utf8NoBOM

    $setupAuditStandardPath = Join-Path $scriptsPath 'Test-DemoKbSetupAudit.ps1'
    $indexGateStandardPath = Join-Path $scriptsPath 'Test-DemoKbIndexGate.ps1'

    @'
#requires -Version 7.4
param()
& $enginePath
'@ | Set-Content -LiteralPath $setupAuditStandardPath -Encoding utf8NoBOM

    @'
#requires -Version 7.4
param()
& $engine
'@ | Set-Content -LiteralPath $indexGateStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Test-DemoKbSetupAudit\.ps1\(reason=missing_AsJson_passthrough\)' -Message 'wrapper K8 sem repasse de -AsJson deve ser sinalizado'
    Assert-Contains -Text $output -Pattern 'Test-DemoKbIndexGate\.ps1\(reason=missing_AsJson_passthrough\)' -Message 'wrapper K9 sem repasse de -AsJson deve ser sinalizado'

    # Mesmos wrappers, agora repassando -AsJson, nao podem ser sinalizados por esse motivo
    @'
#requires -Version 7.4
param([switch]$AsJson)
& $enginePath -AsJson:$AsJson
'@ | Set-Content -LiteralPath $setupAuditStandardPath -Encoding utf8NoBOM

    @'
#requires -Version 7.4
param([switch]$AsJson)
$forward = @{}
if ($AsJson) { $forward['AsJson'] = $true }
& $engine @forward
'@ | Set-Content -LiteralPath $indexGateStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-NotContains -Text $output -Pattern 'Test-DemoKbSetupAudit\.ps1\(reason=missing_AsJson_passthrough\)' -Message 'wrapper K8 com repasse de -AsJson nao pode ser sinalizado por esse motivo'
    Assert-NotContains -Text $output -Pattern 'Test-DemoKbIndexGate\.ps1\(reason=missing_AsJson_passthrough\)' -Message 'wrapper K9 com repasse de -AsJson nao pode ser sinalizado por esse motivo'

    # Migracao parcial: declara [switch]$AsJson mas NAO repassa ao motor -> deve ser
    # sinalizado (a checagem detecta o repasse, nao a mera mencao do termo).
    @'
#requires -Version 7.4
param([switch]$AsJson)
& $enginePath
'@ | Set-Content -LiteralPath $setupAuditStandardPath -Encoding utf8NoBOM

    @'
#requires -Version 7.4
param([switch]$AsJson)
$forward = @{}
& $engine @forward
'@ | Set-Content -LiteralPath $indexGateStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Test-DemoKbSetupAudit\.ps1\(reason=missing_AsJson_passthrough\)' -Message 'wrapper K8 que declara AsJson mas nao repassa deve ser sinalizado'
    Assert-Contains -Text $output -Pattern 'Test-DemoKbIndexGate\.ps1\(reason=missing_AsJson_passthrough\)' -Message 'wrapper K9 que declara AsJson mas nao repassa deve ser sinalizado'

    # Update-KbFromXpz x Sync-GeneXusXpzToXml: drift de contrato de CONSUMO. O molde consome o
    # stdout do motor como JSON v1 (ConvertFrom-Json); wrapper local que ainda trata como TEXTO
    # (sem ConvertFrom-Json) deve ser sinalizado consumes_legacy_text_stdout.
    @'
#requires -Version 7.4
param([string]$InputPath)
$raw = & $enginePath -InputPath $InputPath
$result = $raw | ConvertFrom-Json
[Console]::Error.WriteLine("Created: $($result.Created)")
$raw
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Update-KbFromXpz.example.ps1') -Encoding utf8NoBOM

    $updateStandardPath = Join-Path $scriptsPath 'Update-DemoKbFromXpz.ps1'

    # FALHA: wrapper textual antigo (Format-List, sem ConvertFrom-Json)
    @'
#requires -Version 7.4
param([string]$InputPath)
$result = & $enginePath -InputPath $InputPath
$result | Format-List
'@ | Set-Content -LiteralPath $updateStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Update-DemoKbFromXpz\.ps1\(reason=consumes_legacy_text_stdout\)' -Message 'wrapper Update-*KbFromXpz textual (sem ConvertFrom-Json) deve ser sinalizado'

    # PASSA: wrapper migrado para o contrato JSON v1 (consome ConvertFrom-Json) nao pode ser
    # sinalizado por esse motivo
    @'
#requires -Version 7.4
param([string]$InputPath)
$raw = & $enginePath -InputPath $InputPath
$result = $raw | ConvertFrom-Json
[Console]::Error.WriteLine("Created: $($result.Created)")
$raw
'@ | Set-Content -LiteralPath $updateStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-NotContains -Text $output -Pattern 'Update-DemoKbFromXpz\.ps1\(reason=consumes_legacy_text_stdout\)' -Message 'wrapper Update-*KbFromXpz migrado para JSON v1 nao pode ser sinalizado por esse motivo'

    # Register-KbPostBuildEvents: motor compartilhado .ps1 bem-sucedido nao define
    # necessariamente $LASTEXITCODE. O padrao legado `exit $LASTEXITCODE` quebra sob
    # StrictMode mesmo depois de registrar a metadata.
    @'
#requires -Version 7.4
param([string]$BuildResultJsonPath)
& $engineScript -BuildResultJsonPath $BuildResultJsonPath
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Register-KbPostBuildEvents.example.ps1') -Encoding utf8NoBOM

    $registerStandardPath = Join-Path $scriptsPath 'Register-DemoKbPostBuildEvents.ps1'
    @'
#requires -Version 7.4
param([string]$BuildResultJsonPath)
& $engineScript -BuildResultJsonPath $BuildResultJsonPath
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $registerStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Register-DemoKbPostBuildEvents\.ps1\(reason=unsafe_last_exitcode_after_ps1_engine\)' -Message 'wrapper Register-*KbPostBuildEvents com exit LASTEXITCODE apos .ps1 deve ser sinalizado'

    @'
#requires -Version 7.4
param([string]$BuildResultJsonPath)
& $engineScript -BuildResultJsonPath $BuildResultJsonPath
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
'@ | Set-Content -LiteralPath $registerStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-NotContains -Text $output -Pattern 'Register-DemoKbPostBuildEvents\.ps1\(reason=unsafe_last_exitcode_after_ps1_engine\)' -Message 'wrapper Register-*KbPostBuildEvents com saida segura nao pode ser sinalizado por esse motivo'

    # forwards_unknown_engine_param end-to-end: wrapper local que repassa parametro inexistente
    # a motor compartilhado advanced REAL (Test-GeneXusSourceSanity.ps1) deve sair dentro da
    # linha INVENTORY_CUSTOMIZED (capturada pelo agregador).
    @'
#requires -Version 7.4
Write-Output "sanity"
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Test-KbSourceSanity.example.ps1') -Encoding utf8NoBOM

    @'
#requires -Version 7.4
param([string]$InputPath)
$enginePath = Join-Path $SharedSkillsRoot 'scripts\Test-GeneXusSourceSanity.ps1'
& $enginePath -InputPath $InputPath -BogusXyz $z
'@ | Set-Content -LiteralPath (Join-Path $scriptsPath 'Test-DemoKbSourceSanity.ps1') -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Test-DemoKbSourceSanity\.ps1\(reason=forwards_unknown_engine_param: -BogusXyz -> Test-GeneXusSourceSanity\.ps1\)' -Message 'parametro inexistente repassado a motor advanced deve ser sinalizado pelo inventario dentro de INVENTORY_CUSTOMIZED'

    # ============================================================================
    # Diff de superficie de wrapper (surface_mismatch / INVENTORY_SURFACE_ADVISORY)
    # UNIDADE: Get-XpzWrapperSurfaceFinding com fixtures surface-fieis (so a superficie importa).
    # ============================================================================
    $surfaceDir = Join-Path $tempRoot 'surface'
    [void](New-Item -ItemType Directory -Path $surfaceDir -Force)
    $D = $surfaceDir

    # BLOQUEIA: perda de contrato obrigatorio
    Assert-Surface -Dir $D -Molde 'param([Parameter(Mandatory)][string]$Query, [string]$Opt)' -Local 'param([string]$Opt)' -Block @('mandatory_param_missing') -Message 'U01 obrigatorio ausente -> surface_mismatch'
    Assert-Surface -Dir $D -Molde 'param([Parameter(Mandatory)][string]$Q)' -Local 'param([string]$Q)' -Block @('mandatory_downgraded') -Message 'U10 obrigatorio rebaixado -> surface_mismatch'
    Assert-Surface -Dir $D -Molde 'param([Parameter(Mandatory)][string]$Q)' -Local 'param([string]$Other)' -Block @('mandatory_param_missing') -Message 'U14 [Parameter(Mandatory)] sem =$true e obrigatorio'
    Assert-Surface -Dir $D -Molde 'param([System.Management.Automation.ParameterAttribute(Mandatory=$true)][string]$Q)' -Local 'param([string]$Other)' -Block @('mandatory_param_missing') -Message 'U16 [Parameter] por FQN e lido'
    Assert-Surface -Dir $D -Molde 'param([Parameter(ParameterSetName="A")][Parameter(ParameterSetName="B",Mandatory=$true)][string]$Q)' -Local 'param([string]$Q)' -Block @('mandatory_downgraded') -Message 'U12 multiplos [Parameter] com Mandatory num set -> obrigatorio'

    # BLOQUEIA / AVISA / QUIETO conforme a superficie do MOLDE quando o LOCAL nao tem param() de topo (v14)
    $localFn = "function Foo { param([Parameter(Mandatory)][string]`$X) }`nWrite-Output 'x'"
    Assert-Surface -Dir $D -Molde 'param([Parameter(Mandatory)][string]$Q)' -Local $localFn -Block @('no_param_block') -Message 'U13a sem param() topo + molde obrigatorio -> surface_mismatch no_param_block (nao herda da funcao interna)'
    Assert-Surface -Dir $D -Molde 'param([string]$Q)' -Local $localFn -Adv @('no_param_block') -Message 'U13b sem param() topo + molde so-opcional -> advisory no_param_block'
    Assert-Surface -Dir $D -Molde "[CmdletBinding()]`nparam()" -Local $localFn -Message 'U13c sem param() topo + molde zero-superficie -> quieto'

    # AVISA: reducao opcional / ValidateSet / promocao / extra obrigatorio
    Assert-Surface -Dir $D -Molde 'param([string]$A, [string]$B)' -Local 'param([string]$A)' -Adv @('optional_param_missing') -Message 'U03 opcional ausente -> advisory'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b','c')][string]`$Q)" -Local "param([ValidateSet('a','b')][string]`$Q)" -Adv @('validateset_reduced') -Message 'U04a ValidateSet reduzido (subconjunto) -> advisory'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b')][string]`$Q)" -Local "param([ValidateSet('a','c')][string]`$Q)" -Adv @('validateset_reduced') -Message 'U04b ValidateSet valor trocado (diferenca de conjunto) -> advisory'
    Assert-Surface -Dir $D -Molde "param([System.Management.Automation.ValidateSetAttribute('a','b')][string]`$Q)" -Local "param([ValidateSet('a')][string]`$Q)" -Adv @('validateset_reduced') -Message 'U15 ValidateSet por FQN e lido'
    Assert-Surface -Dir $D -Molde 'param([string]$Q)' -Local 'param([Parameter(Mandatory)][string]$Q)' -Adv @('optional_promoted_to_mandatory') -Message 'U11 opcional -> obrigatorio -> advisory'
    Assert-Surface -Dir $D -Molde 'param([string]$A)' -Local 'param([string]$A, [Parameter(Mandatory)][string]$Extra)' -Adv @('extra_mandatory_added') -Message 'U08 param extra obrigatorio -> advisory'
    Assert-Surface -Dir $D -Molde "[CmdletBinding()]`nparam()" -Local 'param([Parameter(Mandatory)][string]$Z)' -Adv @('extra_mandatory_added') -Message 'U09 molde zero-superficie + local obrigatorio -> advisory extra_mandatory_added'

    # QUIETO: excedente / a frente / delegacao legitima / nao-comparavel
    Assert-Surface -Dir $D -Molde 'param([string]$Root = "X")' -Local 'param([string]$Root = "Y")' -Message 'U02 fiel (so default diferente) -> quieto'
    Assert-Surface -Dir $D -Molde 'param([string]$A)' -Local 'param([string]$A, [string]$Extra)' -Message 'U07 param extra opcional -> quieto'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b')][string]`$Q)" -Local 'param([string]$Q)' -Message 'U05a ValidateSet removido no local -> quieto (delegacao)'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b')][string]`$Q)" -Local "param([ValidateSet('a','b','c')][string]`$Q)" -Message 'U05b ValidateSet local superset -> quieto'
    Assert-Surface -Dir $D -Molde "param([ValidateSet()][string]`$Q)" -Local "param([ValidateSet('a')][string]`$Q)" -Message 'U05c ValidateSet vazio no molde -> nao-comparavel -> quieto'
    Assert-Surface -Dir $D -Molde 'param([ValidateSet(1,2,3)][int]$Q)' -Local 'param([ValidateSet(1,2)][int]$Q)' -Message 'U05d ValidateSet non-string -> nao-comparavel -> quieto'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a',`$z)][string]`$Q)" -Local "param([ValidateSet('a')][string]`$Q)" -Message 'U05e ValidateSet misto (literal+var) -> nao-comparavel -> quieto'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b')][ValidateSet('b','c')][string]`$Q)" -Local "param([ValidateSet('a')][string]`$Q)" -Message 'U06 param com 2 [ValidateSet] (AND/intersecao) -> nao-comparavel -> quieto'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b',IgnoreCase=`$true)][string]`$Q)" -Local "param([ValidateSet('a','b')][string]`$Q)" -Message 'U17 ValidateSet arg nomeado ignorado -> compara so posicionais -> quieto'

    # Coexistencia: BLOQUEIO + AVISO no mesmo wrapper (achado por-wrapper, nao global)
    Assert-Surface -Dir $D -Molde "param([Parameter(Mandatory)][string]`$Query, [string]`$Opt, [ValidateSet('a','b','c')][string]`$Kind)" -Local "param([ValidateSet('a')][string]`$Kind)" -Block @('mandatory_param_missing') -Adv @('optional_param_missing', 'validateset_reduced') -Message 'U18 coexistencia bloqueio + avisos no mesmo wrapper'

    # Cantos OUT-OF-SCOPE (kimi): travar o comportamento CONHECIDO para pegar regressao
    Assert-Surface -Dir $D -Molde "param([Parameter(Mandatory)][string]`$Path)" -Local "param([Parameter(Mandatory)][Alias('Path')][string]`$Local)" -Block @('mandatory_param_missing') -Adv @('extra_mandatory_added') -Message 'OOS-a [Alias] renomeado -> bloqueio+aviso espurios (limitacao conhecida, sem suporte a alias)'
    Assert-Surface -Dir $D -Molde "param([ValidateSet('a','b')][string]`$Q)" -Local "param([ValidateSet('A','B',IgnoreCase=`$false)][string]`$Q)" -Message 'OOS-b IgnoreCase=$false divergente comparado como OrdinalIgnoreCase (limitacao conhecida) -> quieto'
    Assert-Surface -Dir $D -Molde 'param([string]$Q)' -Local "filter Bar { `$_ }" -Adv @('no_param_block') -Message 'OOS-c wrapper em forma de filter -> no_param_block (advisory por molde so-opcional)'

    # ============================================================================
    # END-TO-END pelo inventario: rotulos emitidos, coexistencia e advisory-so nao vira INVENTORY_OK
    # ============================================================================
    # E2E-1: bloqueio (rebaixado) + advisory (opcional ausente) no mesmo wrapper Query
    @'
#requires -Version 7.4
param(
    [Parameter(Mandatory = $true)]
    [string]$Query,
    [string]$Opt
)
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Query-KbIntelligence.example.ps1') -Encoding utf8NoBOM
    $queryStandardPath = Join-Path $scriptsPath 'Query-DemoKbIntelligence.ps1'
    @'
#requires -Version 7.4
param(
    [string]$Query
)
'@ | Set-Content -LiteralPath $queryStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'INVENTORY_CUSTOMIZED\b' -Message 'E2E-1 perda de obrigatorio deve entrar em INVENTORY_CUSTOMIZED'
    Assert-Contains -Text $output -Pattern 'Query-DemoKbIntelligence\.ps1\(reason=surface_mismatch: mandatory_downgraded -Query\)' -Message 'E2E-1 mandatory rebaixado emitido como surface_mismatch'
    Assert-Contains -Text $output -Pattern 'INVENTORY_SURFACE_ADVISORY:.*Query-DemoKbIntelligence\.ps1\(reason=optional_param_missing: -Opt\)' -Message 'E2E-1 opcional ausente emitido como INVENTORY_SURFACE_ADVISORY'
    Assert-NotContains -Text $output -Pattern '\bINVENTORY_OK\b' -Message 'E2E-1 wrapper com surface_mismatch nao pode retornar OK'

    # E2E-2: advisory-so (ValidateSet reduzido) -> INVENTORY_SURFACE_ADVISORY sem surface_mismatch, e sem INVENTORY_OK
    @'
#requires -Version 7.4
param(
    [ValidateSet('a', 'b', 'c')]
    [string]$Query
)
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Query-KbIntelligence.example.ps1') -Encoding utf8NoBOM
    @'
#requires -Version 7.4
param(
    [ValidateSet('a')]
    [string]$Query
)
'@ | Set-Content -LiteralPath $queryStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'INVENTORY_SURFACE_ADVISORY:.*Query-DemoKbIntelligence\.ps1\(reason=validateset_reduced: -Query \[b, c\]\)' -Message 'E2E-2 ValidateSet reduzido emitido como advisory com os valores faltantes'
    Assert-NotContains -Text $output -Pattern 'Query-DemoKbIntelligence\.ps1\(reason=surface_mismatch' -Message 'E2E-2 reducao de ValidateSet nao pode bloquear (nao e surface_mismatch)'
    Assert-NotContains -Text $output -Pattern '\bINVENTORY_OK\b' -Message 'E2E-2 advisory-so ainda nao e INVENTORY_OK (emite status part)'

    # E2E-3: overlap de check por-token (requires_version_mismatch) + surface_mismatch no mesmo wrapper
    @'
#requires -Version 7.4
param(
    [Parameter(Mandatory = $true)]
    [string]$Query
)
'@ | Set-Content -LiteralPath (Join-Path $examplesPath 'Query-KbIntelligence.example.ps1') -Encoding utf8NoBOM
    @'
#requires -version 5.1
param(
    [string]$Other
)
'@ | Set-Content -LiteralPath $queryStandardPath -Encoding utf8NoBOM

    $output = (& $inventoryScriptPath -KbParallelRoot $kbRoot -SkillsExamplesPath $examplesPath 2>&1 |
        ForEach-Object { $_.ToString() }) -join ' '

    Assert-Contains -Text $output -Pattern 'Query-DemoKbIntelligence\.ps1\(reason=requires_version_mismatch' -Message 'E2E-3 check por-token (requires) segue reportado'
    Assert-Contains -Text $output -Pattern 'Query-DemoKbIntelligence\.ps1\(reason=surface_mismatch: mandatory_param_missing -Query\)' -Message 'E2E-3 surface_mismatch coexiste com o check por-token (redundancia aceita)'

    # ============================================================================
    # GUARDA anti-regressao: o regex de pendencia do agregador (Test-XpzSetupAudit.ps1) casa
    # INVENTORY_CUSTOMIZED mas NAO os rotulos de aviso/diagnostico. Localizado POR CONTEUDO
    # (nao por numero de linha) para sobreviver a drift.
    # ============================================================================
    $auditPath = Join-Path $scriptDir 'Test-XpzSetupAudit.ps1'
    $auditLines = [System.IO.File]::ReadAllLines($auditPath)
    $regexLine = @($auditLines | Where-Object { $_ -match 'hasInventoryMethodologyPendencies\s*=' }) | Select-Object -First 1
    if (-not $regexLine) { throw 'ASSERT_FAILED: nao encontrei a linha de $hasInventoryMethodologyPendencies em Test-XpzSetupAudit.ps1' }
    $regexMatch = [regex]::Match($regexLine, "-match\s+'(?<pat>[^']*)'")
    if (-not $regexMatch.Success) { throw "ASSERT_FAILED: nao consegui extrair o regex literal da linha de pendencia | linha=$regexLine" }
    $blockRegex = $regexMatch.Groups['pat'].Value

    Assert-Contains -Text 'INVENTORY_CUSTOMIZED: X(reason=surface_mismatch: mandatory_param_missing -Query)' -Pattern $blockRegex -Message 'regex de pendencia DEVE casar INVENTORY_CUSTOMIZED (surface_mismatch bloqueia via CUSTOMIZED)'
    Assert-NotContains -Text 'INVENTORY_SURFACE_ADVISORY: X(reason=validateset_reduced: -Query [a, b])' -Pattern $blockRegex -Message 'REGRESSAO: regex de pendencia NAO pode casar INVENTORY_SURFACE_ADVISORY'
    Assert-NotContains -Text 'INVENTORY_ENGINE_DIAGNOSTIC: X(reason=engine_unresolved_or_unparseable: Y)' -Pattern $blockRegex -Message 'REGRESSAO: regex de pendencia NAO pode casar INVENTORY_ENGINE_DIAGNOSTIC'

    Write-Output 'WRAPPER_INVENTORY_SELFTEST_OK'
} finally {
    if ($tempRoot.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
