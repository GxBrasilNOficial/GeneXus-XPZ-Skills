#requires -Version 7.4

<#
.SYNOPSIS
    Exemplo sanitizado de edicao cirurgica de XML GeneXus via motor compartilhado.

.DESCRIPTION
    Delega a scripts/Edit-GeneXusXmlSurgical.ps1 na base GeneXus-XPZ-Skills.
    Ajuste SharedSkillsRoot, caminhos da frente, a ancora e o Replacement antes
    de executar. As quebras do Replacement sao derivadas do EOL do proprio
    arquivo-alvo ($newline): o motor nao normaliza EOL e bloqueia com
    REPLACEMENT_EOL_MISMATCH/29 um Replacement cuja quebra divirja da dominante.

.PARAMETER SharedSkillsRoot
    Raiz local da base compartilhada GeneXus-XPZ-Skills.
#>

param(
    [string]$SharedSkillsRoot = 'C:\CAMINHO\PARA\GeneXus-XPZ-Skills'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Edit-GeneXusXmlSurgical.ps1'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Motor Edit-GeneXusXmlSurgical.ps1 nao encontrado: $enginePath"
}

$workingXml = 'C:\CAMINHO\PARA\KbParalela\ObjetosGeradosParaImportacaoNaKbNoGenexus\MinhaFrente\MeuObjeto.xml'
$acervoXml  = 'C:\CAMINHO\PARA\KbParalela\ObjetosDaKbEmXml\MeuObjeto.xml'
$anchorRule = 'Default(CampoExemplo,procExemplo());'
$payloadTemp = 'C:\CAMINHO\PARA\KbParalela\Temp'

# Deriva a quebra de linha a partir do ALVO (mesma regra do motor: qualquer
# CRLF vence; senao CR solto; senao LF), para nao cair no erro 29. O motor NAO
# normaliza EOL — se o Replacement trouxer quebra divergente, nada e gravado.
$targetText = [System.IO.File]::ReadAllText($workingXml)
$newline = if ($targetText.Contains("`r`n")) { "`r`n" } elseif ($targetText.Contains("`r")) { "`r" } else { "`n" }

# Preparar os auxiliares antes da chamada, fora da frente empacotável.
# A pasta Temp deve existir. UTF-8 sem BOM, sem newline adicional involuntária.
# Manter caminhos distintos do destino efetivo e seu .bak, inclusive por links
# ou aliases: o núcleo pode sobrescrevê-los/removê-los se houver colisão.
$anchorPath = Join-Path $payloadTemp 'edicao-anchor.txt'
$replacementPath = Join-Path $payloadTemp 'edicao-replacement.txt'
$replacementRule = "Default(CampoExemplo,procExemplo());{0}{0}// nova rule aprovada na frente" -f $newline
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($anchorPath, $anchorRule, $utf8)
[System.IO.File]::WriteAllText($replacementPath, $replacementRule, $utf8)

