---
name: xpz-daemon
description: Instala e gerencia um monitor persistente de XPZ que sobrevive reboots do sistema
---

# xpz-daemon

Instala um monitor de filesystem no Windows Task Scheduler que observa uma pasta 
para arquivos `.xpz` novos e dispara sincronização automaticamente. O monitor persiste 
após reboots e continua rodando enquanto o sistema estiver ligado. Cada KB pode ter 
seu próprio daemon independente.

---

## GUIDELINE

Usuário solicita ativar ou desativar o monitoramento permanente. A skill:
- Identifica o nome da KB
- Instala a tarefa no Task Scheduler com nome único por KB
- Inicia ou para o monitoramento sob demanda
- Permite verificar status do daemon

---

## TRIGGERS

- "ative o monitoramento automático de XPZ para esta KB"
- "desative o daemon de XPZ"
- "qual é o status do monitoramento?"
- "remova o daemon de XPZ"

---

## RESPONSABILIDADES

- Resolver a pasta a monitorar pelo contexto ou perguntar ao usuário
- Identificar o nome da KB (pelo nome da pasta-pai ou perguntar ao usuário)
- Criar o script `.ps1` do watcher (ou reutilizar se já existe)
- Registrar no Task Scheduler com nome único por KB (ex: `XpzDaemon_KBExemplo`)
- Validar que não existe daemon com esse nome já instalado
- Inicia o monitoramento imediatamente após instalação
- Oferece comandos para parar/iniciar/remover o daemon
- Reporta status e logs de sincronização

---

## WORKFLOW - INSTALAR

1. Resolver a pasta a monitorar pelo contexto (ou perguntar ao usuário)
2. Identificar o nome da KB (pelo nome da pasta-pai ou perguntar ao usuário)
3. Montar o nome único da tarefa: `XpzDaemon_<NomeDaKB>`
4. Validar que não existe tarefa com esse nome já instalado
   - Se existir: oferecer opção de substituir ou usar outro nome
5. Validar permissões de admin (necessário para Task Scheduler)
6. Criar/atualizar o script `.ps1` do watcher com configuração correta
7. Registrar no Task Scheduler para executar ao iniciar e manter rodando
8. Iniciar o daemon imediatamente
9. Reportar: nome da KB, local do script, tarefa agendada, status

---

## WORKFLOW - PARAR

1. Identificar qual daemon parar (por nome da KB)
2. Parar o processo do daemon (se rodando)
3. Desabilitar a tarefa no Task Scheduler
4. Reportar que está parado mas instalado (pode reativar depois)

---

## WORKFLOW - REMOVER

1. Identificar qual daemon remover (por nome da KB)
2. Parar o processo
3. Remover a tarefa do Task Scheduler completamente
4. Deletar o script `.ps1` do watcher
5. Reportar: daemon removido completamente

---

## WORKFLOW - STATUS

1. Listar todos os daemons instalados (opcional: filtrar por KB)
2. Para cada daemon:
   - Verificar se tarefa existe no Task Scheduler
   - Verificar se processo está rodando
   - Reportar: nome da KB, instalado sim/não, rodando sim/não, última sincronização

---

## CONSTRAINTS

- Requer permissões de administrador (Task Scheduler)
- NUNCA corromper ou perder logs de sincronização
- Esperar alguns segundos após criação de `.xpz` antes de processar (IDE ainda escrevendo)
- Validar que a pasta existe antes de instalar
- Permitir múltiplos daemons para diferentes KBs (nomes de tarefa únicos por KB)
- Se daemon travar, Task Scheduler reinicia automaticamente
- Nomes de tarefa devem ser únicos e identificáveis: `XpzDaemon_<NomeDaKB>`

---

## LIMITES

- Roda apenas enquanto Windows estiver ligado (não liga a máquina)
- Requer permissões de admin para instalar/remover
- Logs de sincronização devem ser acessíveis para monitoramento
- Máximo recomendado: 5-10 daemons simultâneos (limite prático do sistema)
