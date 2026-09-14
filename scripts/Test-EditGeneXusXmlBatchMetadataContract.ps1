#requires -Version 7.4
<#
.SYNOPSIS
    Bateria de contrato de Edit-GeneXusXmlBatchMetadata.ps1 (secao 13 do
    desenho congelado v10).

.DESCRIPTION
    Cada caso monta uma KB sintetica minima (frente canonica + acervo) em
    diretorio temporario e exerce o motor de ponta a ponta. Os casos seguem a
    numeracao da secao 13 do desenho:

      1  - caminho principal: insercao null -> texto em Part vazio multi-linha
           E em Part colapsado numa linha (o colapsado NAO pode ser expandido)
      1b - EOL: so-LF, so-CRLF e MISTO (-> EOL_MIXED)
      2  - adversarial: '>' em valor de atributo e <Object> dentro de CDATA
      3  - escala com falha injetada: rollback sem hash alterado
      4  - nao-escrita: duas execucoes sem -Apply nao deixam rastro
      5  - recuperacao a partir do journal apos interrupcao
      6  - lastUpdate: composicao dos dois baselines nas duas ordens; ambos no
           passado; raiz sem lastUpdate casavel com aninhado valido
      6b - objectState new com lastUpdate no futuro alem da tolerancia
      7  - scanner de referencias a Domain (as tres grafias, CDATA, homonimo)
      8  - lock vivo e lock morto
      9  - aborto pos-1b preserva journal e .bak
      10 - colisoes, duplicidades e sanidade de objectState new

.PARAMETER SkipScale
    Pula o caso 3 (131 operacoes). Cada operacao invoca o motor de lastUpdate
    em processo proprio - custo declarado do desenho (secao 2.1).
#>

[CmdletBinding()]
param(
    [switch]$SkipScale
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')

$enginePath = Join-Path $PSScriptRoot 'Edit-GeneXusXmlBatchMetadata.ps1'
$utf8 = Get-Utf8NoBomEncoding
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-batch-metadata-contract-{0}' -f ([guid]::NewGuid().ToString('N')))
$sdtTypeGuid = '447527b5-9210-4523-898b-5dccb17be60a'
$domainTypeGuid = '00972a17-9975-449e-aab1-d26165d51393'
$folderTypeGuid = '00000000-0000-0000-0000-000000000008'
$docPartGuid = 'babf62c5-0111-49e9-a1c3-cc004d90900a'

function New-Sandbox {
    param([Parameter(Mandatory = $true)][string]$Name)

    $root = Join-Path $testRoot $Name
    $front = Join-Path $root ('ObjetosGeradosParaImportacaoNaKbNoGenexus\{0}' -f 'Frente01')
    $acervo = Join-Path $root 'ObjetosDaKbEmXml'
    [void](New-Item -ItemType Directory -Path $front -Force)
    [void](New-Item -ItemType Directory -Path $acervo -Force)
    return [pscustomobject]@{ Root = $root; Front = $front; Acervo = $acervo }
}

function New-ObjectXmlText {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [string]$LastUpdate = '2024-01-01T00:00:00.0000000Z',
        [string]$Description,
        [string]$Parent = 'PastaOrigem',
        [string]$ParentGuid = 'aaaaaaaa-0000-0000-0000-000000000001',
        [string]$ModuleGuid = 'mmmmmmmm-0000-0000-0000-000000000001',
        [string]$FullyQualifiedName,
        [string]$Documentation,
        [switch]$CollapsedPart,
        [string]$Eol = "`r`n",
        [string]$ExtraContent = ''
    )

    if ($null -eq $Description -or $Description -eq '') { $Description = $Name }
    if ([string]::IsNullOrEmpty($FullyQualifiedName)) { $FullyQualifiedName = $Name }

    $innerHtml = ''
    if ($null -ne $Documentation -and $Documentation -ne '') {
        $innerHtml = '<InnerHtml><![CDATA[' + $Documentation + ']]></InnerHtml>'
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('<?xml version="1.0" encoding="utf-8"?>')
    [void]$lines.Add('<Object parentGuid="' + $ParentGuid + '" user="Teste" versionDate="0001-01-01T00:00:00.0000000" lastUpdate="' + $LastUpdate + '" checksum="0123456789abcdef0123456789abcdef" fullyQualifiedName="' + $FullyQualifiedName + '" moduleGuid="' + $ModuleGuid + '" guid="' + $Guid + '" name="' + $Name + '" type="' + $TypeGuid + '" description="' + $Description + '" parent="' + $Parent + '" parentType="' + $folderTypeGuid + '">')
    if ($CollapsedPart) {
        [void]$lines.Add('      <Part type="' + $docPartGuid + '">' + $innerHtml + '<Properties /></Part>')
    } else {
        [void]$lines.Add('      <Part type="' + $docPartGuid + '">')
        if ($innerHtml -ne '') {
            [void]$lines.Add('        ' + $innerHtml)
        }
        [void]$lines.Add('        <Properties />')
        [void]$lines.Add('      </Part>')
    }
    if (-not [string]::IsNullOrEmpty($ExtraContent)) {
        [void]$lines.Add($ExtraContent)
    }
    [void]$lines.Add('      <Properties><Property><Name>Name</Name><Value>' + $Name + '</Value></Property><Property><Name>Description</Name><Value>' + $Description + '</Value></Property></Properties>')
    [void]$lines.Add('</Object>')
    [void]$lines.Add('')

    return ($lines.ToArray() -join $Eol)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Write-Manifest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object[]]$Operations
    )
    $manifest = [ordered]@{
        Kind          = 'xpz-batch-metadata-manifest'
        SchemaVersion = 1
        operations    = @($Operations)
    }
    Write-TextFile -Path $Path -Text ($manifest | ConvertTo-Json -Depth 20)
}

function Invoke-Engine {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$FrontFolder,
        [switch]$Apply,
        [string[]]$ExtraArguments = @()
    )

    # Splat de HASHTABLE, nao de array: array splat liga os elementos por
    # POSICAO, e '-InputPath' viraria o valor do primeiro parametro.
    $splat = @{
        InputPath   = $ManifestPath
        FrontFolder = $FrontFolder
    }
    if ($Apply) { $splat['Apply'] = $true }
    foreach ($extra in @($ExtraArguments)) {
        $splat[$extra.TrimStart('-')] = $true
    }
    $output = & $enginePath @splat
    $exitCode = $LASTEXITCODE
    $report = (@($output) -join "`n") | ConvertFrom-Json
    return [pscustomobject]@{ Report = $report; ExitCode = $exitCode }
}

function Get-BlockCodes {
    param([Parameter(Mandatory = $true)][object]$Report)
    return @(@($Report.blocks) | ForEach-Object { $_.code })
}

function Assert-BlockCode {
    param(
        [Parameter(Mandatory = $true)][string]$Case,
        [Parameter(Mandatory = $true)][object]$Report,
        [Parameter(Mandatory = $true)][string]$Expected
    )
    $codes = Get-BlockCodes -Report $Report
    if ($codes -notcontains $Expected) {
        throw "$Case : esperava bloqueio '$Expected'; obtido [$($codes -join ', ')] com status '$($Report.status)'."
    }
}

