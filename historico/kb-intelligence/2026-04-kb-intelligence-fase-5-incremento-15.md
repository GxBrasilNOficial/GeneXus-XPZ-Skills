# KB Intelligence Fase 5 - Incremento 15 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-22

## Escopo

O decimo quinto incremento da Fase 5 adicionou resolucao semantica controlada de `ATTCUSTOMTYPE` com prefixo `exo:` para `ExternalObject`, somente quando o nome do objeto existir no inventario local.

O escopo consolidado cobre:

- origens ja cobertas pela relacao literal `CustomType:<valor>` de `ATTCUSTOMTYPE`
- destino `ExternalObject`, somente quando o valor usar prefixo `exo:` e o nome antes de eventual sufixo apos virgula existir no inventario local
- regra de extracao `attcustomtype_resolved_object`
- evidencia `Property ATTCUSTOMTYPE`
- confianca `direct`

## Classificacao

A relacao representa evidencia estrutural de tipo externo declarado em propriedade `ATTCUSTOMTYPE`. Ela nao prova chamada efetiva de metodo, carga de provider, dependencia runtime completa nem disponibilidade externa fora do inventario local.

## Fora do incremento

- inferir `ExternalObject` pelo nome da variavel, receptor ou metodo chamado
- resolver `ext:*` para `ExternalObject`
- criar relacao para nomes `exo:` ausentes do inventario local
- inferir modulo, namespace, provider ou vendor a partir do sufixo apos virgula
- provar uso runtime efetivo do `ExternalObject`

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 53351
- relacoes novas resolvidas para `ExternalObject`: 20
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 55/55 casos passing
