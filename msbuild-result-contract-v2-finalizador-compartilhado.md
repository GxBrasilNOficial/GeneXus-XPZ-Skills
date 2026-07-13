# Avaliar contrato v2/finalizador compartilhado para wrappers MSBuild GeneXus

## Status

Ideia pendente para avaliação futura. Este documento registra a oportunidade e os limites conhecidos; não autoriza implementação.

## Origem

A ideia surgiu durante a revisão do incidente em que `Invoke-GeneXusKbBuildAll.ps1` produziu JSON degradado por falha de pós-processamento:

- MSBuild retornou `msBuildExitCode = 0`;
- `BuildAllDone = true`;
- stdout continha sucesso operacional do Build All;
- stderr continha apenas o ruído conhecido `context [anonymous] 1:12 attribute component isn't defined`;
- o resultado final ficou com `postProcessingFailed = true` porque `$operationalSubStateBuild` foi lida sem inicialização.

A correção imediata deve permanecer estreita: inicializar as variáveis necessárias, aplicar corretamente o filtro do ruído conhecido e testar o caminho limpo sem exigir GeneXus real.

## O que fica fora da Fase 0

Não incluir na correção inicial:

- contrato v2 de resultado;
- finalizador compartilhado entre wrappers;
- serializador JSON comum;
- validação formal de esquema;
- migração de consumidores;
- reorganização ampla de documentação;
- mudança de semântica de warnings, stderr bruto ou `postProcessingFailed` fora do caso observado.

Esses itens podem ter valor, mas aumentam o raio da mudança e não são necessários para sanar a falha original.

## Ideia futura

Avaliar uma camada compartilhada para finalizar resultados dos wrappers MSBuild GeneXus, cobrindo pelo menos:

- classificação final operacional;
- preservação de `executionEvidence`, `observedContext`, `buildSignals`, `watcherContext`, timing e fases;
- serialização consistente para stdout e `LogPath`;
- tratamento uniforme de falhas de pós-processamento;
- contrato explícito para stderr bruto, stderr filtrado e ruído filtrado;
- compatibilidade gradual com consumidores existentes.

## Valor potencial

O valor esperado é reduzir divergência entre `Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1` e scripts correlatos quando todos precisarem responder às mesmas perguntas:

- o MSBuild terminou operacionalmente?
- houve erro real, bloqueio ou apenas ruído conhecido?
- o JSON preserva evidências suficientes para diagnóstico?
- uma falha no pós-processamento foi isolada sem mascarar o resultado operacional?
- consumidores conseguem distinguir erro real, warning e ruído estrutural?

## Riscos e decisões em aberto

Antes de implementar, decidir:

- se o ganho justifica mover lógica para helper compartilhado;
- qual é a versão mínima do contrato e como expor `contractVersion`;
- se stdout e `LogPath` devem ser montados pelo mesmo objeto imutável;
- como manter compatibilidade com consumidores que esperam o shape atual;
- como testar `ConvertTo-Json -Depth` sem truncar objetos aninhados;
- como diferenciar falha de classificação, falha de serialização e falha de escrita em arquivo;
- quais campos são obrigatórios mesmo em erro catastrófico;
- se a validação por esquema entra na mesma frente ou em fase posterior.

## Critérios para retomar

Retomar esta ideia se ocorrer pelo menos uma destas condições:

- novo incidente de pós-processamento em wrapper MSBuild;
- divergência confirmada entre BuildAll e Specify/Generate para o mesmo tipo de evidência;
- consumidor passar a depender de contrato mais formal;
- manutenção local mostrar duplicação relevante e arriscada;
- a Fase 0 ficar concluída e estável, com testes cobrindo o caso original.

## Escopo candidato se aprovado

Uma frente futura poderia:

1. inventariar campos emitidos pelos wrappers MSBuild atuais;
2. mapear consumidores locais e documentados;
3. desenhar contrato v2 mínimo e compatível;
4. introduzir helper compartilhado pequeno;
5. portar um wrapper por vez;
6. adicionar testes de contrato, serialização e falha injetada;
7. atualizar documentação normativa apenas depois do comportamento real existir.

## Fora de escopo permanente

Mesmo se retomada, esta ideia não deve:

- tocar pasta paralela de KB real como parte da correção das skills;
- reclassificar `attribute component isn't defined` como erro novo de KB;
- usar arquitetura ampla como pré-requisito para corrigir incidente estreito;
- substituir leitura crítica dos consumidores por suposição de compatibilidade.

## Rastreabilidade da sessão

Os planos temporários da sessão (`Temp/peer-review-msbuild-build-plan-v42.txt` a `Temp/peer-review-msbuild-build-plan-v50.txt`) ajudaram a separar a Fase 0 da arquitetura futura, mas não são fonte normativa. Este documento preserva apenas o aprendizado reutilizável.
