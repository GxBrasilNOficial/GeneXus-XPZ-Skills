# KB Intelligence Fase 5 - Incremento 18 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-22

## Escopo

O decimo oitavo incremento da Fase 5 ampliou o recorte de origem de `ATTCUSTOMTYPE` para incluir objetos `SDT` no nivel top-level, com resolucao semantica controlada para `SDT` somente quando o alvo existir no inventario local.

O escopo consolidado cobre:

- origem `SDT`
- evidencia `Property ATTCUSTOMTYPE` top-level do objeto
- destino `SDT`, somente quando o valor usar prefixo `sdt:` e o objeto existir no inventario local
- regra de extracao `attcustomtype_resolved_object`
- confianca `direct`

## Classificacao

A relacao representa evidencia estrutural de tipo declarado em propriedade no nivel do proprio `SDT`. Ela nao prova serializacao efetiva, uso funcional completo nem substitui a regra separada de item interno de `SDT`.

## Fora do incremento

- item interno de `SDT`, que continua coberto separadamente por `sdt_item_attcustomtype_resolved_sdt`
- ampliar a origem para `Attribute`, `PackagedModule` ou outros tipos fora deste recorte
- resolver `bas:*`, `ext:*` ou `exo:*` adicionais por esta ampliacao de origem
- inferir `SDT` por nome de variavel, parametro, membro ou metodo
- criar relacao para `SDT` ausente do inventario local
- provar uso runtime efetivo do `SDT`

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 60494
- relacoes novas resolvidas por origem `SDT` top-level: 401
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 64/64 casos passing
