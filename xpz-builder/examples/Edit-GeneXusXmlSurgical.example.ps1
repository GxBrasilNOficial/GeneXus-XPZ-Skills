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

# Deriva a quebra de linha a partir do ALVO (mesma regra do motor: qualquer
# CRLF vence; senao CR solto; senao LF), para nao cair no erro 29. O motor NAO
# normaliza EOL — se o Replacement trouxer quebra divergente, nada e gravado.
$targetText = [System.IO.File]::ReadAllText($workingXml)
$newline = if ($targetText.Contains("`r`n")) { "`r`n" } elseif ($targetText.Contains("`r")) { "`r" } else { "`n" }

# 1) Simular antes de gravar
& $enginePath `
    -InputPath $workingXml `
    -Anchor $anchorRule `
    -Replacement ("Default(CampoExemplo,procExemplo());{0}{0}// nova rule aprovada na frente" -f $newline) `
    -EditMode Replace `
    -LastUpdateBaselinePath $acervoXml `
    -DryRun `
    -AsJson

# 2) Apply real (bump automático de lastUpdate; baseline = acervo oficial)
& $enginePath `
    -InputPath $workingXml `
    -Anchor $anchorRule `
    -Replacement ("Default(CampoExemplo,procExemplo());{0}{0}// nova rule aprovada na frente" -f $newline) `
    -EditMode Replace `
    -LastUpdateBaselinePath $acervoXml `
    -AsJson

# 3) Inserir após ancora sem remover o trecho ancora (InsertAfter)
& $enginePath `
    -InputPath $workingXml `
    -Anchor $anchorRule `
    -Replacement ("{0}// comentario de rastreio da frente" -f $newline) `
    -EditMode InsertAfter `
    -LastUpdateBaselinePath $acervoXml `
    -AsJson

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