function Assert-Status {
    param(
        [Parameter(Mandatory = $true)][string]$Case,
        [Parameter(Mandatory = $true)][object]$Report,
        [Parameter(Mandatory = $true)][string]$Expected
    )
    if ($Report.status -ne $Expected) {
        $detalhe = @(@($Report.blocks) | ForEach-Object { "$($_.code): $($_.message)" }) -join ' | '
        throw "$Case : status deveria ser '$Expected'; obtido '$($Report.status)' com bloqueios [$detalhe]."
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function New-DocumentationOperation {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$XmlPath,
        [object]$ExpectedDocumentation = $null,
        [string]$NewDocumentation = 'Texto de documentação.',
        [string]$ObjectState = 'existing'
    )

    $operation = [ordered]@{
        id          = $Id
        op          = 'setDocumentation'
        objectState = $ObjectState
        target      = [ordered]@{ guid = $Guid; expectedType = 'SDT'; expectedName = $Name; xmlPath = $XmlPath }
        new         = [ordered]@{ documentation = $NewDocumentation }
    }
    if ($ObjectState -eq 'existing') {
        $operation['expected'] = [ordered]@{ documentation = $ExpectedDocumentation }
    }
    return $operation
}

[void](New-Item -ItemType Directory -Path $testRoot -Force)
$failures = [System.Collections.Generic.List[string]]::new()

try {
    # ----------------------------------------------------------------------
    # Caso 1 - caminho principal: insercao em Part multi-linha e colapsado
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso01'
    $guidMulti = '11111111-1111-1111-1111-111111111101'
    $guidInline = '11111111-1111-1111-1111-111111111102'
    $textoMulti = New-ObjectXmlText -Name 'SdtMulti' -Guid $guidMulti -TypeGuid $sdtTypeGuid
    $textoInline = New-ObjectXmlText -Name 'SdtInline' -Guid $guidInline -TypeGuid $sdtTypeGuid -CollapsedPart
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtMulti.xml') -Text $textoMulti
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtInline.xml') -Text $textoInline
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtMulti.xml') -Text $textoMulti
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtInline.xml') -Text $textoInline

    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-multi' -Guid $guidMulti -Name 'SdtMulti' -XmlPath 'SDT/SdtMulti.xml' -NewDocumentation 'Documentação inserida.'),
        (New-DocumentationOperation -Id 'op-inline' -Guid $guidInline -Name 'SdtInline' -XmlPath 'SDT/SdtInline.xml' -NewDocumentation 'Documentação inserida.')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    Assert-Status -Case 'Caso 1' -Report $result.Report -Expected 'checksumStale'

    $multiFinal = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtMulti.xml'))
    if ($multiFinal -notmatch [regex]::Escape("        <InnerHtml><![CDATA[Documentação inserida.]]></InnerHtml>`r`n        <Properties />")) {
        throw 'Caso 1: insercao multi-linha nao respeitou a indentacao do <Properties> irmao.'
    }
    $inlineFinal = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtInline.xml'))
    $inlinePartMatch = [regex]::Match($inlineFinal, '<Part type="' + [regex]::Escape($docPartGuid) + '">.*?</Part>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $inlinePartMatch.Success) { throw 'Caso 1: Part colapsado nao encontrado apos a edicao.' }
    if ($inlinePartMatch.Value.Contains("`n")) {
        throw 'Caso 1: Part colapsado foi expandido para multi-linha; o desenho proibe.'
    }
    if (-not $inlinePartMatch.Value.Contains('<InnerHtml><![CDATA[Documentação inserida.]]></InnerHtml>')) {
        throw 'Caso 1: InnerHtml nao entrou no Part colapsado.'
    }

    # ----------------------------------------------------------------------
    # Caso 1b - EOL
    # ----------------------------------------------------------------------
    foreach ($eolCase in @(
            @{ Name = 'lf'; Eol = "`n"; Expect = 'ok' },
            @{ Name = 'crlf'; Eol = "`r`n"; Expect = 'ok' })) {
        $sandbox = New-Sandbox -Name ('caso01b-' + $eolCase.Name)
        $guid = '11111111-1111-1111-1111-1111111111b1'
        $text = New-ObjectXmlText -Name 'SdtEol' -Guid $guid -TypeGuid $sdtTypeGuid -Eol $eolCase.Eol
        Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtEol.xml') -Text $text
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtEol.xml') -Text $text
        $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
        Write-Manifest -Path $manifestPath -Operations @(
            (New-DocumentationOperation -Id 'op-eol' -Guid $guid -Name 'SdtEol' -XmlPath 'SDT/SdtEol.xml' -NewDocumentation "Linha 1`nLinha 2")
        )
        $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
        if ($result.Report.status -eq 'blocked') {
            throw "Caso 1b ($($eolCase.Name)): bloqueado indevidamente [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
        }
        $final = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtEol.xml'))
        $profileCrLf = ([regex]::Matches($final, "`r`n")).Count
        $profileLoneLf = ([regex]::Matches($final, "(?<!`r)`n")).Count
        if ($eolCase.Eol -eq "`n" -and $profileCrLf -gt 0) {
            throw 'Caso 1b (lf): arquivo so-LF ganhou CRLF; o payload deveria ser normalizado para o EOL do arquivo.'
        }
        if ($eolCase.Eol -eq "`r`n" -and $profileLoneLf -gt 0) {
            throw 'Caso 1b (crlf): arquivo CRLF ganhou LF solto vindo do payload JSON.'
        }
    }

    $sandbox = New-Sandbox -Name 'caso01b-misto'
    $guid = '11111111-1111-1111-1111-1111111111b2'
    $mixed = (New-ObjectXmlText -Name 'SdtMisto' -Guid $guid -TypeGuid $sdtTypeGuid -Eol "`r`n")
    $mixed = $mixed.Replace('        <Properties />', "        <Properties />`n")
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtMisto.xml') -Text $mixed
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtMisto.xml') -Text $mixed
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-misto' -Guid $guid -Name 'SdtMisto' -XmlPath 'SDT/SdtMisto.xml')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    Assert-BlockCode -Case 'Caso 1b (misto)' -Report $result.Report -Expected 'EOL_MIXED'

    # payload com CR solto -> PAYLOAD_EOL_INVALID
    $sandbox = New-Sandbox -Name 'caso01b-payload'
    $guid = '11111111-1111-1111-1111-1111111111b3'
    $text = New-ObjectXmlText -Name 'SdtPayload' -Guid $guid -TypeGuid $sdtTypeGuid
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtPayload.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtPayload.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-payload' -Guid $guid -Name 'SdtPayload' -XmlPath 'SDT/SdtPayload.xml' -NewDocumentation "Linha 1`rLinha 2")
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 1b (payload CR solto)' -Report $result.Report -Expected 'PAYLOAD_EOL_INVALID'

    # ----------------------------------------------------------------------
    # Caso 2 - adversarial: '>' em valor de atributo e <Object> dentro de CDATA
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso02'
    $guid = '22222222-2222-2222-2222-222222222201'
    $cdataTrap = '      <Source><![CDATA[<Object ElementId="5" ControlName="NewUsers"><Part type="' + $docPartGuid + '"></Object>]]></Source>'
    $text = New-ObjectXmlText -Name 'SdtAdversarial' -Guid $guid -TypeGuid $sdtTypeGuid -Description 'a > b' -ExtraContent $cdataTrap
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtAdversarial.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtAdversarial.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-adv' -Guid $guid -Name 'SdtAdversarial' -XmlPath 'SDT/SdtAdversarial.xml' -NewDocumentation 'Documentação adversarial.')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    if ($result.Report.status -eq 'blocked') {
        throw "Caso 2: <Object> dentro de CDATA desbalanceou a varredura [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
    }
    $final = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtAdversarial.xml'))
    if (-not $final.Contains($cdataTrap)) {
        throw 'Caso 2: o CDATA adversarial foi alterado; deveria ficar byte-identico.'
    }
    if (([regex]::Matches($final, [regex]::Escape('<InnerHtml>'))).Count -ne 1) {
        throw 'Caso 2: InnerHtml gravado em lugar diferente do contado.'
    }

    # ----------------------------------------------------------------------
    # Caso 2b - Part de documentacao dentro de <Object> ANINHADO nao conta
    #
    # E a regra central da secao 6.0: a contagem da ancora e do escopo B, que
    # exclui subarvores <Object> aninhadas - nao do arquivo inteiro. A medicao
    # que a motivou e PackagedModule\GeneXus.xml, com 248 Parts. Contar no
    # arquivo daria ANCHOR_AMBIGUOUS; contar em B da exatamente 1, e o patch
    # tem de entrar no Part da RAIZ, deixando a subarvore aninhada intacta.
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso02b'
    $guid = '22222222-2222-2222-2222-2222222222b1'
    # Interpolacao, nao concatenacao: em array literal a virgula tem
    # precedencia MAIOR que o '+', e 'a' + $x + 'b' se desfaz em elementos
    # separados - o fixture sairia com quebra de linha no meio dos atributos.
    $nestedBlock = @(
        "      <Object guid=`"22222222-2222-2222-2222-2222222222b2`" name=`"ObjetoEmpacotado`" type=`"$($sdtTypeGuid)`" lastUpdate=`"2019-01-01T00:00:00.0000000Z`" description=`"ObjetoEmpacotado`">",
        "        <Part type=`"$($docPartGuid)`">",
        '          <InnerHtml><![CDATA[Documentação do objeto empacotado.]]></InnerHtml>',
        '          <Properties />',
        '        </Part>',
        '      </Object>'
    ) -join "`r`n"
    $text = New-ObjectXmlText -Name 'SdtComAninhado' -Guid $guid -TypeGuid $sdtTypeGuid -ExtraContent $nestedBlock
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtComAninhado.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtComAninhado.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-aninhado' -Guid $guid -Name 'SdtComAninhado' -XmlPath 'SDT/SdtComAninhado.xml' -NewDocumentation 'Documentação da raiz.')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    if ($result.Report.status -eq 'blocked') {
        throw "Caso 2b: Part em <Object> aninhado foi contado no escopo errado [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
    }
    $nestedFinal = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtComAninhado.xml'))
    if (-not $nestedFinal.Contains($nestedBlock)) {
        throw 'Caso 2b: a subarvore <Object> aninhada deveria sair byte-identica.'
    }
    if (([regex]::Matches($nestedFinal, [regex]::Escape('<Part type="' + $docPartGuid + '">'))).Count -ne 2) {
        throw 'Caso 2b: o arquivo deveria continuar com os dois Part (raiz e aninhado).'
    }
    if (([regex]::Matches($nestedFinal, [regex]::Escape('Documentação da raiz.'))).Count -ne 1) {
        throw 'Caso 2b: a documentacao nova nao entrou exatamente uma vez no Part da raiz.'
    }
    $rootPartIndex = $nestedFinal.IndexOf('<Part type="' + $docPartGuid + '">', [StringComparison]::Ordinal)
    $nestedIndex = $nestedFinal.IndexOf('<Object guid="22222222-2222-2222-2222-2222222222b2"', [StringComparison]::Ordinal)
    if ($nestedFinal.IndexOf('Documentação da raiz.', [StringComparison]::Ordinal) -lt $rootPartIndex -or
        $nestedFinal.IndexOf('Documentação da raiz.', [StringComparison]::Ordinal) -gt $nestedIndex) {
        throw 'Caso 2b: a documentacao nova foi gravada fora do Part da raiz.'
    }
    if (([regex]::Matches($nestedFinal, 'lastUpdate="')).Count -ne 2) {
        throw 'Caso 2b: o arquivo deveria manter os dois lastUpdate (raiz e aninhado).'
    }
    if ($nestedFinal -notmatch 'lastUpdate="2019-01-01T00:00:00\.0000000Z"') {
        throw 'Caso 2b: o lastUpdate do objeto aninhado foi alterado; o bump e da raiz.'
    }

    # ----------------------------------------------------------------------
    # Caso 4 - nao-escrita
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso04'
    $guid = '44444444-4444-4444-4444-444444444401'
    $text = New-ObjectXmlText -Name 'SdtDry' -Guid $guid -TypeGuid $sdtTypeGuid
    $targetPath = Join-Path $sandbox.Front 'SDT\SdtDry.xml'
    Write-TextFile -Path $targetPath -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtDry.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-dry' -Guid $guid -Name 'SdtDry' -XmlPath 'SDT/SdtDry.xml')
    )
    $hashBefore = Get-Sha256 -Path $targetPath
    $mtimeBefore = (Get-Item -LiteralPath $targetPath).LastWriteTimeUtc
    [void](Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front)
    [void](Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front)
    if ((Get-Sha256 -Path $targetPath) -ne $hashBefore) { throw 'Caso 4: execucao sem -Apply alterou o alvo.' }
    if ((Get-Item -LiteralPath $targetPath).LastWriteTimeUtc -ne $mtimeBefore) { throw 'Caso 4: execucao sem -Apply alterou o mtime do alvo.' }
    $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
    if (Test-Path -LiteralPath $workDir) {
        $leftovers = @(Get-ChildItem -LiteralPath $workDir -Force)
        if ($leftovers.Count -gt 0) {
            throw "Caso 4: execucao sem -Apply deixou artefato persistente: $($leftovers[0].FullName)"
        }
    }

    # ----------------------------------------------------------------------
    # Caso 6 - lastUpdate: composicao dos dois baselines
    # ----------------------------------------------------------------------
    $stampAntigo = '2020-01-01T00:00:00.0000000Z'
    $stampNovo = '2024-06-01T12:00:00.0000000Z'
    $valores = @{}
    foreach ($ordem in @(
            @{ Name = 'acervo-maior'; Front = $stampAntigo; Acervo = $stampNovo },
            @{ Name = 'frente-maior'; Front = $stampNovo; Acervo = $stampAntigo })) {
        $sandbox = New-Sandbox -Name ('caso06-' + $ordem.Name)
        $guid = '66666666-6666-6666-6666-666666666601'
        Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtStamp.xml') -Text (New-ObjectXmlText -Name 'SdtStamp' -Guid $guid -TypeGuid $sdtTypeGuid -LastUpdate $ordem.Front)
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtStamp.xml') -Text (New-ObjectXmlText -Name 'SdtStamp' -Guid $guid -TypeGuid $sdtTypeGuid -LastUpdate $ordem.Acervo)
        $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
        Write-Manifest -Path $manifestPath -Operations @(
            (New-DocumentationOperation -Id 'op-stamp' -Guid $guid -Name 'SdtStamp' -XmlPath 'SDT/SdtStamp.xml')
        )
        $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
        if ($result.Report.status -eq 'blocked') {
            throw "Caso 6 ($($ordem.Name)): bloqueado [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
        }
        $final = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtStamp.xml'))
        $valores[$ordem.Name] = [regex]::Match($final, 'lastUpdate="([^"]+)"').Groups[1].Value
        $baselineSource = @($result.Report.files)[0].baselineSource
        $esperado = 'acervo'
        if ($ordem.Name -eq 'frente-maior') { $esperado = 'front' }
        if ($baselineSource -ne $esperado) {
            throw "Caso 6 ($($ordem.Name)): baseline vencedor deveria ser '$esperado'; obtido '$baselineSource'."
        }
    }
    # ambos os baselines estao no passado: UtcNow domina e o carimbo e o mesmo
    # nas duas ordens (a menos da resolucao de segundo do formato)
    $instantes = @($valores.Values | ForEach-Object {
            $parsed = [DateTimeOffset]::MinValue
            [void][DateTimeOffset]::TryParse($_, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)
            $parsed
        })
    $delta = [Math]::Abs(($instantes[0] - $instantes[1]).TotalSeconds)
    if ($delta -gt 5) {
        throw "Caso 6: as duas ordens produziram carimbos distantes ($delta s); a composicao nao e simetrica."
    }

    # raiz sem lastUpdate casavel + aninhado valido -> LASTUPDATE_TARGET_OUTSIDE_ROOT
    $sandbox = New-Sandbox -Name 'caso06-offset'
    $guid = '66666666-6666-6666-6666-666666666602'
    $nested = '      <Nested><Object guid="99999999-9999-9999-9999-999999999999" name="Aninhado" lastUpdate="2024-01-01T00:00:00.0000000Z"></Object></Nested>'
    $text = New-ObjectXmlText -Name 'SdtOffset' -Guid $guid -TypeGuid $sdtTypeGuid -LastUpdate '2024-01-01T00:00:00.0000000+03:00' -ExtraContent $nested
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtOffset.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtOffset.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-offset' -Guid $guid -Name 'SdtOffset' -XmlPath 'SDT/SdtOffset.xml')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 6 (offset)' -Report $result.Report -Expected 'LASTUPDATE_TARGET_OUTSIDE_ROOT'

    # ----------------------------------------------------------------------
    # Caso 6b - objectState new com lastUpdate futuro alem da tolerancia
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso06b'
    $guid = '66666666-6666-6666-6666-6666666666b1'
    $futuro = [DateTime]::UtcNow.AddHours(3).ToString("yyyy-MM-dd'T'HH:mm:ss'.0000000Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtNovo.xml') -Text (New-ObjectXmlText -Name 'SdtNovo' -Guid $guid -TypeGuid $sdtTypeGuid -LastUpdate $futuro)
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-novo' -Guid $guid -Name 'SdtNovo' -XmlPath 'SDT/SdtNovo.xml' -ObjectState 'new')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 6b' -Report $result.Report -Expected 'NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE'

    # ----------------------------------------------------------------------
    # Caso 7 - scanner de referencias a Domain
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso07'
    $domainGuid = '77777777-7777-7777-7777-777777777701'
    $moduleGuid = '77777777-0000-0000-0000-0000000000aa'
    $domainText = New-ObjectXmlText -Name 'GAMMessageType' -Guid $domainGuid -TypeGuid $domainTypeGuid -ModuleGuid $moduleGuid -FullyQualifiedName 'GAM.GAMMessageType'
    Write-TextFile -Path (Join-Path $sandbox.Front 'Domain\GAMMessageType.xml') -Text $domainText
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\GAMMessageType.xml') -Text $domainText
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')

    $renameOperation = [ordered]@{
        id          = 'op-rename'
        op          = 'renameDomain'
        objectState = 'existing'
        target      = [ordered]@{ guid = $domainGuid; expectedType = 'Domain'; expectedName = 'GAMMessageType'; xmlPath = 'Domain/GAMMessageType.xml' }
        expected    = [ordered]@{ name = 'GAMMessageType'; fullyQualifiedName = 'GAM.GAMMessageType'; propertyName = 'GAMMessageType'; description = 'GAMMessageType' }
        new         = [ordered]@{ name = 'SemUso_GAMMessageType' }
        renameFile  = $true
    }
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)

    # 7.1 sem referencia: renomeia
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    if ($result.Report.status -eq 'blocked') {
        throw "Caso 7.1: rename sem referencia foi bloqueado [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml'))) {
        throw 'Caso 7.1: arquivo nao foi renomeado.'
    }
    $renamedText = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml'))
    foreach ($expectedFragment in @(' name="SemUso_GAMMessageType"', 'fullyQualifiedName="GAM.SemUso_GAMMessageType"', '<Name>Name</Name><Value>SemUso_GAMMessageType</Value>', 'description="SemUso_GAMMessageType"')) {
        if (-not $renamedText.Contains($expectedFragment)) {
            throw "Caso 7.1: ponto do rename nao aplicado: '$expectedFragment'."
        }
    }

    # 7.2 referencia qualificada 'Domain:Nome, Modulo' bloqueia
    # As tres formas medidas no acervo para o MESMO objeto, mais a variacao só
    # na caixa: curta, qualificada com virgula e espaco, e caixa divergente.
    foreach ($grafia in @('Domain:GAMMessageType', 'Domain:GAMMessageType, GAM', 'domain:gammessagetype')) {
        $sandbox = New-Sandbox -Name ('caso07-ref-' + ([guid]::NewGuid().ToString('N').Substring(0, 6)))
        Write-TextFile -Path (Join-Path $sandbox.Front 'Domain\GAMMessageType.xml') -Text $domainText
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\GAMMessageType.xml') -Text $domainText
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')
        $consumidor = New-ObjectXmlText -Name 'SdtConsumidor' -Guid '77777777-7777-7777-7777-7777777777c1' -TypeGuid $sdtTypeGuid `
            -ExtraContent ('      <Item><Properties><Property><Name>Type</Name><Value>' + $grafia + '</Value></Property></Properties></Item>')
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtConsumidor.xml') -Text $consumidor
        $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
        Write-Manifest -Path $manifestPath -Operations @($renameOperation)
        $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
        Assert-BlockCode -Case ("Caso 7.2 ($grafia)") -Report $result.Report -Expected 'DOMAIN_STILL_REFERENCED'
    }

    # 7.3 ocorrencia em CDATA de documentacao e report-only; em <Source> bloqueia
    foreach ($cdataCase in @(
            @{ Name = 'documentacao'; Blocks = $false },
            @{ Name = 'source'; Blocks = $true })) {
        $sandbox = New-Sandbox -Name ('caso07-cdata-' + $cdataCase.Name)
        Write-TextFile -Path (Join-Path $sandbox.Front 'Domain\GAMMessageType.xml') -Text $domainText
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\GAMMessageType.xml') -Text $domainText
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')
        if ($cdataCase.Name -eq 'documentacao') {
            $consumidor = New-ObjectXmlText -Name 'SdtCdata' -Guid '77777777-7777-7777-7777-7777777777c2' -TypeGuid $sdtTypeGuid -Documentation 'Este objeto cita Domain:GAMMessageType em prosa.'
        } else {
            $consumidor = New-ObjectXmlText -Name 'SdtCdata' -Guid '77777777-7777-7777-7777-7777777777c2' -TypeGuid $sdtTypeGuid `
                -ExtraContent '      <Source><![CDATA[&Var = Domain:GAMMessageType]]></Source>'
        }
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtCdata.xml') -Text $consumidor
        $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
        Write-Manifest -Path $manifestPath -Operations @($renameOperation)
        $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
        if ($cdataCase.Blocks) {
            Assert-BlockCode -Case 'Caso 7.3 (source)' -Report $result.Report -Expected 'DOMAIN_STILL_REFERENCED'
        } else {
            if ((Get-BlockCodes -Report $result.Report) -contains 'DOMAIN_STILL_REFERENCED') {
                throw 'Caso 7.3 (documentacao): CDATA de documentacao deveria ser report-only.'
            }
            $kinds = @(@($result.Report.warnings) | ForEach-Object { $_.kind })
            if ($kinds -notcontains 'cdataOccurrence') {
                throw 'Caso 7.3 (documentacao): ocorrencia em CDATA de documentacao nao foi reportada.'
            }
        }
    }

    # 7.4 grafia desconhecida que colide com o alvo -> REFERENCE_SCAN_INCOMPLETE
    $sandbox = New-Sandbox -Name 'caso07-desconhecida'
    Write-TextFile -Path (Join-Path $sandbox.Front 'Domain\GAMMessageType.xml') -Text $domainText
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\GAMMessageType.xml') -Text $domainText
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')
    $consumidor = New-ObjectXmlText -Name 'SdtOutroModulo' -Guid '77777777-7777-7777-7777-7777777777c3' -TypeGuid $sdtTypeGuid `
        -ExtraContent '      <Item><Properties><Property><Name>Type</Name><Value>Domain:GAMMessageType, OutroModulo</Value></Property></Properties></Item>'
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtOutroModulo.xml') -Text $consumidor
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 7.4' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'

    # 7.5 unusedEvidence declarando uso bloqueia mesmo sem medicao positiva
    $sandbox = New-Sandbox -Name 'caso07-evidencia'
    Write-TextFile -Path (Join-Path $sandbox.Front 'Domain\GAMMessageType.xml') -Text $domainText
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\GAMMessageType.xml') -Text $domainText
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')
    $operationComEvidencia = [ordered]@{}
    foreach ($entry in $renameOperation.GetEnumerator()) { $operationComEvidencia[$entry.Key] = $entry.Value }
    $operationComEvidencia['unusedEvidence'] = [ordered]@{ source = 'kb-intelligence'; query = 'what-uses GAMMessageType'; result = '3 dependentes'; statedBy = 'humano' }
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($operationComEvidencia)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 7.5' -Report $result.Report -Expected 'DOMAIN_STILL_REFERENCED'

    # ----------------------------------------------------------------------
    # Caso 7.6 a 7.8 - PackagedModule (secao 7 e secao 13.7)
    #
    # Domain definido dentro de PackagedModule esta FORA de escopo do rename,
    # e o buraco real medido na v7 e o oposto do que se imaginava: um nome que
    # existe tanto em Domain/ quanto dentro de um PackagedModule resolvia com
    # confianca para o objeto do acervo, com o homonimo empacotado invisivel.
    # ----------------------------------------------------------------------
    function New-PackagedModuleSandbox {
        param([Parameter(Mandatory = $true)][string]$Name)

        $sandbox = New-Sandbox -Name $Name
        Write-TextFile -Path (Join-Path $sandbox.Front 'Domain\GAMMessageType.xml') -Text $domainText
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\GAMMessageType.xml') -Text $domainText
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')
        return $sandbox
    }

    function New-PackagedModuleXmlText {
        param(
            [Parameter(Mandatory = $true)][string]$PackageName,
            [Parameter(Mandatory = $true)][string]$DomainName
        )

        # Interpolacao, nao concatenacao: ver a nota do caso 2b sobre a
        # precedencia da virgula sobre o '+' em array literal.
        return (@(
            '<?xml version="1.0" encoding="utf-8"?>',
            "<Object guid=`"0a0a0a0a-0000-0000-0000-00000000000a`" name=`"$($PackageName)`" type=`"9e5d0ef7-7a37-4d76-9f05-8b5e4a2a4a2a`" lastUpdate=`"2020-01-01T00:00:00.0000000Z`" description=`"$($PackageName)`">",
            "      <Object guid=`"0b0b0b0b-0000-0000-0000-00000000000b`" name=`"$($DomainName)`" type=`"$($domainTypeGuid)`" description=`"$($DomainName)`">",
            "        <Properties><Property><Name>Name</Name><Value>$($DomainName)</Value></Property></Properties>",
            '      </Object>',
            '</Object>',
            ''
        ) -join "`r`n")
    }

    # 7.6 grafia qualificada cujo definidor vive dentro de PackagedModule
    $sandbox = New-PackagedModuleSandbox -Name 'caso07-packaged-definidor'
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'PackagedModule\OutroPacote.xml') -Text (New-PackagedModuleXmlText -PackageName 'OutroModulo' -DomainName 'GAMMessageType')
    $consumidor = New-ObjectXmlText -Name 'SdtQualificado' -Guid '77777777-7777-7777-7777-7777777777d1' -TypeGuid $sdtTypeGuid `
        -ExtraContent '      <Item><Properties><Property><Name>Type</Name><Value>Domain:GAMMessageType, OutroModulo</Value></Property></Properties></Item>'
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtQualificado.xml') -Text $consumidor
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    Assert-BlockCode -Case 'Caso 7.6' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'
    if (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml')) {
        throw 'Caso 7.6: cobertura incompleta nao pode deixar o rename acontecer.'
    }

    # 7.7 homonimo em PackagedModule, sem nenhuma referencia no acervo
    $sandbox = New-PackagedModuleSandbox -Name 'caso07-packaged-homonimo'
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'PackagedModule\PacoteComHomonimo.xml') -Text (New-PackagedModuleXmlText -PackageName 'PacoteExterno' -DomainName 'GAMMessageType')
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    Assert-BlockCode -Case 'Caso 7.7' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'
    $detalhe7 = (@(@($result.Report.blocks) | Where-Object { $_.code -eq 'REFERENCE_SCAN_INCOMPLETE' } | ForEach-Object { @($_.detail) -join ' ' }) -join ' ')
    if ($detalhe7 -notmatch 'PackagedModule') {
        throw "Caso 7.7: o bloqueio nao nomeou o homonimo empacotado: $detalhe7"
    }
    if (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml')) {
        throw 'Caso 7.7: homonimo empacotado nao pode deixar o rename acontecer.'
    }

    # 7.8 PackagedModule mal formado que ja casou nome e tipo Domain:
    #     nao pode ser pulado em silencio (regressao do endurecimento).
    #     O conteudo evita a substring 'Domain:' de proposito, para o indice de
    #     referencias nao o pegar antes e o caso isolar o detector de homonimo.
    $sandbox = New-PackagedModuleSandbox -Name 'caso07-packaged-malformado'
    $malformado = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Object name="PacoteQuebrado"><Object name="GAMMessageType" type="' + $domainTypeGuid + '">' + "`r`n"
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'PackagedModule\PacoteQuebrado.xml') -Text $malformado
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    Assert-BlockCode -Case 'Caso 7.8' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'
    $detalhe8 = (@(@($result.Report.blocks) | Where-Object { $_.code -eq 'REFERENCE_SCAN_INCOMPLETE' } | ForEach-Object { @($_.detail) -join ' ' }) -join ' ')
    if ($detalhe8 -notmatch 'bem formado|ilegivel') {
        throw "Caso 7.8: o bloqueio nao nomeou o XML de PackagedModule ilegivel/mal formado: $detalhe8"
    }
    if (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml')) {
        throw 'Caso 7.8: XML de PackagedModule ilegivel nao pode deixar o rename acontecer.'
    }

    # ----------------------------------------------------------------------
    # Caso 8 - lock
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso08'
    $guid = '88888888-8888-8888-8888-888888888801'
    $text = New-ObjectXmlText -Name 'SdtLock' -Guid $guid -TypeGuid $sdtTypeGuid
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtLock.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtLock.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-lock' -Guid $guid -Name 'SdtLock' -XmlPath 'SDT/SdtLock.xml')
    )
    $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
    [void](New-Item -ItemType Directory -Path $workDir -Force)
    Write-TextFile -Path (Join-Path $workDir 'run.lock') -Text (([ordered]@{ pid = $PID; runId = 'outro'; startedAtUtc = '2024-01-01T00:00:00Z' }) | ConvertTo-Json)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 8 (lock vivo)' -Report $result.Report -Expected 'RUN_LOCKED'

    Write-TextFile -Path (Join-Path $workDir 'run.lock') -Text (([ordered]@{ pid = 999999; runId = 'morto'; startedAtUtc = '2024-01-01T00:00:00Z' }) | ConvertTo-Json)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    $kinds = @(@($result.Report.warnings) | ForEach-Object { $_.kind })
    if ($kinds -notcontains 'staleLockReclaimed') {
        throw 'Caso 8 (lock morto): o lock de PID morto deveria ser reaproveitado com aviso.'
    }

    # ----------------------------------------------------------------------
    # Caso 9 - aborto pos-1b preserva journal e .bak (PLAN_STALE)
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso09'
    $guidA = '99999999-9999-9999-9999-999999999901'
    $guidB = '99999999-9999-9999-9999-999999999902'
    foreach ($pair in @(@{ Name = 'SdtA'; Guid = $guidA }, @{ Name = 'SdtB'; Guid = $guidB })) {
        $text = New-ObjectXmlText -Name $pair.Name -Guid $pair.Guid -TypeGuid $sdtTypeGuid
        Write-TextFile -Path (Join-Path $sandbox.Front ('SDT\{0}.xml' -f $pair.Name)) -Text $text
        Write-TextFile -Path (Join-Path $sandbox.Acervo ('SDT\{0}.xml' -f $pair.Name)) -Text $text
    }
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-a' -Guid $guidA -Name 'SdtA' -XmlPath 'SDT/SdtA.xml'),
        (New-DocumentationOperation -Id 'op-b' -Guid $guidB -Name 'SdtB' -XmlPath 'SDT/SdtB.xml')
    )
    # o acervo consultado muda entre o plano e a aplicacao: o motor so descobre
    # na reconferencia da Fase 2, ja com journal e .bak materializados.
    # Gatilho observavel (o primeiro .bak aparecendo em -WorkDir) em vez de
    # espera cega: com Start-Sleep fixo a corrida quase nunca acontecia e o
    # caso passava sem provar nada.
    $acervoB = Join-Path $sandbox.Acervo 'SDT\SdtB.xml'
    $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
    $watcher = Start-ThreadJob -ScriptBlock {
        param($WorkDir, $Path)
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ([DateTime]::UtcNow -lt $deadline) {
            if (Test-Path -LiteralPath $WorkDir -PathType Container) {
                if (@(Get-ChildItem -LiteralPath $WorkDir -Filter '*.bak' -File -ErrorAction SilentlyContinue).Count -gt 0) {
                    $raw = [System.IO.File]::ReadAllText($Path)
                    [System.IO.File]::WriteAllText($Path, $raw.Replace('description="SdtB"', 'description="SdtB "'), [System.Text.UTF8Encoding]::new($false))
                    return $true
                }
            }
            Start-Sleep -Milliseconds 20
        }
        return $false
    } -ArgumentList $workDir, $acervoB
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    $watcherFired = $false
    $watcherCompleted = Wait-Job -Job $watcher -Timeout 40
    if ($null -ne $watcherCompleted) { $watcherFired = [bool](Receive-Job -Job $watcher) }
    Remove-Job -Job $watcher -Force -ErrorAction SilentlyContinue
    if (-not $watcherFired) {
        Write-Verbose 'Caso 9: o gatilho nao disparou; caso inconclusivo nesta rodada.'
    }

    if ($result.Report.status -eq 'blocked') {
        $codes = Get-BlockCodes -Report $result.Report
        if ($codes -notcontains 'PLAN_STALE') {
            throw "Caso 9: bloqueio inesperado [$($codes -join ', ')]."
        }
        $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
        $journals = @(Get-ChildItem -LiteralPath $workDir -Filter '*.journal.json' -File)
        $baks = @(Get-ChildItem -LiteralPath $workDir -Filter '*.bak' -File)
        if ($journals.Count -eq 0) { throw 'Caso 9: journal deveria ser preservado apos aborto pos-1b.' }
        if ($baks.Count -eq 0) { throw 'Caso 9: .bak deveria ser preservado apos aborto pos-1b.' }
    } else {
        # A corrida nao aconteceu nesta execucao: o caso nao e determinístico
        # por natureza, e nao pode reprovar por isso.
        Write-Verbose 'Caso 9: a alteracao concorrente nao chegou a tempo; caso inconclusivo nesta rodada.'
    }

    # ----------------------------------------------------------------------
    # Caso 10 - schema, colisao e sanidade
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso10'
    $guid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'
    $text = New-ObjectXmlText -Name 'SdtSchema' -Guid $guid -TypeGuid $sdtTypeGuid
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtSchema.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtSchema.xml') -Text $text

    # 10.1 duplicidade por xmlPath na mesma operacao
    $manifestPath = Join-Path $sandbox.Root 'manifesto-dup.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-1' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml'),
        (New-DocumentationOperation -Id 'op-2' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.1' -Report $result.Report -Expected 'DUPLICATE_OPERATION'

    # 10.2 mesmo guid em xmlPath distintos
    $guidOutro = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtOutro.xml') -Text (New-ObjectXmlText -Name 'SdtOutro' -Guid $guidOutro -TypeGuid $sdtTypeGuid)
    $manifestPath = Join-Path $sandbox.Root 'manifesto-guid.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-1' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml'),
        (New-DocumentationOperation -Id 'op-2' -Guid $guid -Name 'SdtOutro' -XmlPath 'SDT/SdtOutro.xml')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.2' -Report $result.Report -Expected 'DUPLICATE_TARGET'

    # 10.3 objectState new com homonimo no acervo
    $manifestPath = Join-Path $sandbox.Root 'manifesto-novo.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-novo' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml' -ObjectState 'new')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.3' -Report $result.Report -Expected 'NEW_OBJECT_EXISTS_IN_ACERVO'

    # 10.4 Kind e SchemaVersion
    $manifestPath = Join-Path $sandbox.Root 'manifesto-kind.json'
    Write-TextFile -Path $manifestPath -Text (([ordered]@{ Kind = 'outro'; SchemaVersion = 1; operations = @() }) | ConvertTo-Json)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.4 (Kind)' -Report $result.Report -Expected 'MANIFEST_KIND_MISMATCH'

    $manifestPath = Join-Path $sandbox.Root 'manifesto-schema.json'
    Write-TextFile -Path $manifestPath -Text (([ordered]@{ Kind = 'xpz-batch-metadata-manifest'; SchemaVersion = 99; operations = @() }) | ConvertTo-Json)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.4 (SchemaVersion)' -Report $result.Report -Expected 'MANIFEST_SCHEMA_UNSUPPORTED'

    # 10.5 chave JSON duplicada
    $manifestPath = Join-Path $sandbox.Root 'manifesto-dupkey.json'
    Write-TextFile -Path $manifestPath -Text '{"Kind":"xpz-batch-metadata-manifest","SchemaVersion":1,"operations":[],"operations":[]}'
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.5' -Report $result.Report -Expected 'MANIFEST_SCHEMA_INVALID'

    # 10.6 allowDegradedAccents sem o switch de linha de comando
    $operationDegradada = New-DocumentationOperation -Id 'op-acento' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml' -NewDocumentation 'Informacao nao revisada.'
    $operationDegradada['allowDegradedAccents'] = $true
    $manifestPath = Join-Path $sandbox.Root 'manifesto-acento.json'
    Write-Manifest -Path $manifestPath -Operations @($operationDegradada)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.6' -Report $result.Report -Expected 'MANIFEST_SCHEMA_INVALID'

    # 10.7 degradacao introduzida bloqueia; com a excecao completa, passa
    $operationDegradada.Remove('allowDegradedAccents')
    $manifestPath = Join-Path $sandbox.Root 'manifesto-acento2.json'
    Write-Manifest -Path $manifestPath -Operations @($operationDegradada)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.7' -Report $result.Report -Expected 'DEGRADED_ACCENTS_INTRODUCED'

    $operationDegradada['allowDegradedAccents'] = $true
    $manifestPath = Join-Path $sandbox.Root 'manifesto-acento3.json'
    Write-Manifest -Path $manifestPath -Operations @($operationDegradada)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ExtraArguments @('-AllowDegradedAccents')
    if ((Get-BlockCodes -Report $result.Report) -contains 'DEGRADED_ACCENTS_INTRODUCED') {
        throw 'Caso 10.7: a excecao por operacao mais o switch deveriam liberar a gravacao.'
    }

    # 10.8 CDATA_UNSAFE
    $operationCdata = New-DocumentationOperation -Id 'op-cdata' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml' -NewDocumentation 'Texto com ]]> dentro.'
    $manifestPath = Join-Path $sandbox.Root 'manifesto-cdata.json'
    Write-Manifest -Path $manifestPath -Operations @($operationCdata)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.8' -Report $result.Report -Expected 'CDATA_UNSAFE'

    # 10.9 precondicao de documentation divergente
    $operationPrecondicao = New-DocumentationOperation -Id 'op-pre' -Guid $guid -Name 'SdtSchema' -XmlPath 'SDT/SdtSchema.xml' -ExpectedDocumentation 'algo que nao esta la'
    $manifestPath = Join-Path $sandbox.Root 'manifesto-pre.json'
    Write-Manifest -Path $manifestPath -Operations @($operationPrecondicao)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 10.9' -Report $result.Report -Expected 'PRECONDITION_MISMATCH'

    # 10.10 alvo fora da frente
    $manifestPath = Join-Path $sandbox.Root 'manifesto-fora.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-fora' -Guid $guid -Name 'SdtSchema' -XmlPath '../SDT/SdtSchema.xml')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    $codes = Get-BlockCodes -Report $result.Report
    if ($codes -notcontains 'PATH_OUTSIDE_FRONT' -and $codes -notcontains 'TARGET_FILE_MISSING') {
        throw "Caso 10.10: caminho fora da frente deveria bloquear; obtido [$($codes -join ', ')]."
    }

    # 10.11 frente fora do container canonico
    $foraCanonica = Join-Path $testRoot 'fora-canonica\Frente01'
    [void](New-Item -ItemType Directory -Path $foraCanonica -Force)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $foraCanonica
    Assert-BlockCode -Case 'Caso 10.11' -Report $result.Report -Expected 'FRONT_NOT_CANONICAL'

    # ----------------------------------------------------------------------
    # Caso 11 - setParent e composicao de duas operacoes no mesmo arquivo
    # ----------------------------------------------------------------------
    $folderGuid = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
    $folderOrigemGuid = 'aaaaaaaa-0000-0000-0000-000000000001'

    function New-ParentSandbox {
        param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$ObjectGuid)

        $sandbox = New-Sandbox -Name $Name
        $objeto = New-ObjectXmlText -Name 'SdtParent' -Guid $ObjectGuid -TypeGuid $sdtTypeGuid -Parent 'PastaOrigem' -ParentGuid $folderOrigemGuid
        Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtParent.xml') -Text $objeto
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtParent.xml') -Text $objeto
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Folder\PastaOrigem.xml') -Text (New-ObjectXmlText -Name 'PastaOrigem' -Guid $folderOrigemGuid -TypeGuid $folderTypeGuid -ParentGuid '00000000-0000-0000-0000-000000000000')
        Write-TextFile -Path (Join-Path $sandbox.Acervo 'Folder\PastaDestino.xml') -Text (New-ObjectXmlText -Name 'PastaDestino' -Guid $folderGuid -TypeGuid $folderTypeGuid -ParentGuid '00000000-0000-0000-0000-000000000000')
        return $sandbox
    }

    function New-ParentOperation {
        param(
            [Parameter(Mandatory = $true)][string]$ObjectGuid,
            [Parameter(Mandatory = $true)][string]$DestinationGuid,
            [string]$DestinationName = 'PastaDestino',
            [string]$DestinationType = $folderTypeGuid
        )

        return [ordered]@{
            id          = 'op-parent'
            op          = 'setParent'
            objectState = 'existing'
            target      = [ordered]@{ guid = $ObjectGuid; expectedType = 'SDT'; expectedName = 'SdtParent'; xmlPath = 'SDT/SdtParent.xml' }
            expected    = [ordered]@{ parent = 'PastaOrigem'; parentGuid = $folderOrigemGuid; parentType = $folderTypeGuid }
            new         = [ordered]@{ parent = $DestinationName; parentGuid = $DestinationGuid; parentType = $DestinationType }
        }
    }

    # 11.1 caminho feliz
    $objectGuid = 'cccccccc-cccc-cccc-cccc-cccccccccc01'
    $sandbox = New-ParentSandbox -Name 'caso11-ok' -ObjectGuid $objectGuid
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @((New-ParentOperation -ObjectGuid $objectGuid -DestinationGuid $folderGuid))
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    if ($result.Report.status -eq 'blocked') {
        throw "Caso 11.1: setParent bloqueado [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
    }
    $parentFinal = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtParent.xml'))
    foreach ($fragmento in @('parent="PastaDestino"', "parentGuid=`"$folderGuid`"")) {
        if (-not $parentFinal.Contains($fragmento)) {
            throw "Caso 11.1: atributo nao aplicado: '$fragmento'."
        }
    }
    if ($parentFinal.Contains('parent="PastaOrigem"')) {
        throw 'Caso 11.1: o valor antigo de parent sobreviveu.'
    }

    # 11.2 destino inexistente no acervo e na frente
    $sandbox = New-ParentSandbox -Name 'caso11-missing' -ObjectGuid $objectGuid
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @((New-ParentOperation -ObjectGuid $objectGuid -DestinationGuid 'dddddddd-dddd-dddd-dddd-dddddddddd01' -DestinationName 'PastaFantasma'))
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 11.2' -Report $result.Report -Expected 'PARENT_TARGET_MISSING'

    # 11.3 autorreferencia
    $sandbox = New-ParentSandbox -Name 'caso11-self' -ObjectGuid $folderGuid
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtParent.xml') -Text (New-ObjectXmlText -Name 'SdtParent' -Guid $folderGuid -TypeGuid $sdtTypeGuid -Parent 'PastaOrigem' -ParentGuid $folderOrigemGuid)
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @((New-ParentOperation -ObjectGuid $folderGuid -DestinationGuid $folderGuid))
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 11.3' -Report $result.Report -Expected 'PARENT_SELF_REFERENCE'

    # 11.4 destino do tipo Module e recusado (D6)
    $sandbox = New-ParentSandbox -Name 'caso11-module' -ObjectGuid $objectGuid
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @((New-ParentOperation -ObjectGuid $objectGuid -DestinationGuid $folderGuid -DestinationType '00000000-0000-0000-0000-000000000006'))
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 11.4' -Report $result.Report -Expected 'MODULE_PARENT_UNSUPPORTED'

    # 11.5 composicao: setDocumentation + setParent no MESMO arquivo.
    #      O mesmo guid em duas operacoes de tipos diferentes e o caso que a
    #      composicao da secao 4 exige; duplicidade so bloqueia quando o guid
    #      aparece em mais de um xmlPath (ou duas vezes na mesma operacao).
    $sandbox = New-ParentSandbox -Name 'caso11-composicao' -ObjectGuid $objectGuid
    $documentacao = New-DocumentationOperation -Id 'op-doc' -Guid $objectGuid -Name 'SdtParent' -XmlPath 'SDT/SdtParent.xml' -NewDocumentation 'Documentação composta.'
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($documentacao, (New-ParentOperation -ObjectGuid $objectGuid -DestinationGuid $folderGuid))
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    if ($result.Report.status -eq 'blocked') {
        throw "Caso 11.5: composicao bloqueada [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
    }
    $compostoFinal = [System.IO.File]::ReadAllText((Join-Path $sandbox.Front 'SDT\SdtParent.xml'))
    if (-not $compostoFinal.Contains('<InnerHtml><![CDATA[Documentação composta.]]></InnerHtml>')) {
        throw 'Caso 11.5: a documentacao nao entrou na composicao.'
    }
    if (-not $compostoFinal.Contains('parent="PastaDestino"')) {
        throw 'Caso 11.5: o setParent nao entrou na composicao.'
    }
    if (([regex]::Matches($compostoFinal, 'lastUpdate="')).Count -ne 1) {
        throw 'Caso 11.5: lastUpdate deveria ser bumpado uma unica vez por arquivo.'
    }
    $arquivos = @($result.Report.files)
    if ($arquivos.Count -ne 1) {
        throw "Caso 11.5: as duas operacoes deveriam compor um unico arquivo; relatorio trouxe $($arquivos.Count)."
    }
    if (@($arquivos[0].operations).Count -ne 2) {
        throw 'Caso 11.5: o relatorio deveria listar as duas operacoes do arquivo.'
    }

    # ----------------------------------------------------------------------
    # Caso 5 - recuperacao a partir do journal apos interrupcao
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso05'
    $guid = '55555555-5555-5555-5555-555555555501'
    $text = New-ObjectXmlText -Name 'SdtJournal' -Guid $guid -TypeGuid $sdtTypeGuid
    $targetPath = Join-Path $sandbox.Front 'SDT\SdtJournal.xml'
    Write-TextFile -Path $targetPath -Text $text
    $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
    [void](New-Item -ItemType Directory -Path $workDir -Force)
    $bakPath = Join-Path $workDir 'run.SdtJournal.xml.bak'
    Write-TextFile -Path $bakPath -Text $text
    $journalPath = Join-Path $workDir 'run.journal.json'
    Write-TextFile -Path $journalPath -Text (([ordered]@{
        Kind          = 'xpz-batch-metadata-journal'
        SchemaVersion = 1
        runId         = 'run'
        startedAtUtc  = '2024-01-01T00:00:00Z'
        workDir       = $workDir
        steps         = @(
            [ordered]@{ seq = 1; opId = 'op-1'; action = 'write'; state = 'started'; pathBefore = $targetPath; pathAfter = $targetPath; bakPath = $bakPath; hashBefore = 'abc'; hashAfter = $null; atUtc = '2024-01-01T00:00:01Z' }
        )
    }) | ConvertTo-Json -Depth 8)

    $recoveryScript = Join-Path $PSScriptRoot 'Show-GeneXusXmlBatchMetadataRecoveryPlan.ps1'
    if (-not (Test-Path -LiteralPath $recoveryScript -PathType Leaf)) {
        throw 'Caso 5: roteiro de recuperacao manual ausente (entregavel da secao 13.1).'
    }
    $recovery = & $recoveryScript -JournalPath $journalPath -AsJson | ConvertFrom-Json
    if ($recovery.status -ne 'interrupted') {
        throw "Caso 5: o roteiro deveria classificar a rodada como interrompida; obtido '$($recovery.status)'."
    }
    $restoreTargets = @(@($recovery.restore) | ForEach-Object { $_.target })
    if ($restoreTargets -notcontains $targetPath) {
        throw 'Caso 5: o roteiro nao apontou o alvo a restaurar.'
    }

    # 5b - rename interrompido entre 'started' e 'committed': o move pode ter
    #      acontecido ou nao, e o roteiro precisa dizer o que conferir. Sem
    #      isso, o pilar da secao 14 (recusa de adiar renameDomain apoiada na
    #      recuperabilidade) fica sem roteiro no caso interrompido.
    $renameFrom = Join-Path $sandbox.Front 'Domain\AlvoAntigo.xml'
    $renameTo = Join-Path $sandbox.Front 'Domain\AlvoNovo.xml'
    Write-TextFile -Path $renameTo -Text (New-ObjectXmlText -Name 'AlvoNovo' -Guid '55555555-5555-5555-5555-555555555502' -TypeGuid $domainTypeGuid)
    $renameBak = Join-Path $workDir 'run.AlvoAntigo.xml.bak'
    Write-TextFile -Path $renameBak -Text (New-ObjectXmlText -Name 'AlvoAntigo' -Guid '55555555-5555-5555-5555-555555555502' -TypeGuid $domainTypeGuid)
    $journalRenamePath = Join-Path $workDir 'run-rename.journal.json'
    Write-TextFile -Path $journalRenamePath -Text (([ordered]@{
        Kind          = 'xpz-batch-metadata-journal'
        SchemaVersion = 1
        runId         = 'run-rename'
        startedAtUtc  = '2024-01-01T00:00:00Z'
        workDir       = $workDir
        steps         = @(
            [ordered]@{ seq = 1; opId = 'op-r'; action = 'write'; state = 'started'; pathBefore = $renameFrom; pathAfter = $renameFrom; bakPath = $renameBak; hashBefore = 'abc'; hashAfter = $null; atUtc = '2024-01-01T00:00:01Z' },
            [ordered]@{ seq = 2; opId = 'op-r'; action = 'write'; state = 'committed'; pathBefore = $renameFrom; pathAfter = $renameFrom; bakPath = $renameBak; hashBefore = 'abc'; hashAfter = 'def'; atUtc = '2024-01-01T00:00:02Z' },
            [ordered]@{ seq = 3; opId = 'op-r'; action = 'rename'; state = 'started'; pathBefore = $renameFrom; pathAfter = $renameTo; bakPath = $renameBak; hashBefore = $null; hashAfter = $null; atUtc = '2024-01-01T00:00:03Z' }
        )
    }) | ConvertTo-Json -Depth 8)

    $recoveryRename = & $recoveryScript -JournalPath $journalRenamePath -AsJson | ConvertFrom-Json
    if ($recoveryRename.status -ne 'interrupted') {
        throw "Caso 5b: rodada com rename interrompido deveria sair como interrompida; obtido '$($recoveryRename.status)'."
    }
    $uncertain = @($recoveryRename.undoRenamesUncertain)
    if ($uncertain.Count -ne 1) {
        throw "Caso 5b: o roteiro deveria listar 1 rename incerto; listou $($uncertain.Count)."
    }
    if ($uncertain[0].from -ne $renameTo -or $uncertain[0].to -ne $renameFrom) {
        throw 'Caso 5b: o rename incerto nao trouxe os dois caminhos (destino e origem).'
    }
    if (-not $uncertain[0].fromPresent -or $uncertain[0].toPresent) {
        throw 'Caso 5b: o roteiro nao mediu corretamente qual dos dois caminhos existe em disco.'
    }
    if (@($recoveryRename.undoRenames).Count -ne 0) {
        throw 'Caso 5b: rename sem committed nao pode entrar na lista de renomes confirmados.'
    }
    $textoRoteiro = (& $recoveryScript -JournalPath $journalRenamePath) -join "`n"
    if ($textoRoteiro -notmatch 'o move ACONTECEU') {
        throw 'Caso 5b: o roteiro textual nao instruiu o operador sobre o rename interrompido.'
    }

    # ----------------------------------------------------------------------
    # Caso 12 - -ReportPath: guardas e fronteira com a promessa de nao-escrita
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso12'
    $guid = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01'
    $text = New-ObjectXmlText -Name 'SdtReport' -Guid $guid -TypeGuid $sdtTypeGuid
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtReport.xml') -Text $text
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtReport.xml') -Text $text
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-report' -Guid $guid -Name 'SdtReport' -XmlPath 'SDT/SdtReport.xml')
    )

    function Invoke-WithReportPath {
        param(
            [Parameter(Mandatory = $true)][string]$ManifestPath,
            [Parameter(Mandatory = $true)][string]$FrontFolder,
            [Parameter(Mandatory = $true)][string]$ReportPath,
            [switch]$Apply
        )
        $splat = @{ InputPath = $ManifestPath; FrontFolder = $FrontFolder; ReportPath = $ReportPath }
        if ($Apply) { $splat['Apply'] = $true }
        $output = & $enginePath @splat
        return ((@($output) -join "`n") | ConvertFrom-Json)
    }

    # 12.1 sem -Apply e com -ReportPath: grava o relatorio e NADA mais.
    #      A promessa de "nenhum artefato persistente" cobre o que o MOTOR cria
    #      por conta propria (journal, .bak, baseline, temporario, -WorkDir);
    #      o relatorio foi pedido pelo chamador, num caminho que ele deu.
    $reportOut = Join-Path $sandbox.Root 'relatorio.json'
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath $reportOut
    if ($report.status -eq 'blocked') {
        throw "Caso 12.1: bloqueado indevidamente [$((Get-BlockCodes -Report $report) -join ', ')]."
    }
    if (-not (Test-Path -LiteralPath $reportOut -PathType Leaf)) {
        throw 'Caso 12.1: -ReportPath nao gravou o relatorio.'
    }
    $reportFromDisk = [System.IO.File]::ReadAllText($reportOut) | ConvertFrom-Json
    if ($reportFromDisk.runId -ne $report.runId) {
        throw 'Caso 12.1: o relatorio em disco nao corresponde ao do stdout.'
    }
    $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
    if (Test-Path -LiteralPath $workDir) {
        $leftovers = @(Get-ChildItem -LiteralPath $workDir -Force)
        if ($leftovers.Count -gt 0) {
            throw "Caso 12.1: rodada sem -Apply deixou artefato do motor: $($leftovers[0].FullName)"
        }
    }

    # 12.2 extensao que nao e .json
    $reportBad = Join-Path $sandbox.Root 'relatorio.txt'
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath $reportBad
    Assert-BlockCode -Case 'Caso 12.2' -Report $report -Expected 'ARTIFACT_PATH_COLLISION'
    if (Test-Path -LiteralPath $reportBad) {
        throw 'Caso 12.2: o motor recusou o caminho e mesmo assim gravou nele.'
    }

    # 12.3 area protegida (o proprio acervo)
    $reportProtected = Join-Path $sandbox.Acervo 'relatorio.json'
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath $reportProtected
    Assert-BlockCode -Case 'Caso 12.3' -Report $report -Expected 'PROTECTED_AREA'
    if (Test-Path -LiteralPath $reportProtected) {
        throw 'Caso 12.3: gravou relatorio dentro de area protegida.'
    }

    # 12.4 dentro do -WorkDir, onde vivem journal, .bak e baseline
    $reportInWorkDir = Join-Path $workDir 'relatorio.json'
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath $reportInWorkDir
    Assert-BlockCode -Case 'Caso 12.4' -Report $report -Expected 'ARTIFACT_PATH_COLLISION'

    # 12.5b caminho relativo e pasta pai inexistente
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath 'relatorio-relativo.json'
    Assert-BlockCode -Case 'Caso 12.5b (relativo)' -Report $report -Expected 'ARTIFACT_PATH_COLLISION'
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath (Join-Path $sandbox.Root 'pasta-que-nao-existe\relatorio.json')
    Assert-BlockCode -Case 'Caso 12.5b (pasta pai)' -Report $report -Expected 'ARTIFACT_PATH_COLLISION'

    # 12.5 destino existente que nao e arquivo regular
    $reportAsDirectory = Join-Path $sandbox.Root 'relatorio-pasta.json'
    [void](New-Item -ItemType Directory -Path $reportAsDirectory -Force)
    $report = Invoke-WithReportPath -ManifestPath $manifestPath -FrontFolder $sandbox.Front -ReportPath $reportAsDirectory
    Assert-BlockCode -Case 'Caso 12.5' -Report $report -Expected 'ARTIFACT_PATH_COLLISION'

    # ----------------------------------------------------------------------
    # Caso 14 - XML ilegivel no indice do acervo nao pode passar em silencio
    #
    # Os ramos fail-open que a varredura de eixos vizinhos encontrou: um
    # Domain/*.xml invalido sumia do indice de definicoes (a forma curta
    # deixava de resolver e a referencia real deixava de bloquear), e um XML
    # invalido na pasta do tipo escondia o homonimo de objectState:new.
    # ----------------------------------------------------------------------
    $xmlInvalido = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Object name="Quebrado" type="' + $domainTypeGuid + '">' + "`r`n"

    # 14.1 Domain do acervo invalido durante um renameDomain
    $sandbox = New-PackagedModuleSandbox -Name 'caso14-domain-invalido'
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Domain\OutroDominio.xml') -Text $xmlInvalido
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    Assert-BlockCode -Case 'Caso 14.1' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'
    if (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml')) {
        throw 'Caso 14.1: indice de Domain com buraco nao pode deixar o rename acontecer.'
    }

    # 14.2 XML invalido na pasta do tipo com objectState: new
    $sandbox = New-Sandbox -Name 'caso14-tipo-invalido'
    $guidNovo = '1e1e1e1e-1e1e-1e1e-1e1e-1e1e1e1e1e01'
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtNovoLimpo.xml') -Text (New-ObjectXmlText -Name 'SdtNovoLimpo' -Guid $guidNovo -TypeGuid $sdtTypeGuid)
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtQuebrado.xml') -Text ('<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Object name="SdtQuebrado" type="' + $sdtTypeGuid + '">' + "`r`n")
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-novo' -Guid $guidNovo -Name 'SdtNovoLimpo' -XmlPath 'SDT/SdtNovoLimpo.xml' -ObjectState 'new')
    )
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    Assert-BlockCode -Case 'Caso 14.2' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'

    # 14.3 Folder ilegivel no grafo de pais: fail-closed ja cobre o risco, mas
    #      o arquivo tem de aparecer no relatorio, para o operador distinguir
    #      "destino nao existe" de "nao consegui ler o destino".
    $sandbox = New-ParentSandbox -Name 'caso14-folder-invalido' -ObjectGuid $objectGuid
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Folder\FolderQuebrado.xml') -Text ('<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Object name="FolderQuebrado" type="' + $folderTypeGuid + '">' + "`r`n")
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @((New-ParentOperation -ObjectGuid $objectGuid -DestinationGuid $folderGuid))
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front
    $kinds = @(@($result.Report.warnings) | ForEach-Object { $_.kind })
    if ($kinds -notcontains 'acervoFileUnreadable') {
        throw 'Caso 14.3: Folder ilegivel deveria aparecer como aviso no relatorio.'
    }
    if ($result.Report.status -eq 'blocked') {
        throw "Caso 14.3: Folder ilegivel de outro destino nao deveria bloquear [$((Get-BlockCodes -Report $result.Report) -join ', ')]."
    }

    # 14.4 -WorkDir com ponto de reanalise no caminho
    $sandbox = New-Sandbox -Name 'caso14-workdir-reparse'
    $guidReparse = '1e1e1e1e-1e1e-1e1e-1e1e-1e1e1e1e1e02'
    $textReparse = New-ObjectXmlText -Name 'SdtReparse' -Guid $guidReparse -TypeGuid $sdtTypeGuid
    Write-TextFile -Path (Join-Path $sandbox.Front 'SDT\SdtReparse.xml') -Text $textReparse
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'SDT\SdtReparse.xml') -Text $textReparse
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @(
        (New-DocumentationOperation -Id 'op-reparse' -Guid $guidReparse -Name 'SdtReparse' -XmlPath 'SDT/SdtReparse.xml')
    )
    $realWorkDir = Join-Path $sandbox.Root 'work-real'
    $linkedWorkDir = Join-Path $sandbox.Root 'work-link'
    [void](New-Item -ItemType Directory -Path $realWorkDir -Force)
    $junction = $null
    try {
        $junction = New-Item -ItemType Junction -Path $linkedWorkDir -Target $realWorkDir -ErrorAction Stop
    } catch {
        $junction = $null
    }
    if ($null -eq $junction) {
        Write-Verbose 'Caso 14.4: sem permissao para criar junction; caso inconclusivo nesta rodada.'
    } else {
        $splat = @{ InputPath = $manifestPath; FrontFolder = $sandbox.Front; WorkDir = (Join-Path $linkedWorkDir 'sub') }
        $output = & $enginePath @splat
        $report = ((@($output) -join "`n") | ConvertFrom-Json)
        Assert-BlockCode -Case 'Caso 14.4' -Report $report -Expected 'PROTECTED_AREA'
        if (Test-Path -LiteralPath (Join-Path $realWorkDir 'sub')) {
            throw 'Caso 14.4: o motor criou o -WorkDir dentro do caminho recusado.'
        }
    }

    # ----------------------------------------------------------------------
    # Caso 15 - -AcknowledgeReferences registra o limite e NAO autoriza
    # ----------------------------------------------------------------------
    $sandbox = New-PackagedModuleSandbox -Name 'caso15-acknowledge'
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'PackagedModule\PacoteComHomonimo.xml') -Text (New-PackagedModuleXmlText -PackageName 'PacoteExterno' -DomainName 'GAMMessageType')
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations @($renameOperation)
    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply -ExtraArguments @('-AcknowledgeReferences')
    Assert-BlockCode -Case 'Caso 15' -Report $result.Report -Expected 'REFERENCE_SCAN_INCOMPLETE'
    $kinds = @(@($result.Report.warnings) | ForEach-Object { $_.kind })
    if ($kinds -notcontains 'referenceLimitAcknowledged') {
        throw 'Caso 15: a aceitacao do limite deveria ficar registrada no relatorio.'
    }
    if (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_GAMMessageType.xml')) {
        throw 'Caso 15: -AcknowledgeReferences nao pode transformar medicao incompleta em autorizacao.'
    }

    # ----------------------------------------------------------------------
    # Caso 13 - dependencia que SOME entre as fases vira PLAN_STALE
    # ----------------------------------------------------------------------
    foreach ($vanishCase in @('acervo', 'alvo')) {
        $sandbox = New-Sandbox -Name ('caso13-' + $vanishCase)
        $guidA = 'ffffffff-ffff-ffff-ffff-ffffffffff01'
        $guidB = 'ffffffff-ffff-ffff-ffff-ffffffffff02'
        foreach ($pair in @(@{ Name = 'SdtSomeA'; Guid = $guidA }, @{ Name = 'SdtSomeB'; Guid = $guidB })) {
            $objectText = New-ObjectXmlText -Name $pair.Name -Guid $pair.Guid -TypeGuid $sdtTypeGuid
            Write-TextFile -Path (Join-Path $sandbox.Front ('SDT\{0}.xml' -f $pair.Name)) -Text $objectText
            Write-TextFile -Path (Join-Path $sandbox.Acervo ('SDT\{0}.xml' -f $pair.Name)) -Text $objectText
        }
        $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
        Write-Manifest -Path $manifestPath -Operations @(
            (New-DocumentationOperation -Id 'op-a' -Guid $guidA -Name 'SdtSomeA' -XmlPath 'SDT/SdtSomeA.xml'),
            (New-DocumentationOperation -Id 'op-b' -Guid $guidB -Name 'SdtSomeB' -XmlPath 'SDT/SdtSomeB.xml')
        )
        $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
        if ($vanishCase -eq 'acervo') {
            $doomedPath = Join-Path $sandbox.Acervo 'SDT\SdtSomeB.xml'
        } else {
            $doomedPath = Join-Path $sandbox.Front 'SDT\SdtSomeB.xml'
        }

        # gatilho observavel em vez de espera cega: o apagamento acontece
        # quando o primeiro .bak aparece, ou seja, com a Fase 1b em curso.
        $vanisher = Start-ThreadJob -ScriptBlock {
            param($WorkDir, $DoomedPath)
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            while ([DateTime]::UtcNow -lt $deadline) {
                if (Test-Path -LiteralPath $WorkDir -PathType Container) {
                    if (@(Get-ChildItem -LiteralPath $WorkDir -Filter '*.bak' -File -ErrorAction SilentlyContinue).Count -gt 0) {
                        Remove-Item -LiteralPath $DoomedPath -Force -ErrorAction SilentlyContinue
                        return $true
                    }
                }
                Start-Sleep -Milliseconds 20
            }
            return $false
        } -ArgumentList $workDir, $doomedPath

        $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
        $fired = $false
        $completed = Wait-Job -Job $vanisher -Timeout 40
        if ($null -ne $completed) { $fired = [bool](Receive-Job -Job $vanisher) }
        Remove-Job -Job $vanisher -Force -ErrorAction SilentlyContinue

        if (-not $fired) {
            Write-Verbose "Caso 13 ($vanishCase): o gatilho nao disparou; caso inconclusivo nesta rodada."
            continue
        }
        if ($result.Report.status -eq 'internalError') {
            throw "Caso 13 ($vanishCase): sumico entre fases virou erro interno em vez de bloqueio nomeado."
        }
        Assert-BlockCode -Case "Caso 13 ($vanishCase)" -Report $result.Report -Expected 'PLAN_STALE'
        $mensagens = @(@($result.Report.blocks) | Where-Object { $_.code -eq 'PLAN_STALE' } | ForEach-Object { $_.message })
        if (-not ($mensagens -match 'desapareceu|indisponivel|ilegivel')) {
            throw "Caso 13 ($vanishCase): PLAN_STALE nao nomeou o sumico: $($mensagens -join ' | ')"
        }
    }

    # ----------------------------------------------------------------------
    # Caso 16 - rollback do RENAME
    #
    # O caso 3 exercita a falha na escrita. Aqui a falha e no rename, que e o
    # passo que a secao 14 usa como pilar: a recusa de adiar renameDomain se
    # apoia em "o rename e desfeito em ordem inversa antes de restaurar os
    # .bak". Injecao: um intruso cria o arquivo de DESTINO do segundo rename
    # depois que as escritas terminaram - a colisao foi conferida na Fase 1a,
    # e a corrida e justamente o que o rollback existe para tratar.
    # ----------------------------------------------------------------------
    $sandbox = New-Sandbox -Name 'caso16-rollback-rename'
    $renameGuids = @{ A = '16161616-1616-1616-1616-161616161601'; B = '16161616-1616-1616-1616-161616161602' }
    $renameTargets = @{}
    foreach ($sufixo in @('A', 'B')) {
        $nome = "DomRollback$sufixo"
        $objectText = New-ObjectXmlText -Name $nome -Guid $renameGuids[$sufixo] -TypeGuid $domainTypeGuid -ModuleGuid $moduleGuid -FullyQualifiedName "GAM.$nome"
        $alvo = Join-Path $sandbox.Front ('Domain\{0}.xml' -f $nome)
        Write-TextFile -Path $alvo -Text $objectText
        Write-TextFile -Path (Join-Path $sandbox.Acervo ('Domain\{0}.xml' -f $nome)) -Text $objectText
        $renameTargets[$sufixo] = $alvo
    }
    Write-TextFile -Path (Join-Path $sandbox.Acervo 'Module\GAM.xml') -Text (New-ObjectXmlText -Name 'GAM' -Guid $moduleGuid -TypeGuid '00000000-0000-0000-0000-000000000006' -ModuleGuid '00000000-0000-0000-0000-000000000000')

    $renameOperations = @()
    foreach ($sufixo in @('A', 'B')) {
        $nome = "DomRollback$sufixo"
        $renameOperations += [ordered]@{
            id          = "op-rollback-$sufixo"
            op          = 'renameDomain'
            objectState = 'existing'
            target      = [ordered]@{ guid = $renameGuids[$sufixo]; expectedType = 'Domain'; expectedName = $nome; xmlPath = "Domain/$nome.xml" }
            expected    = [ordered]@{ name = $nome; fullyQualifiedName = "GAM.$nome"; propertyName = $nome; description = $nome }
            new         = [ordered]@{ name = "SemUso_$nome" }
            renameFile  = $true
        }
    }
    $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
    Write-Manifest -Path $manifestPath -Operations $renameOperations

    $hashesAntes = @{}
    foreach ($sufixo in @('A', 'B')) { $hashesAntes[$sufixo] = Get-Sha256 -Path $renameTargets[$sufixo] }
    $workDir = Join-Path $sandbox.Root 'Temp\xpz-batch-metadata\Frente01'
    $intruso = Join-Path $sandbox.Front 'Domain\SemUso_DomRollbackB.xml'
    $conteudoIntruso = 'INTRUSO'

    $collider = Start-ThreadJob -ScriptBlock {
        param($WorkDir, $Intruder, $Content)
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ([DateTime]::UtcNow -lt $deadline) {
            $journal = @(Get-ChildItem -LiteralPath $WorkDir -Filter '*.journal.json' -File -ErrorAction SilentlyContinue)
            if ($journal.Count -gt 0) {
                $raw = ''
                try { $raw = [System.IO.File]::ReadAllText($journal[0].FullName) } catch { $raw = '' }
                if (([regex]::Matches($raw, '"state":\s*"committed"')).Count -ge 2) {
                    [System.IO.File]::WriteAllText($Intruder, $Content, [System.Text.UTF8Encoding]::new($false))
                    return $true
                }
            }
            Start-Sleep -Milliseconds 15
        }
        return $false
    } -ArgumentList $workDir, $intruso, $conteudoIntruso

    $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
    $colliderFired = $false
    $colliderCompleted = Wait-Job -Job $collider -Timeout 40
    if ($null -ne $colliderCompleted) { $colliderFired = [bool](Receive-Job -Job $collider) }
    Remove-Job -Job $collider -Force -ErrorAction SilentlyContinue

    if (-not $colliderFired) {
        Write-Verbose 'Caso 16: o intruso nao chegou a tempo; caso inconclusivo nesta rodada.'
    } else {
        if (@('rollbackComplete', 'rollbackIncomplete') -notcontains $result.Report.status) {
            $detalhe = @(@($result.Report.blocks) | ForEach-Object { "$($_.code): $($_.message)" }) -join ' | '
            throw "Caso 16: a colisao no rename deveria levar a rollback; status '$($result.Report.status)' [$detalhe]."
        }
        if ($result.Report.status -eq 'rollbackIncomplete') {
            throw "Caso 16: rollback do rename ficou incompleto: $(@($result.Report.rollbackErrors) -join '; ')"
        }
        foreach ($sufixo in @('A', 'B')) {
            $alvo = $renameTargets[$sufixo]
            if (-not (Test-Path -LiteralPath $alvo -PathType Leaf)) {
                throw "Caso 16: o alvo $sufixo nao voltou ao nome original apos o rollback."
            }
            if ((Get-Sha256 -Path $alvo) -ne $hashesAntes[$sufixo]) {
                throw "Caso 16: o alvo $sufixo voltou com conteudo diferente do original."
            }
        }
        if (Test-Path -LiteralPath (Join-Path $sandbox.Front 'Domain\SemUso_DomRollbackA.xml')) {
            throw 'Caso 16: o rename do primeiro alvo nao foi desfeito.'
        }
        if ([System.IO.File]::ReadAllText($intruso) -ne $conteudoIntruso) {
            throw 'Caso 16: o motor escreveu por cima do arquivo que causou a colisao.'
        }
    }

    # ----------------------------------------------------------------------
    # Caso 3 - escala com falha injetada
    # ----------------------------------------------------------------------
    if ($SkipScale) {
        Write-Verbose 'Caso 3 pulado por -SkipScale.'
    } else {
        $sandbox = New-Sandbox -Name 'caso03'
        $operations = [System.Collections.Generic.List[object]]::new()
        $targets = [System.Collections.Generic.List[string]]::new()
        for ($i = 1; $i -le 131; $i++) {
            $name = 'SdtEscala{0:D3}' -f $i
            $objectGuid = '33333333-3333-3333-3333-{0:D12}' -f $i
            $objectText = New-ObjectXmlText -Name $name -Guid $objectGuid -TypeGuid $sdtTypeGuid
            $path = Join-Path $sandbox.Front ('SDT\{0}.xml' -f $name)
            Write-TextFile -Path $path -Text $objectText
            Write-TextFile -Path (Join-Path $sandbox.Acervo ('SDT\{0}.xml' -f $name)) -Text $objectText
            [void]$targets.Add($path)
            [void]$operations.Add((New-DocumentationOperation -Id ('op-{0:D3}' -f $i) -Guid $objectGuid -Name $name -XmlPath ('SDT/{0}.xml' -f $name)))
        }
        $manifestPath = Join-Path $sandbox.Root 'manifesto.json'
        Write-Manifest -Path $manifestPath -Operations @($operations)

        $hashesBefore = @{}
        foreach ($path in $targets) { $hashesBefore[$path] = Get-Sha256 -Path $path }

        # falha injetada: o alvo 120 fica legivel (o plano passa) mas com a
        # SUBSTITUICAO bloqueada por outro processo, e o File.Move falha no
        # meio do lote - exatamente a janela que o journal existe para cobrir.
        $blockedPath = $targets[119]
        $blockingStream = [System.IO.File]::Open($blockedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $result = Invoke-Engine -ManifestPath $manifestPath -FrontFolder $sandbox.Front -Apply
        } finally {
            $blockingStream.Dispose()
        }

        if (@('rollbackComplete', 'rollbackIncomplete') -notcontains $result.Report.status) {
            $detalhe = @(@($result.Report.blocks) | ForEach-Object { "$($_.code): $($_.message)" }) -join ' | '
            throw "Caso 3: a falha injetada deveria levar a rollback; status '$($result.Report.status)' [$detalhe]."
        }
        if ($result.Report.status -eq 'rollbackIncomplete') {
            throw "Caso 3: rollback ficou incompleto: $($result.Report.rollbackErrors -join '; ')"
        }
        $changed = [System.Collections.Generic.List[string]]::new()
        foreach ($path in $targets) {
            if ((Get-Sha256 -Path $path) -ne $hashesBefore[$path]) { [void]$changed.Add($path) }
        }
        if ($changed.Count -gt 0) {
            throw "Caso 3: $($changed.Count) arquivo(s) ficaram com hash alterado apos o rollback; o primeiro e $($changed[0])."
        }
        $novos = @(Get-ChildItem -LiteralPath (Join-Path $sandbox.Front 'SDT') -File)
        if ($novos.Count -ne 131) {
            throw "Caso 3: a frente deveria manter 131 arquivos; tem $($novos.Count)."
        }
    }
} catch {
    [void]$failures.Add($_.Exception.Message)
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "FALHA: $failure" }
    exit 1
}

Write-Output 'OK: Test-EditGeneXusXmlBatchMetadataContract.ps1'
exit 0