# 1) Simular e conferir o resultado antes de gravar o XML.
$raw = & $enginePath `
    -InputPath $workingXml `
    -AnchorPath $anchorPath `
    -ReplacementPath $replacementPath `
    -EditMode Replace `
    -LastUpdateBaselinePath $acervoXml `
    -DryRun `
    -AsJson
$simulationExit = $LASTEXITCODE
if ($simulationExit -ne 0) { throw "Simulação recusada (exit $simulationExit): $raw" }
try { $simulation = $raw | ConvertFrom-Json -ErrorAction Stop }
catch { throw 'Simulação não retornou JSON válido; aplicação cancelada.' }
if ($simulation.status -ne 'OK' -or $simulation.wellFormed -ne $true) {
    throw 'Simulação sem status OK e wellFormed=true; aplicação cancelada.'
}
# DryRun atual pode responder OK/exit 0 com wellFormed=false.
# Reutilizar os mesmos conteúdos aprovados; não há hash/lock entre as etapas.

# 2) Apply real (bump automático de lastUpdate; baseline = acervo oficial)
& $enginePath `
    -InputPath $workingXml `
    -AnchorPath $anchorPath `
    -ReplacementPath $replacementPath `
    -EditMode Replace `
    -LastUpdateBaselinePath $acervoXml `
    -AsJson
if ($LASTEXITCODE -ne 0) { throw 'Aplicação recusada; conferir o JSON acima.' }

# 3) Alternativa por strings (simular e conferir como acima antes de aplicar):
# & $enginePath -InputPath $workingXml -Anchor $anchorRule -Replacement $replacementRule -EditMode Replace -LastUpdateBaselinePath $acervoXml -DryRun -AsJson
# InsertAfter mantém a âncora; as quatro combinações string/arquivo são válidas.
# Exatamente uma origem por conteúdo; use nomes completos, pois -Anc/-Rep são
# ambíguos. Arquivo vazio/só BOM: âncora -> ANCHOR_EMPTY; substituição -> remoção
# em Replace ou NOOP_REPLACEMENT em InsertAfter. O editor não normaliza EOL.

# 4) Dependencia reenviada sem mudanca funcional: patch proibido na prática;
#    se algum ajuste textual for inevitavel, preservar lastUpdate explicitamente:
# & $enginePath -InputPath $workingXml -Anchor '...' -Replacement '...' -EditMode Replace -PreserveLastUpdate -AsJson

# 5) Ancora que se repete: -ExpectedAnchorCount apenas valida; para aplicar em
#    TODAS as ocorrências é obrigatório -ApplyToAllOccurrences (sem ele → 18).
# & $enginePath -InputPath $workingXml -Anchor '<trecho repetido>' -Replacement '<novo>' -EditMode Replace -ExpectedAnchorCount 2 -ApplyToAllOccurrences -AsJson

# 6) Remocao funcional: Replacement vazio em Replace (nao confundir com no-op).
# & $enginePath -InputPath $workingXml -Anchor '<trecho a remover>' -Replacement '' -EditMode Replace -AsJson

# 7) EOL: o Replacement tem de usar a quebra dominante do alvo. Um Replacement
#    com quebra divergente (ou EOL misto dentro dele) sobre fonte uniforme
#    devolve 29 REPLACEMENT_EOL_MISMATCH e NADA e gravado — por isso $newline e
#    derivado do proprio arquivo acima. Fonte de EOL misto segue diagnostico
#    (replacementEolMismatch=null) e grava; o motor nunca normaliza.

# 8) Novo NUNCA importado: declaração explícita, não inferida pela ausência no
#    acervo. Substituir o baseline da chamada pelo switch (não combinar ambos).
# & $enginePath -InputPath $workingXml -Anchor '...' -Replacement '...' -EditMode Replace -NewObjectNotImported -DryRun -AsJson
# Conflito com baseline não vazio/PreserveLastUpdate -> LASTUPDATE_CONTEXT_CONFLICT/30.
# Baseline explícito com bump: mesma raiz Object/Attribute + GUID válido não
# zero igual; sem isso -> LASTUPDATE_BASELINE_IDENTITY_MISMATCH/31, sem escrita.

# 9) Recarimbo final de preparação ainda não importada com acúmulo:
# $setter = Join-Path $SharedSkillsRoot 'scripts\Set-GeneXusXmlLastUpdate.ps1'
# Existente: referência oficial ATUAL do mesmo objeto; renová-la após importação.
# & $setter -InputPath $workingXml -BaselineXmlPath $acervoXml -AsJson
# Novo nunca importado (apenas sob essa precondição):
# & $setter -InputPath $workingXml -NewObjectNotImported -AsJson
# Default prova avanço somente sobre o arquivo, não KB viva/aceite do envelope.
# Lote: -NewObjectsNotImported só afeta objectState=new; existing permanece
# acumulativo. Add-GeneXusButton também requer essa conferência final.

# 10) Valor literal do JSON sem coerção de data (compatível com mínimo 7.4):
# $rawJson = & $setter -InputPath $workingXml -BaselineXmlPath $acervoXml -DryRun -AsJson
# $doc = [System.Text.Json.JsonDocument]::Parse([string]$rawJson)
# try { $literal = $doc.RootElement.GetProperty('lastUpdateAfter').GetString() }
# finally { $doc.Dispose() }
# Alternativas: saída textual do gerador ou atributo salvo no XML (.0000000Z).

# 11) Conferir a interface efetiva antes de montar chamadas:
# Editor e Set-GeneXusXmlLastUpdate usam -AsJson. Os motores abaixo já emitem
# JSON por padrão, sem -AsJson: Build-GeneXusImportFileEnvelope,
# New-XpzImportPackage, Copy-GeneXusAcervoToFront,
# Get-GeneXusImportPackageObjectInventory e Test-GeneXusSourceSanity.
# Uma flag -AsJson aceita por um gate filho não pertence automaticamente ao pai.
