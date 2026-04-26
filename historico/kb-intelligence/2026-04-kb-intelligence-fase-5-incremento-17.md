# KB Intelligence Fase 5 - Incremento 17 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-22

## Escopo

O decimo setimo incremento da Fase 5 ampliou o recorte de origem de `ATTCUSTOMTYPE` para incluir objetos `Domain`, com resolucao semantica controlada para `SDT` somente quando o alvo existir no inventario local.

O escopo consolidado cobre:

- origem `Domain`
- destino `SDT`, somente quando o valor usar prefixo `sdt:` e o objeto existir no inventario local
- regra de extracao `attcustomtype_resolved_object`
- evidencia `Property ATTCUSTOMTYPE`
- confianca `direct`

## Classificacao

A relacao representa evidencia estrutural de tipo declarado em propriedade `ATTCUSTOMTYPE`. Ela nao prova serializacao efetiva, contrato runtime completo, uso funcional do tipo nem disponibilidade de tipos externos fora do inventario local.

## Fora do incremento

- ampliar a origem para `SDT`, `Attribute`, `PackagedModule` ou outros tipos fora deste recorte
- resolver `bas:*`, `ext:*` ou `exo:*` adicionais por esta ampliacao de origem
- inferir `SDT` pelo nome do dominio, variavel, parametro ou metodo
- criar relacao para `SDT` ausente do inventario local
- provar uso runtime efetivo do `SDT`

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 53974
- relacoes novas resolvidas por origem `Domain`: 25
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 61/61 casos passing
