# Estudo de caso: Update incremental do índice KB Intelligence

**Status:** Estudo para implementação futura  
**Data:** 2026-04-26  
**Origem:** Análise de viabilidade após correção do campo `scope` e identificação da ausência de GUID no índice

---

## 1. Contexto

O `Build-KbIntelligenceIndex.py` faz sempre rebuild completo: scan de diretório + hash de cada XML + ~15 extrações de evidência via regex + write do SQLite. Para KBs de centenas de objetos, a extração de evidências domina o tempo total (~90%).

A nomenclatura ambígua nos wrappers — "New" vs "Update" — sugere falsamente que existe um caminho incremental mais rápido. Este estudo avalia a viabilidade de um caminho incremental real.

## 2. Estrutura de custo do rebuild

| Fase | O quê | Peso relativo |
|------|-------|---------------|
| `collect_all_objects()` | Scan de diretórios + hash SHA256 de cada XML | ~5% |
| ~15 funções de extração de evidência | Regex sobre Source XML de Procedure, WebPanel, DataProvider, WorkWithForWeb, etc. | ~90% |
| `write_index()` | SQLite INSERT de objetos + evidências + relações | ~4% |
| `validation_report()` | Comparações simples | ~1% |

O gargalo é claro: cada função de evidência itera N objetos e aplica regex no `Source` de cada XML.

## 3. Desenho do update incremental

### 3.1 Fase 1 — Diff (barato)

- Ler a tabela `objects` do SQLite atual: `(type, name, file_path, file_hash, guid)`
- Re-escanear `source_root` com `collect_all_objects()` (já calcula hash)
- Classificar cada objeto:
  - `added`: guid não estava no SQLite
  - `modified`: guid existe mas `file_hash` diferente (conteúdo mudou)
  - `renamed`: guid existe no SQLite com outro `name` (detectável se `guid` estiver no índice)
  - `unchanged`: guid e file_hash idênticos
  - `deleted`: estava no SQLite, não está mais no disco

**Pré-requisito atendido:** o campo `guid` já está implementado no motor (`Build-KbIntelligenceIndex.py`) e exposto nas queries do `Query-KbIntelligenceIndex.py`.

### 3.2 Fase 2 — Evidência seletiva (ganho principal)

- Extrair evidências apenas dos objetos `added` + `modified` + `renamed`
- Remover evidências e relações antigas desses mesmos objetos antes de inserir as novas
- Para objetos `deleted`, remover suas linhas em `objects`, `evidence` e `relations`

### 3.3 Fase 3 — Writeback (barato)

- DELETE das linhas afetadas, INSERT das novas, COMMIT

## 4. Perigos e mitigação

| Perigo | Severidade | Mitigação |
|--------|-----------|-----------|
| **Relações órfãs** — objeto A não mudou, mas referencia objeto B que foi deletado ou renomeado; a relação de A → B fica apontando para um target que não existe mais | Média | Após processar `deleted`/`renamed`, fazer passada de limpeza em `relations WHERE target_type = ? AND target_name = ?` |
| **Renome sem GUID** — sem GUID no índice, um rename é visto como `deleted` + `added`, perdendo o vínculo de identidade | Alta | *Atendido:* `guid` já está armazenado na tabela `objects` e serve como chave estável de identidade |
| **Novos objetos em tipos-alvo** — novo Attribute ou Table aparece; objetos-fonte não mudaram, mas suas evidências passariam a referenciar o novo target. Com incremental, essas evidências não seriam reextraídas. | Alta | Se um tipo-alvo ganha objetos novos, **todos** os source objects daquele tipo de evidência precisam ser reextraídos. Isso anula parte do ganho incremental. Mitigação: flag `--force-rebuild-on-new-targets` que detecta crescimento em tipos-alvo e força rebuild completo. |
| **Divergência silenciosa** — acúmulo de pequenas inconsistências ao longo de múltiplas execuções incrementais sem que ninguém perceba | Média | Rebuild completo periódico (a cada N incrementais) ou flag `--full` para uso consciente. Alternativa: `--verify` que compara hash do índice contra rebuild fresh em background. |
| **Complexidade de código** — ~15 extractors; cada loop precisaria filtrar por objeto afetado | Média | Isolável: o diff decide quais objetos reprocessar, e as funções de extração recebem listas filtradas, sem mudar assinatura das funções existentes. |

## 5. Expectativa de ganho

Cenário típico: KB de 500 objetos, usuário altera 3 Transactions e 1 WebPanel (0.8% de mudança).

| Operação | Rebuild full | Incremental |
|----------|-------------|-------------|
| Scan + hash | 500 XMLs | 500 XMLs (precisa verificar todos para detectar mudanças) |
| Extração de evidência | 500 objetos processados | ~4 objetos processados |
| Write SQLite | 500 INSERTs | ~4 DELETEs + ~4 INSERTs |
| **Tempo estimado** | 100% | ~8-12% |

Ganho real: ~90% de redução no caso típico.

**Atenção ao perigo 3 (novos tipos-alvo):** se o usuário adicionou um `Attribute` novo, toda extração de `attcustomtype` precisaria reescanear N objetos-fonte, reduzindo o ganho. O flag `--force-rebuild-on-new-targets` torna essa decisão explícita.

## 6. Conclusão

O update incremental é viável e o ganho seria expressivo no caso comum (poucos objetos alterados, sem novos tipos-alvo). Os pré-requisitos são:

1. **GUID no índice** *(atendido)* — `guid` já está armazenado na tabela `objects` e exposto nas queries
2. **Schema version** *(atendido)* — `schema_version = "1"` já está na tabela `metadata`; o `Query-KbIntelligenceIndex.py` valida isso obrigatoriamente antes de qualquer query, garantindo que índices stale sejam detectados e forcem rebuild explícito
3. **Flag `--incremental`** — modo de operação explícito, mantendo rebuild completo como padrão seguro
4. **Flag `--force-rebuild-on-new-targets`** — para o caso de novos objetos em tipos que servem como alvo de evidências
5. **Testes de consistência** — validar que N execuções incrementais produzem o mesmo índice que 1 rebuild completo

Até que os pré-requisitos 3 a 5 sejam implementados, o rebuild completo permanece como único caminho. A nomenclatura `Rebuild-` nos wrappers reflete isso com precisão.
