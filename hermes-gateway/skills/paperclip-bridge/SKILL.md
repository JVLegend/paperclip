---
name: paperclip-bridge
description: Integração Hermes ↔ Paperclip — delegar tarefas, monitorar agentes, consultar rotinas e ver o que está acontecendo na plataforma de agentes do JV.
version: 1.0.0
author: JV
tags: [paperclip, agentes, delegação, monitoramento]
---

# Paperclip Bridge — Integração com a Plataforma de Agentes

Esta skill permite que você (Hermes) interaja com o Paperclip — a plataforma de agentes do JV — via API REST.

**Use esta skill sempre que JV:**
- Pedir para delegar algo a um agente específico
- Quiser saber o status dos agentes ou o que estão fazendo
- Perguntar sobre rotinas/crons (se rodaram, resultados)
- Pedir para executar uma rotina manualmente
- Quiser ver logs de execução
- Perguntar "o que está acontecendo no Paperclip?"

---

## Configuração

```
API_BASE=https://jv-paperclip-production.up.railway.app/api
API_KEY=pcp_board_setup_bc5dce235ce5166620bd3d15061636c87fa1be6a3d4298a6
```

Todos os comandos usam `curl` com o header de autenticação:
```bash
curl -s -H "Authorization: Bearer $API_KEY" "$API_BASE/endpoint"
```

Para facilitar, use o helper script `pcp` instalado em `~/.hermes/skills/productivity/paperclip-bridge/pcp.sh`:
```bash
source ~/.hermes/skills/productivity/paperclip-bridge/pcp.sh
```

---

## Comandos Rápidos (via helper `pcp`)

Depois de fazer `source` do script, use:

| Comando | O que faz |
|---|---|
| `pcp agents` | Lista todos os agentes |
| `pcp agent <id>` | Detalhes de um agente |
| `pcp status` | Status geral — agentes + runs ativos |
| `pcp runs [limit]` | Lista runs recentes (default: 10) |
| `pcp live` | Runs ativos/em andamento agora |
| `pcp run-log <runId>` | Log de execução de um run |
| `pcp routines` | Lista todas as rotinas |
| `pcp routine <id>` | Detalhes de uma rotina |
| `pcp routine-runs <id> [limit]` | Runs recentes de uma rotina |
| `pcp trigger-routine <routineId>` | Executa rotina manualmente |
| `pcp wakeup <agentId> "instrução"` | Delega tarefa para um agente |
| `pcp health` | Health check do servidor |

---

## IDs dos Agentes — JV AI Labs

| Agente | ID | Quando delegar |
|--------|-----|-------------|
| **CEO** | `e391537b-56e6-4146-822c-5bd43f100b8d` | Decisões estratégicas, priorização |
| **CTO** | `9b5cc0f8-1ecc-47ce-9b1f-791e2a02c7d8` | Código, debugging, deploys |
| **Conteúdo** | `f2370b7e-4944-4e98-9a26-039bf755d10e` | Posts, copywriting |
| **Chief of Staff** | `4570f69a-e159-4d61-b13e-e5f339bbc867` | Agenda, follow-ups |
| **Pesquisa & PhD** | `a1842a55-3df9-4f29-9d80-4441d949703a` | Papers, publicações |
| **Crescimento AEO** | `780aa59c-3c3a-44fe-9cfc-1f30ee4c63bf` | Prospecção, leads |
| **Inteligência** | `2158f367-5ac9-4db6-b2c4-bf8f8e80c897` | Monitoramento, reputação |
| **Produtividade** | `cde79e46-ebbf-4f3d-a7f6-108105114c36` | Vault, organização |
| **Grants** | `32549fcf-b969-4823-ae88-5e0b50d041aa` | Editais, financiamento |
| **Produtos** | `a0d2a193-0ac2-4fab-becf-adb60bdf1b33` | Roadmap, features |
| **SRE Monitor** | `d89cd20e-86ce-4941-be46-45916b48dfd9` | Infra, alertas |

**Company ID**: `6da87f11-6a27-4627-b101-924d5a161f6e`

---

## Exemplos de Uso

### Delegar tarefa a um agente
```bash
source ~/.hermes/skills/productivity/paperclip-bridge/pcp.sh
pcp wakeup "9b5cc0f8-1ecc-47ce-9b1f-791e2a02c7d8" "Verifica se o deploy do iaparamedicos.com.br está OK"
```

### Ver o que está acontecendo agora
```bash
source ~/.hermes/skills/productivity/paperclip-bridge/pcp.sh
pcp live
```

### Ver resultado de uma rotina
```bash
source ~/.hermes/skills/productivity/paperclip-bridge/pcp.sh
pcp routines
# Pegar o ID da rotina
pcp routine-runs <routineId> 3
# Ver o log do run mais recente
pcp run-log <runId>
```

### Status geral rápido
```bash
source ~/.hermes/skills/productivity/paperclip-bridge/pcp.sh
pcp status
```

---

## Protocolo de Delegação

Quando JV pedir algo que precisa de profundidade:

1. **Identifica o agente certo** pela tabela acima
2. **Executa** `pcp wakeup <agentId> "instrução detalhada"`
3. **Informa JV**: "Delegado para o [Agente]. Vou monitorar."
4. **Monitora** com `pcp live` ou `pcp runs` e reporta quando terminar
5. **Busca o resultado** com `pcp run-log <runId>` e resume para JV

---

## Protocolo de Status Diário

Quando JV perguntar "o que está acontecendo?" ou "status":

1. `pcp live` — runs ativos agora
2. `pcp runs 5` — últimos 5 runs
3. `pcp routines` — rotinas configuradas e status
4. Resume tudo em 3-5 bullets objetivos

---

## Sistema de Learnings (Self-Improving Agent)

Os agentes logam aprendizados, erros e feature requests no PostgreSQL do Railway. Isso cria memória institucional entre sessões.

### Tipos de Learning
| Tipo | Quando usar |
|---|---|
| `LRN` | Correção, insight, best practice, knowledge gap |
| `ERR` | Falha de comando, API error, timeout, crash |
| `FEAT` | Feature request, capacidade faltando |

### Comandos via pcp
```bash
pcp learn-log LRN correction "Kimi precisa de api.kimi.com, não moonshot.ai"
pcp learn-log ERR api_error "Timeout ao chamar Paperclip API"
pcp learn-log FEAT feature "Dashboard de métricas dos agentes"
pcp learn-list
pcp learn-stats
pcp learn-search "kimi"
```

### Para agentes dentro do container Paperclip
```bash
source /app/scripts/learnings.sh
learn "Descobri que o CTO precisa de mais contexto sobre a infra"
learn-error "API do Kimi retornou 429 rate limit"
learn-feat "Integração com Google Calendar"
learn-stats
```

### Promoção automática
Quando um `pattern_key` atinge 3+ recorrências → candidato a promoção para SOUL.md ou AGENTS.md.

---

## Notas Importantes

- O `wakeup` é **assíncrono** — retorna um runId, não o resultado
- Para ver o resultado, use `pcp run-log <runId>` depois de alguns minutos
- Rotinas têm `status: active/paused` — se JV perguntar, informe
- Os agentes usam o adapter `hermes_local` — precisam do binário `hermes` no container
- Se um agente não responder, verifique com `pcp agent <id>` se está configurado
