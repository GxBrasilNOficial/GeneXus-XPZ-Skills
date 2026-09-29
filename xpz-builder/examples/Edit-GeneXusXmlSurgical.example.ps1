#requires -Version 7.4
<#
.SYNOPSIS
    Exemplo sanitizado de edicao cirurgica de XML GeneXus via motor compartilhado.

.DESCRIPTION
    Delega a scripts/Edit-GeneXusXmlSurgical.ps1 na base GeneXus-XPZ-Skills.
    Ajuste SharedSkillsRoot, caminhos da frente e strings Anchor/Replacement
    (incluindo `r`n e tabs) antes de executar.

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

# 1) Simular antes de gravar
& $enginePath `
    -InputPath $workingXml `
    -Anchor $anchorRule `
    -Replacement ("Default(CampoExemplo,procExemplo());{0}{0}// nova rule aprovada na frente" -f "`r`n") `
    -EditMode Replace `
    -LastUpdateBaselinePath $acervoXml `
    -DryRun `
    -AsJson

# 2) Apply real (bump automático de lastUpdate; baseline = acervo oficial)
& $enginePath `
    -InputPath $workingXml `
    -Anchor $anchorRule `
    -Replacement ("Default(CampoExemplo,procExemplo());{0}{0}// nova rule aprovada na frente" -f "`r`n") `
    -EditMode Replace `
    -LastUpdateBaselinePath $acervoXml `
    -AsJson

# 3) Inserir após ancora sem remover o trecho ancora (InsertAfter)
& $enginePath `
    -InputPath $workingXml `
    -Anchor $anchorRule `
    -Replacement ("{0}// comentario de rastreio da frente" -f "`r`n") `
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
