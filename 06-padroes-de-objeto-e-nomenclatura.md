# 06 - Padroes de Objeto e Nomenclatura

## Papel do documento
conceitual

## Nivel de confianca predominante
medio

## Depende de
01-base-empirica-geral.md

## Usado por
08-guia-para-agente-gpt.md, 07-open-points-e-checklist.md

## Objetivo
Reunir padroes de nomeacao, organizacao e relacoes aparentes observadas no acervo, sem promover esses padroes a garantia estrutural.

## Fontes consolidadas
- 03-genexus-object-design-patterns.md

## Origem incorporada - 03-genexus-object-design-patterns.md

## Papel do documento
conceitual

## Nível de confiança predominante
médio

## Depende de
01-base-empirica-geral.md, 30-inventario-bruto-kb.md

## Usado por
02-regras-operacionais-e-runtime.md, 26-guia-para-agente-gpt.md

## Objetivo
Registrar padrões observáveis de nomeação, organização e referência entre objetos no acervo analisado.
Evitar que convenções locais sejam tratadas como regra universal sem qualificação.

## Escopo

Este documento registra padrões observáveis no inventário bruto e nos XMLs extraídos da KB principal analisada, complementados por um full export comparativo de uma KB independente usado apenas como contraprova de nomes genéricos do ecossistema GeneXus. Ele não prescreve convenções obrigatórias que não tenham apoio visível no acervo.

## Evidência comparativa posterior

- `Evidência direta`: um full export comparativo de KB independente confirmou a presença de nomes compartilhados do ecossistema GeneXus, como `Main Programs`, `ToBeDefined`, `UI`, `GAM_Frontend`, `GeneXusSecurity`, `GeneXusReporting` e `SidebarItemsDP`.
- `Inferência forte`: quando um nome aparece tanto no acervo principal quanto nessa KB independente, cresce a confiança editorial de que ele pertence ao repertório genérico ou comunitário de GeneXus, e não apenas ao domínio de negócio da KB principal.

## Padrões de nomeação por grupo

### `Procedure`

- `Evidência direta`: há muitos objetos com prefixo `proc`, por exemplo `PRCExemploA`, `PRCExemploB` e `PRCExemploC`, referenciados em XMLs lidos como `APIExemploIntegracaoA.xml` e `MODExemploAMenu.xml`.
- `Evidência direta`: também existem procedimentos sem prefixo `proc`, como `ctodUTC` e `curvalSTRZERO`.
- `Inferência forte`: o prefixo `proc` é recorrente, mas não exclusivo nem obrigatório no acervo.

### `DataProvider`

- `Evidência direta`: vários nomes começam com `dp`, como `DPExemploA`, `DPExemploB`, `DPExemploC` e `DPExemploD`.
- `Evidência direta`: também há exceções com outros formatos, como `DPRegions`, `DPSampleInfinityScrollGrid`, `GAM_GetTotalUsers` e `SidebarItemsDP`.
- `Evidência direta`: o full export comparativo também trouxe `SidebarItemsDP`, reforçando que esse nome não é exclusivo da KB principal analisada.
- `Inferência forte`: o grupo `DataProvider` favorece nomes identificáveis por função, com forte presença de prefixo `dp`, mas aceita variações legadas e nomes de módulos terceiros.

### `SDT`

- `Evidência direta`: nomes com prefixo `sdt` aparecem no acervo, como `SDTExemploTribSelecaoA`, `SDTExemploDocumentoFiscalA` e `SDTExemploFaturaA`.
- `Inferência forte`: o prefixo `sdt` parece uma convenção frequente para estruturas de dados, embora a capitalização varie.

### `WebPanel`

- `Evidência direta`: o acervo inclui nomes como `wpEntradaMODExemploA`, `wpEscolhaPesagemMODExemploA`, `WWEntradaMODExemploA`, `VWExemploA` e `MODExemploAMenu`.
- `Inferência forte`: não há um único prefixo estável para todo `WebPanel`; coexistem padrões como `wp`, `WW`, `View` e nomes conceituais sem prefixo.

### `WorkWithForWeb`

- `Evidência direta`: os arquivos observados usam nomes iniciando por `WorkWithWeb`, como `WorkWithWebTRNExemploB`, `WWExemploB` e `WWExemploBPadrao`.
- `Inferência forte`: dentro deste grupo extraído, `WorkWithWeb` funciona como assinatura nominal consistente.

### `Transaction`, `Domain` e `Module`

- `Evidência direta`: há nomes conceituais sem prefixo evidente, como `TRNExemploA`, `TRNExemploB`, `TRNExemploC`, `TRNExemploD`, `MODExemploA`, `MODExemploB` e `MODExemploC`.
- `Evidência direta`: o full export comparativo também exibiu contêineres e módulos compartilhados como `Main Programs`, `ToBeDefined`, `UI`, `GAM_Frontend` e `GeneXusReporting`.
- `Inferência forte`: nesses grupos, o padrão dominante parece ser nome de negócio ou nome técnico do conceito, não prefixação.

## Padrões de organização

- `Evidência direta`: vários objetos trazem `parent` apontando para um contêiner lógico, como `MODExemploAMenu` com `parent="MODExemploA"` e `APIExemploIntegracaoA` com `parent="MODExemploD"`.
- `Inferência forte`: módulos e contêineres funcionam como eixo importante de organização do acervo.
- `Evidência direta`: o inventário bruto também registra `moduleGuid` e `parentGuid`, o que reforça a presença de uma organização explícita por vínculos.

## Padrões de referência entre objetos

- `Evidência direta`: em `WebPanel\MODExemploAMenu.xml` o código referencia outros objetos nominais, como `wpEntradaMODExemploA`, `WWEntradaMODExemploA`, `WWPesagemMODExemploA` e `wpEscolhaPesagemMODExemploA`.
- `Evidência direta`: no unico caso real de `API` observado nesta KB, representado aqui pelo alias sanitizado `APIExemploIntegracaoA.xml`, aparecem chamadas para procedures como `PRCExemploA`, `procSdtTributacaoDadosBasicosSelecaoConformeParametros` e `PRCExemploB`.
- `Inferência forte`: nomes de objetos no acervo não são apenas rótulos; eles também aparecem como pontos de acoplamento explícito entre artefatos.

## Uso cauteloso destes padrões

- `Inferência forte`: para documentação e análise, vale registrar esses padrões como recorrências da KB.
- `Hipótese`: para criação de objetos novos, essas recorrências podem servir como convenção inicial, mas isso ainda precisaria de validação com a equipe ou com a IDE da KB.






